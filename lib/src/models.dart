import 'package:flutter/foundation.dart';

enum WhisperSamplingStrategy { greedy, beamSearch }

enum WhisperDeviceType { cpu, gpu, integratedGpu, accelerator, meta, unknown }

@immutable
class WhisperDevice {
  const WhisperDevice({
    required this.index,
    required this.gpuIndex,
    required this.name,
    required this.description,
    required this.type,
    required this.freeMemory,
    required this.totalMemory,
  });

  final int index;
  final int? gpuIndex;
  final String name;
  final String description;
  final WhisperDeviceType type;
  final int freeMemory;
  final int totalMemory;

  bool get isGpu =>
      type == WhisperDeviceType.gpu || type == WhisperDeviceType.integratedGpu;
}

/// Model initialization options.
@immutable
class WhisperModelConfig {
  const WhisperModelConfig({
    this.useGpu = true,
    this.flashAttention = true,
    this.gpuDevice = 0,
  });

  final bool useGpu;
  final bool flashAttention;
  final int gpuDevice;

  factory WhisperModelConfig.forDevice(
    WhisperDevice device, {
    bool flashAttention = true,
  }) => WhisperModelConfig(
    useGpu: device.isGpu,
    flashAttention: flashAttention,
    gpuDevice: device.gpuIndex ?? 0,
  );
}

/// Options applied to one transcription.
@immutable
class WhisperTranscribeConfig {
  const WhisperTranscribeConfig({
    this.language = 'auto',
    this.translate = false,
    this.threads = 0,
    this.tokenTimestamps = false,
    this.noContext = false,
    this.strategy = WhisperSamplingStrategy.greedy,
    this.offset = Duration.zero,
    this.duration,
    this.singleSegment = false,
    this.initialPrompt,
    this.maxSegmentLength = 0,
    this.splitOnWord = false,
    this.maxTokensPerSegment = 0,
    this.audioContext = 0,
    this.tinyDiarize = false,
    this.suppressRegex,
    this.temperature = 0,
    this.temperatureIncrement = 0.2,
    this.entropyThreshold = 2.4,
    this.logProbabilityThreshold = -1,
    this.noSpeechThreshold = 0.6,
    this.bestOf = 5,
    this.beamSize = 5,
    this.beamPatience = -1,
    this.vad,
  });

  final String language;
  final bool translate;
  final int threads;
  final bool tokenTimestamps;
  final bool noContext;
  final WhisperSamplingStrategy strategy;
  final Duration offset;
  final Duration? duration;
  final bool singleSegment;
  final String? initialPrompt;
  final int maxSegmentLength;
  final bool splitOnWord;
  final int maxTokensPerSegment;
  final int audioContext;
  final bool tinyDiarize;
  final String? suppressRegex;
  final double temperature;
  final double temperatureIncrement;
  final double entropyThreshold;
  final double logProbabilityThreshold;
  final double noSpeechThreshold;
  final int bestOf;
  final int beamSize;
  final double beamPatience;
  final WhisperVadConfig? vad;
}

@immutable
class WhisperVadConfig {
  const WhisperVadConfig({
    required this.modelPath,
    this.threshold = 0.5,
    this.minimumSpeechDuration = const Duration(milliseconds: 250),
    this.minimumSilenceDuration = const Duration(milliseconds: 100),
    this.maximumSpeechDuration = const Duration(seconds: 30),
    this.speechPadding = const Duration(milliseconds: 30),
    this.samplesOverlap = 0.1,
  });

  final String modelPath;
  final double threshold;
  final Duration minimumSpeechDuration;
  final Duration minimumSilenceDuration;
  final Duration maximumSpeechDuration;
  final Duration speechPadding;
  final double samplesOverlap;
}

@immutable
class WhisperToken {
  const WhisperToken({
    required this.id,
    required this.text,
    required this.probability,
    required this.start,
    required this.end,
  });

  final int id;
  final String text;
  final double probability;
  final Duration start;
  final Duration end;
}

/// One timestamped text segment.
@immutable
class WhisperSegment {
  const WhisperSegment({
    required this.text,
    required this.start,
    required this.end,
    this.speakerTurnNext = false,
    this.noSpeechProbability = 0,
    this.tokens = const [],
  });

  final String text;
  final Duration start;
  final Duration end;
  final bool speakerTurnNext;
  final double noSpeechProbability;
  final List<WhisperToken> tokens;
}

@immutable
class WhisperVadSegment {
  const WhisperVadSegment({required this.start, required this.end});
  final Duration start;
  final Duration end;
}

@immutable
class WhisperTimings {
  const WhisperTimings({
    required this.sample,
    required this.encode,
    required this.decode,
    required this.batchDecode,
    required this.prompt,
  });

  final Duration sample;
  final Duration encode;
  final Duration decode;
  final Duration batchDecode;
  final Duration prompt;
}

/// Immutable result of one transcription.
@immutable
class WhisperResult {
  const WhisperResult({
    required this.language,
    required this.segments,
    this.vadSegments = const [],
    this.timings,
  });

  final String language;
  final List<WhisperSegment> segments;
  final List<WhisperVadSegment> vadSegments;
  final WhisperTimings? timings;

  String get text => segments.map((segment) => segment.text).join();
}
