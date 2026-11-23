import { spawn } from 'node:child_process';
import { createReadStream } from 'node:fs';
import { mkdir, stat } from 'node:fs/promises';
import { createServer } from 'node:http';
import { extname, resolve, sep } from 'node:path';
import { once } from 'node:events';

const [site, fixtures, profile] = process.argv.slice(2).map((entry) => resolve(entry));
const types = {
  '.html': 'text/html',
  '.js': 'text/javascript',
  '.json': 'application/json',
  '.wasm': 'application/wasm',
  '.wav': 'audio/wav',
};
let complete;
let modelNetworkEnabled = true;
const result = new Promise((resolveResult) => { complete = resolveResult; });
const server = createServer(async (request, response) => {
  response.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
  response.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
  const path = new URL(request.url, 'http://localhost').pathname;
  if (request.method === 'POST' && path.startsWith('/__whisper_model_network/')) {
    modelNetworkEnabled = path.endsWith('/on');
    response.writeHead(204).end();
    return;
  }
  if (!modelNetworkEnabled && path === '/web_fixtures/ggml-tiny.en-q5_1.bin') {
    response.writeHead(503).end();
    return;
  }
  if (path === '/__whisper_test_result' && request.method === 'POST') {
    let body = '';
    for await (const chunk of request) body += chunk;
    response.writeHead(204).end();
    complete(JSON.parse(body));
    return;
  }

  const prefix = '/web_fixtures/';
  const root = path.startsWith(prefix) ? fixtures : site;
  const relative = path.startsWith(prefix) ? path.slice(prefix.length) : path.slice(1);
  const file = resolve(root, relative || 'index.html');
  if (!file.startsWith(root + sep)) {
    response.writeHead(404).end();
    return;
  }
  const info = await stat(file).catch(() => null);
  if (!info?.isFile()) {
    response.writeHead(404).end();
    return;
  }
  response.writeHead(200, {
    'Content-Type': types[extname(file)] || 'application/octet-stream',
    'Content-Length': info.size,
  });
  createReadStream(file).pipe(response);
});

await mkdir(profile, { recursive: true });
server.listen(0, '127.0.0.1');
await once(server, 'listening');
const browser = spawn(process.env.CHROME_EXECUTABLE || 'google-chrome', [
  '--headless',
  '--no-first-run',
  `--user-data-dir=${profile}`,
  `http://127.0.0.1:${server.address().port}/`,
], { stdio: ['ignore', 'ignore', 'inherit'], windowsHide: true });
const timer = setTimeout(() => complete({ ok: false, error: 'Chrome smoke test timed out.' }), 180000);
browser.once('error', (error) => complete({ ok: false, error }));
browser.once('exit', (code) => complete({ ok: false, error: `Chrome exited early (${code}).` }));
try {
  const outcome = await result;
  if (!outcome.ok) throw new Error(outcome.error);
  console.log('Chrome verified inference, cancellation, persistent model reuse, integrity, cache clearing and quota fallback.');
} finally {
  clearTimeout(timer);
  browser.kill();
  server.close();
  server.closeAllConnections();
}
