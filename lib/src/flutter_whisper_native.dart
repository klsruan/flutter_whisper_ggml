import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'exceptions.dart';
import 'models.dart';
import 'whisper_backend.dart';

typedef _CreateN = Pointer<Void> Function(Pointer<Utf8>, Uint8, Uint8, Int32);
typedef _CreateD = Pointer<Void> Function(Pointer<Utf8>, int, int, int);
typedef _VoidN = Void Function(Pointer<Void>);
typedef _VoidD = void Function(Pointer<Void>);
typedef _TranscribeN =
    Int32 Function(
      Pointer<Void>,
      Pointer<Float>,
      Int32,
      Pointer<_OptionsV2>,
      Pointer<NativeFunction<_ProgressN>>,
    );
typedef _TranscribeD =
    int Function(
      Pointer<Void>,
      Pointer<Float>,
      int,
      Pointer<_OptionsV2>,
      Pointer<NativeFunction<_ProgressN>>,
    );
typedef _Int1N = Int32 Function(Pointer<Void>);
typedef _Int1D = int Function(Pointer<Void>);
typedef _Int2N = Int32 Function(Pointer<Void>, Int32);
typedef _Int2D = int Function(Pointer<Void>, int);
typedef _Int3N = Int32 Function(Pointer<Void>, Int32, Int32);
typedef _Int3D = int Function(Pointer<Void>, int, int);
typedef _Time2N = Int64 Function(Pointer<Void>, Int32);
typedef _Time2D = int Function(Pointer<Void>, int);
typedef _Time3N = Int64 Function(Pointer<Void>, Int32, Int32);
typedef _Time3D = int Function(Pointer<Void>, int, int);
typedef _Float2N = Float Function(Pointer<Void>, Int32);
typedef _Float2D = double Function(Pointer<Void>, int);
typedef _Float3N = Float Function(Pointer<Void>, Int32, Int32);
typedef _Float3D = double Function(Pointer<Void>, int, int);
typedef _Text1N = Pointer<Utf8> Function(Pointer<Void>);
typedef _Text1D = Pointer<Utf8> Function(Pointer<Void>);
typedef _Text2N = Pointer<Utf8> Function(Pointer<Void>, Int32);
typedef _Text2D = Pointer<Utf8> Function(Pointer<Void>, int);
typedef _Text3N = Pointer<Utf8> Function(Pointer<Void>, Int32, Int32);
typedef _Text3D = Pointer<Utf8> Function(Pointer<Void>, int, int);
typedef _ProgressN = Void Function(Int32);
typedef _CountN = Int32 Function();
typedef _CountD = int Function();
typedef _IndexedTextN = Pointer<Utf8> Function(Int32);
typedef _IndexedTextD = Pointer<Utf8> Function(int);
typedef _IndexedIntN = Int32 Function(Int32);
typedef _IndexedIntD = int Function(int);
typedef _IndexedUint64N = Uint64 Function(Int32);
typedef _IndexedUint64D = int Function(int);

final class _OptionsV2 extends Struct {
  @Uint32()
  external int abiVersion;
  @Uint32()
  external int structSize;
  @Int32()
  external int strategy;
  @Int32()
  external int threads;
  @Int32()
  external int offsetMs;
  @Int32()
  external int durationMs;
  @Int32()
  external int translate;
  @Int32()
  external int noContext;
  @Int32()
  external int tokenTimestamps;
  @Int32()
  external int singleSegment;
  @Int32()
  external int maxSegmentLength;
  @Int32()
  external int splitOnWord;
  @Int32()
  external int maxTokens;
  @Int32()
  external int audioContext;
  @Int32()
  external int tinyDiarize;
  @Int32()
  external int bestOf;
  @Int32()
  external int beamSize;
  @Float()
  external double beamPatience;
  @Float()
  external double temperature;
  @Float()
  external double temperatureIncrement;
  @Float()
  external double entropyThreshold;
  @Float()
  external double logProbabilityThreshold;
  @Float()
  external double noSpeechThreshold;
  @Int32()
  external int vadEnabled;
  @Float()
  external double vadThreshold;
  @Int32()
  external int vadMinSpeechMs;
  @Int32()
  external int vadMinSilenceMs;
  @Float()
  external double vadMaxSpeechSeconds;
  @Int32()
  external int vadSpeechPaddingMs;
  @Float()
  external double vadSamplesOverlap;
  external Pointer<Utf8> language;
  external Pointer<Utf8> initialPrompt;
  external Pointer<Utf8> suppressRegex;
  external Pointer<Utf8> vadModelPath;
  external Pointer<NativeFunction<_ProgressN>> progressCallback;
}

