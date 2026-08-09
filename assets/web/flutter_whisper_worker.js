'use strict';

let moduleInstance = null;
let context = 0;

function reply(id, body) {
  self.postMessage({ id, ...body });
}

async function downloadModel(id, url) {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Model download failed (${response.status}): ${url}`);
  }
  const total = Number(response.headers.get('content-length') || 0);
  if (!response.body || !total) {
    const bytes = new Uint8Array(await response.arrayBuffer());
    reply(id, { event: 'progress', progress: 100 });
    return bytes;
  }
  const reader = response.body.getReader();
  const chunks = [];
  let received = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    chunks.push(value);
    received += value.length;
    reply(id, {
      event: 'progress',
      progress: Math.min(100, Math.round((received * 100) / total)),
    });
  }
  const bytes = new Uint8Array(received);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.length;
  }
  return bytes;
}

async function initialize(message) {
  if (typeof createFlutterWhisperModule !== 'function') {
    self.importScripts(message.moduleUrl);
  }
  if (typeof createFlutterWhisperModule !== 'function') {
    throw new Error('The Emscripten module factory was not found.');
  }
  const moduleBase = new URL('.', message.moduleUrl).href;
  moduleInstance = await createFlutterWhisperModule({
    locateFile: (file) => new URL(file, moduleBase).href,
    print: (text) => console.log(`[whisper.cpp] ${text}`),
    printErr: (text) => console.error(`[whisper.cpp] ${text}`),
  });
  const model = await downloadModel(message.id, message.modelUrl);
  if (model.byteLength < 1024 * 1024) {
    throw new Error(
      'The selected model is incomplete. for-tests-* files contain headers only.',
    );
  }
  const magic = new DataView(
    model.buffer,
    model.byteOffset,
    model.byteLength,
  ).getUint32(0, true);
  if (magic !== 0x67676d6c) {
    throw new Error('The selected file is not a valid GGML Whisper model.');
  }
  const modelPath = '/whisper-model.bin';
  moduleInstance.FS.writeFile(modelPath, model);
  const create = moduleInstance.cwrap('fw_web_create', 'number', [
    'string',
    'number',
    'number',
    'number',
  ]);
  context = create(
    modelPath,
    message.useGpu ? 1 : 0,
    message.flashAttention ? 1 : 0,
    message.gpuDevice || 0,
  );
  if (!context) throw new Error('whisper.cpp could not load the Web model.');
}

function transcribe(message) {
  if (!moduleInstance || !context) throw new Error('WASM model is not loaded.');
  const samples = message.samples instanceof Float32Array
    ? message.samples
    : new Float32Array(message.samples);
  const pointer = moduleInstance._malloc(samples.byteLength);
  try {
    if (!moduleInstance.HEAPF32) {
      throw new Error(
        'The Emscripten HEAPF32 runtime export is missing. Rebuild the '
        + 'flutter_whisper WebAssembly artifacts.',
      );
    }
    moduleInstance.HEAPF32.set(samples, pointer >> 2);
    moduleInstance.fwOnProgress = (progress) => {
      reply(message.id, { event: 'progress', progress });
    };
    moduleInstance.fwOnSegment = (segment) => {
      reply(message.id, { event: 'segment', segment });
    };
    reply(message.id, { event: 'progress', progress: 0 });
    const run = moduleInstance.cwrap('fw_web_transcribe', 'string', [
      'number',
      'number',
      'number',
      'string',
      'number',
      'number',
    ]);
    const config = message.config || {};
    const result = run(
      context,
      pointer,
      samples.length,
      config.language || 'auto',
      config.translate ? 1 : 0,
      config.threads || 0,
    );
    if (!result) throw new Error('whisper.cpp returned an empty WASM result.');
    const parsed = JSON.parse(result);
    if (parsed.error) throw new Error(parsed.error);
    reply(message.id, { event: 'progress', progress: 100 });
    return result;
  } finally {
    moduleInstance.fwOnProgress = null;
    moduleInstance.fwOnSegment = null;
    moduleInstance._free(pointer);
  }
}

self.onmessage = async ({ data: message }) => {
  const id = message.id;
  try {
    switch (message.command) {
      case 'init':
        await initialize(message);
        reply(id, { ok: true });
        break;
      case 'transcribe':
        reply(id, { ok: true, result: transcribe(message) });
        break;
      case 'cancel':
        if (moduleInstance && context) {
          moduleInstance.ccall('fw_web_cancel', null, ['number'], [context]);
        }
        reply(id, { ok: true });
        break;
      default:
        throw new Error(`Unknown worker command: ${message.command}`);
    }
  } catch (error) {
    reply(id, { ok: false, error: error?.message || String(error) });
  }
};