final class FlutterWhisperNative implements WhisperBackend {
  FlutterWhisperNative._(this._context, this._bindings);
  final Pointer<Void> _context;
  final _Bindings _bindings;
  bool _disposed = false;
  bool _transcribing = false;

  static List<WhisperDevice> get availableDevices {
    final bindings = _Bindings.open();
    final devices = <WhisperDevice>[];
    var gpuIndex = 0;
    for (var index = 0; index < bindings.deviceCount(); index++) {
      final type = _deviceType(bindings.deviceType(index));
      final isGpu =
          type == WhisperDeviceType.gpu ||
          type == WhisperDeviceType.integratedGpu;
      devices.add(
        WhisperDevice(
          index: index,
          gpuIndex: isGpu ? gpuIndex++ : null,
          name: bindings.deviceName(index).toDartString(),
          description: bindings.deviceDescription(index).toDartString(),
          type: type,
          freeMemory: bindings.deviceMemoryFree(index),
          totalMemory: bindings.deviceMemoryTotal(index),
        ),
      );
    }
    return List.unmodifiable(devices);
  }

  static Future<FlutterWhisperNative> load(
    String path,
    WhisperModelConfig config,
  ) async {
    final file = File(path);
    if (!await file.exists()) {
      throw WhisperException('Model file does not exist: $path');
    }
    final size = await file.length();
    if (size < 1024 * 1024) {
      throw WhisperException(
        'The selected file is not a complete Whisper model ($size bytes). Files named for-tests-* contain headers only.',
      );
    }
    final handle = await file.open();
    try {
      final header = await handle.read(4);
      if (header.length != 4 ||
          ByteData.sublistView(header).getUint32(0, Endian.little) !=
              0x67676d6c) {
        throw const WhisperException(
          'The selected file is not a valid GGML Whisper model (bad magic).',
        );
      }
    } finally {
      await handle.close();
    }
    final address = await Isolate.run(() => _load(path, config));
    return FlutterWhisperNative._(
      Pointer<Void>.fromAddress(address),
      _Bindings.open(),
    );
  }

  @override
  Future<WhisperResult> transcribe(
    Float32List samples,
    WhisperTranscribeConfig config, {
    void Function(int progress)? onProgress,
    void Function(WhisperSegment segment)? onSegment,
  }) async {
    if (_disposed) throw StateError('Native context is disposed.');
    if (samples.isEmpty) {
      throw const WhisperException('Audio samples cannot be empty.');
    }
    if (_transcribing) {
      throw StateError('A native transcription is already in progress.');
    }
    final events = onProgress != null || onSegment != null
        ? ReceivePort()
        : null;
    final job = _TranscriptionJob(
      contextAddress: _context.address,
      samples: samples,
      config: config,
      events: events?.sendPort,
      reportProgress: onProgress != null,
      reportSegments: onSegment != null,
    );
    _bindings.prepareTranscription(_context);
    _transcribing = true;
    try {
      final inference = Isolate.run(job.run);
      if (events == null) return await inference;
      final delivery = events.takeWhile((event) => event != null).forEach((
        event,
      ) {
        if (event is int) {
          onProgress?.call(event.clamp(0, 100));
        } else if (event is WhisperSegment) {
          onSegment?.call(event);
        }
      });
      final results = await Future.wait<Object?>([
        inference.then<WhisperResult>(
          (result) => result,
          onError: (Object error, StackTrace stack) {
            events.close();
            Error.throwWithStackTrace(error, stack);
          },
        ),
        delivery,
      ]);
      return results.first as WhisperResult;
    } finally {
      events?.close();
      _transcribing = false;
      if (_disposed) _bindings.destroy(_context);
    }
  }

  @override
  void cancel() {
    if (!_disposed && _transcribing) _bindings.cancel(_context);
  }

  @override
  void dispose() {
    if (!_disposed) {
      _disposed = true;
      if (!_transcribing) _bindings.destroy(_context);
    }
  }
}

WhisperDeviceType _deviceType(int value) => switch (value) {
  0 => WhisperDeviceType.cpu,
  1 => WhisperDeviceType.gpu,
  2 => WhisperDeviceType.integratedGpu,
  3 => WhisperDeviceType.accelerator,
  4 => WhisperDeviceType.meta,
  _ => WhisperDeviceType.unknown,
};

final class _TranscriptionJob {
  const _TranscriptionJob({
    required this.contextAddress,
    required this.samples,
    required this.config,
    required this.events,
    required this.reportProgress,
    required this.reportSegments,
  });

  final int contextAddress;
  final Float32List samples;
  final WhisperTranscribeConfig config;
  final SendPort? events;
  final bool reportProgress;
  final bool reportSegments;

  WhisperResult run() {
    try {
      return _transcribe(this);
    } finally {
      events?.send(null);
    }
  }
}

int _load(String path, WhisperModelConfig config) {
  final bindings = _Bindings.open();
  final nativePath = path.toNativeUtf8();
  try {
    final value = bindings.create(
      nativePath,
      config.useGpu ? 1 : 0,
      config.flashAttention ? 1 : 0,
      config.gpuDevice,
    );
    if (value == nullptr) {
      throw const WhisperException('whisper.cpp could not load the model.');
    }
    return value.address;
  } finally {
    malloc.free(nativePath);
  }
}

WhisperResult _transcribe(_TranscriptionJob job) {
  final b = _Bindings.open();
  final context = Pointer<Void>.fromAddress(job.contextAddress);
  final samples = job.samples;
  final config = job.config;
  final pcm = calloc<Float>(samples.length);
  final options = calloc<_OptionsV2>();
  final language = config.language.toNativeUtf8();
  final prompt = config.initialPrompt?.toNativeUtf8();
  final regex = config.suppressRegex?.toNativeUtf8();
  final vadPath = config.vad?.modelPath.toNativeUtf8();
  NativeCallable<_ProgressN>? progressCallback;
  NativeCallable<_ProgressN>? segmentCallback;
  try {
    pcm.asTypedList(samples.length).setAll(0, samples);
    final o = options.ref;
    o
      ..abiVersion = 2
      ..structSize = sizeOf<_OptionsV2>()
      ..strategy = config.strategy.index
      ..threads = config.threads
      ..offsetMs = config.offset.inMilliseconds
      ..durationMs = config.duration?.inMilliseconds ?? 0
      ..translate = config.translate ? 1 : 0
      ..noContext = config.noContext ? 1 : 0
      ..tokenTimestamps = config.tokenTimestamps ? 1 : 0
      ..singleSegment = config.singleSegment ? 1 : 0
      ..maxSegmentLength = config.maxSegmentLength
      ..splitOnWord = config.splitOnWord ? 1 : 0
      ..maxTokens = config.maxTokensPerSegment
      ..audioContext = config.audioContext
      ..tinyDiarize = config.tinyDiarize ? 1 : 0
      ..bestOf = config.bestOf
      ..beamSize = config.beamSize
      ..beamPatience = config.beamPatience
      ..temperature = config.temperature
      ..temperatureIncrement = config.temperatureIncrement
      ..entropyThreshold = config.entropyThreshold
      ..logProbabilityThreshold = config.logProbabilityThreshold
      ..noSpeechThreshold = config.noSpeechThreshold
      ..vadEnabled = config.vad == null ? 0 : 1
      ..vadThreshold = config.vad?.threshold ?? 0.5
      ..vadMinSpeechMs = config.vad?.minimumSpeechDuration.inMilliseconds ?? 250
      ..vadMinSilenceMs =
          config.vad?.minimumSilenceDuration.inMilliseconds ?? 100
      ..vadMaxSpeechSeconds =
          (config.vad?.maximumSpeechDuration.inMilliseconds ?? 30000) / 1000
      ..vadSpeechPaddingMs = config.vad?.speechPadding.inMilliseconds ?? 30
      ..vadSamplesOverlap = config.vad?.samplesOverlap ?? 0.1
      ..language = language
      ..initialPrompt = prompt ?? nullptr
      ..suppressRegex = regex ?? nullptr
      ..vadModelPath = vadPath ?? nullptr;
    if (job.reportProgress) {
      progressCallback = NativeCallable<_ProgressN>.isolateLocal(
        (int progress) => job.events!.send(progress),
      );
    }
    if (job.reportSegments) {
      segmentCallback = NativeCallable<_ProgressN>.isolateLocal(
        (int segment) => job.events!.send(_readSegment(b, context, segment)),
      );
    }
    o.progressCallback = progressCallback?.nativeFunction ?? nullptr;
    final code = b.transcribe(
      context,
      pcm,
      samples.length,
      options,
      segmentCallback?.nativeFunction ?? nullptr,
    );
    if (code != 0) {
      throw WhisperException(b.lastError(context).toDartString(), code: code);
    }

    final segments = List.generate(
      b.segmentCount(context),
      (index) => _readSegment(b, context, index),
      growable: false,
    );
    final vad = List.generate(
      b.vadCount(context),
      (i) => WhisperVadSegment(
        start: _cs(b.vadStart(context, i)),
        end: _cs(b.vadEnd(context, i)),
      ),
      growable: false,
    );
    return WhisperResult(
      language: b.resultLanguage(context).toDartString(),
      segments: segments,
      vadSegments: vad,
      timings: WhisperTimings(
        sample: _ms(b.timing(context, 0)),
        encode: _ms(b.timing(context, 1)),
        decode: _ms(b.timing(context, 2)),
        batchDecode: _ms(b.timing(context, 3)),
        prompt: _ms(b.timing(context, 4)),
      ),
    );
  } finally {
    progressCallback?.close();
    segmentCallback?.close();
    calloc.free(pcm);
    calloc.free(options);
    malloc.free(language);
    if (prompt != null) malloc.free(prompt);
    if (regex != null) malloc.free(regex);
    if (vadPath != null) malloc.free(vadPath);
  }
}

WhisperSegment _readSegment(_Bindings b, Pointer<Void> context, int segment) {
  return WhisperSegment(
    text: b.segmentText(context, segment).toDartString(),
    start: _cs(b.segmentStart(context, segment)),
    end: _cs(b.segmentEnd(context, segment)),
    speakerTurnNext: b.speakerTurn(context, segment) != 0,
    noSpeechProbability: b.noSpeech(context, segment),
    tokens: List.generate(b.tokenCount(context, segment), (token) {
      final text = b.tokenText(context, segment, token);
      return WhisperToken(
        id: b.tokenId(context, segment, token),
        text: utf8.decode(
          text.cast<Uint8>().asTypedList(text.length),
          allowMalformed: true,
        ),
        probability: b.tokenProbability(context, segment, token),
        start: _cs(b.tokenStart(context, segment, token)),
        end: _cs(b.tokenEnd(context, segment, token)),
      );
    }, growable: false),
  );
}

Duration _cs(int value) => Duration(milliseconds: value * 10);
Duration _ms(double value) => Duration(microseconds: (value * 1000).round());

final class _Bindings {
  _Bindings(this.library)
    : deviceCount = library.lookupFunction<_CountN, _CountD>('fw_device_count'),
      deviceName = library.lookupFunction<_IndexedTextN, _IndexedTextD>(
        'fw_device_name',
      ),
      deviceDescription = library.lookupFunction<_IndexedTextN, _IndexedTextD>(
        'fw_device_description',
      ),
      deviceType = library.lookupFunction<_IndexedIntN, _IndexedIntD>(
        'fw_device_type',
      ),
      deviceMemoryFree = library
          .lookupFunction<_IndexedUint64N, _IndexedUint64D>(
            'fw_device_memory_free',
          ),
      deviceMemoryTotal = library
          .lookupFunction<_IndexedUint64N, _IndexedUint64D>(
            'fw_device_memory_total',
          ),
      create = library.lookupFunction<_CreateN, _CreateD>('fw_create'),
      destroy = library.lookupFunction<_VoidN, _VoidD>('fw_destroy'),
      prepareTranscription = library.lookupFunction<_VoidN, _VoidD>(
        'fw_prepare_transcription',
      ),
      transcribe = library.lookupFunction<_TranscribeN, _TranscribeD>(
        'fw_transcribe_v3',
      ),
      cancel = library.lookupFunction<_VoidN, _VoidD>('fw_cancel'),
      segmentCount = library.lookupFunction<_Int1N, _Int1D>('fw_segment_count'),
      segmentText = library.lookupFunction<_Text2N, _Text2D>('fw_segment_text'),
      segmentStart = library.lookupFunction<_Time2N, _Time2D>(
        'fw_segment_start',
      ),
      segmentEnd = library.lookupFunction<_Time2N, _Time2D>('fw_segment_end'),
      speakerTurn = library.lookupFunction<_Int2N, _Int2D>(
        'fw_segment_speaker_turn_next',
      ),
      noSpeech = library.lookupFunction<_Float2N, _Float2D>(
        'fw_segment_no_speech_probability',
      ),
      tokenCount = library.lookupFunction<_Int2N, _Int2D>('fw_token_count'),
      tokenId = library.lookupFunction<_Int3N, _Int3D>('fw_token_id'),
      tokenText = library.lookupFunction<_Text3N, _Text3D>('fw_token_text'),
      tokenProbability = library.lookupFunction<_Float3N, _Float3D>(
        'fw_token_probability',
      ),
      tokenStart = library.lookupFunction<_Time3N, _Time3D>('fw_token_start'),
      tokenEnd = library.lookupFunction<_Time3N, _Time3D>('fw_token_end'),
      vadCount = library.lookupFunction<_Int1N, _Int1D>('fw_vad_segment_count'),
      vadStart = library.lookupFunction<_Time2N, _Time2D>(
        'fw_vad_segment_start',
      ),
      vadEnd = library.lookupFunction<_Time2N, _Time2D>('fw_vad_segment_end'),
      timing = library.lookupFunction<_Float2N, _Float2D>('fw_timing_ms'),
      resultLanguage = library.lookupFunction<_Text1N, _Text1D>(
        'fw_result_language',
      ),
      lastError = library.lookupFunction<_Text1N, _Text1D>('fw_last_error');
  factory _Bindings.open() {
    if (Platform.isIOS || Platform.isMacOS) {
      return _Bindings(DynamicLibrary.process());
    }
    final libraryName = switch (Platform.operatingSystem) {
      'windows' => 'flutter_whisper_plugin.dll',
      'linux' || 'android' => 'libflutter_whisper_plugin.so',
      _ => throw UnsupportedError(
        'flutter_whisper native is unsupported on '
        '${Platform.operatingSystem}.',
      ),
    };
    return _Bindings(DynamicLibrary.open(libraryName));
  }
  final DynamicLibrary library;
  final _CountD deviceCount;
  final _IndexedTextD deviceName;
  final _IndexedTextD deviceDescription;
  final _IndexedIntD deviceType;
  final _IndexedUint64D deviceMemoryFree;
  final _IndexedUint64D deviceMemoryTotal;
  final _CreateD create;
  final _VoidD destroy;
  final _VoidD prepareTranscription;
  final _TranscribeD transcribe;
  final _VoidD cancel;
  final _Int1D segmentCount;
  final _Text2D segmentText;
  final _Time2D segmentStart;
  final _Time2D segmentEnd;
  final _Int2D speakerTurn;
  final _Float2D noSpeech;
  final _Int2D tokenCount;
  final _Int3D tokenId;
  final _Text3D tokenText;
  final _Float3D tokenProbability;
  final _Time3D tokenStart;
  final _Time3D tokenEnd;
  final _Int1D vadCount;
  final _Time2D vadStart;
  final _Time2D vadEnd;
  final _Float2D timing;
  final _Text1D resultLanguage;
  final _Text1D lastError;
}
