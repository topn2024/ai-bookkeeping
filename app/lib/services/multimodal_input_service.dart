import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'voice_recognition_engine.dart';
import 'nlu_engine.dart';

/// 多模态输入统一服务
/// 提供语音、图像、文本的统一入口，简化上层调用
class UnifiedRecognitionService {
  final VoiceRecognitionEngine _voiceEngine;
  final ImageRecognitionEngine _imageEngine;
  final NLUEngine _nluEngine;
  final InputPreprocessor _preprocessor;

  UnifiedRecognitionService({
    VoiceRecognitionEngine? voiceEngine,
    ImageRecognitionEngine? imageEngine,
    NLUEngine? nluEngine,
  })  : _voiceEngine = voiceEngine ?? VoiceRecognitionEngine(),
        _imageEngine = imageEngine ?? ImageRecognitionEngine(),
        _nluEngine = nluEngine ?? NLUEngine(),
        _preprocessor = InputPreprocessor();

  /// 统一识别入口
  Future<RecognitionResult> recognize(RecognitionInput input) async {
    switch (input.type) {
      case InputType.voice:
        return await _processVoice(input as VoiceInput);
      case InputType.image:
        return await _processImage(input as ImageInput);
      case InputType.text:
        return await _processText(input as TextInput);
      case InputType.mixed:
        return await _processMixed(input as MixedInput);
    }
  }

  /// 处理语音输入
  Future<RecognitionResult> _processVoice(VoiceInput input) async {
    final startTime = DateTime.now();

    // 1. 音频预处理
    final processedAudio = await _preprocessor.preprocessAudio(input.audioData);

    // 2. 语音转文本
    final asrResult = await _voiceEngine.transcribe(processedAudio);

    // 3. NLU解析
    final nluResult = await _nluEngine.parse(
      asrResult.text,
      context: input.context,
    );

    // 4. 构建结果
    return RecognitionResult(
      source: RecognitionSource.voice,
      rawText: asrResult.text,
      transactions: nluResult.transactions,
      confidence: _calculateConfidence(asrResult.confidence, nluResult.confidence),
      metadata: RecognitionMetadata(
        asrConfidence: asrResult.confidence,
        nluConfidence: nluResult.confidence,
        processingTime: DateTime.now().difference(startTime),
      ),
    );
  }

  /// 处理图像输入
  Future<RecognitionResult> _processImage(ImageInput input) async {
    final startTime = DateTime.now();

    // 1. 图像预处理
    final processedImage = await _preprocessor.preprocessImage(input.imageData);

    // 2. 图像类型检测
    final imageType = await _imageEngine.detectType(processedImage);

    // 3. 根据类型选择处理策略
    final ocrResult = await _imageEngine.process(processedImage, imageType);

    // 4. NLU解析（对于需要语义理解的图像）
    final nluResult = imageType.needsNLU
        ? await _nluEngine.parse(ocrResult.text, context: input.context)
        : NLUResult(
            intent: NLUIntent(type: IntentType.recordExpense, confidence: 0.8),
            entities: [],
            transactions: ocrResult.transactions,
            confidence: ocrResult.confidence,
            rawText: ocrResult.text,
            normalizedText: ocrResult.text,
          );

    return RecognitionResult(
      source: RecognitionSource.image,
      rawText: ocrResult.text,
      transactions: nluResult.transactions,
      confidence: _calculateConfidence(ocrResult.confidence, nluResult.confidence),
      imageType: imageType,
      metadata: RecognitionMetadata(
        ocrConfidence: ocrResult.confidence,
        nluConfidence: nluResult.confidence,
        detectedFields: ocrResult.detectedFields,
        processingTime: DateTime.now().difference(startTime),
      ),
    );
  }

  /// 处理文本输入
  Future<RecognitionResult> _processText(TextInput input) async {
    final startTime = DateTime.now();

    // NLU解析
    final nluResult = await _nluEngine.parse(
      input.text,
      context: input.context,
    );

    return RecognitionResult(
      source: RecognitionSource.text,
      rawText: input.text,
      transactions: nluResult.transactions,
      confidence: nluResult.confidence,
      metadata: RecognitionMetadata(
        nluConfidence: nluResult.confidence,
        processingTime: DateTime.now().difference(startTime),
      ),
    );
  }

  /// 处理混合输入（如语音+截图）
  Future<RecognitionResult> _processMixed(MixedInput input) async {
    // 并行处理各模态
    final futures = <Future<RecognitionResult>>[];

    if (input.voiceInput != null) {
      futures.add(_processVoice(input.voiceInput!));
    }
    if (input.imageInput != null) {
      futures.add(_processImage(input.imageInput!));
    }
    if (input.textInput != null) {
      futures.add(_processText(input.textInput!));
    }

    final results = await Future.wait(futures);

    // 融合多模态结果
    return _fuseResults(results);
  }

  /// 多模态结果融合
  RecognitionResult _fuseResults(List<RecognitionResult> results) {
    if (results.length == 1) return results.first;

    final transactions = <ParsedTransaction>[];
    final seenAmounts = <double>{};

    // 优先使用高置信度结果
    final sortedResults = List<RecognitionResult>.from(results)
      ..sort((a, b) => b.confidence.compareTo(a.confidence));

    for (final result in sortedResults) {
      for (final tx in result.transactions) {
        // 去重：相同金额的交易只保留置信度最高的
        if (!seenAmounts.contains(tx.amount)) {
          transactions.add(tx);
          seenAmounts.add(tx.amount);
        }
      }
    }

    return RecognitionResult(
      source: RecognitionSource.mixed,
      rawText: sortedResults.first.rawText,
      transactions: transactions,
      confidence: sortedResults.first.confidence,
      fusedFrom: results.map((r) => r.source).toList(),
      metadata: RecognitionMetadata(
        processingTime: Duration.zero,
      ),
    );
  }

  /// 计算综合置信度
  double _calculateConfidence(double conf1, double conf2) {
    return (conf1 + conf2) / 2;
  }

  /// 初始化服务
  Future<void> initialize() async {
    await _voiceEngine.initializeOfflineModel();
    await _imageEngine.initialize();
  }

  /// 释放资源
  void dispose() {
    _voiceEngine.dispose();
  }
}

/// 输入预处理服务
class InputPreprocessor {
  /// 音频预处理
  Future<ProcessedAudio> preprocessAudio(Uint8List rawAudio) async {
    // 1. 格式转换（统一为16kHz单声道PCM）
    final normalized = await _normalizeAudioFormat(rawAudio);

    // 2. 降噪处理
    final denoised = await _applyNoiseReduction(normalized);

    // 3. VAD（语音活动检测）切分
    final segments = await _detectVoiceSegments(denoised);

    // 4. 静音段过滤
    final filtered = segments.where((s) => s.isSpeech).toList();

    return ProcessedAudio(
      data: filtered.isEmpty ? denoised : _mergeSegments(filtered, denoised),
      segments: filtered,
      duration: _calculateDuration(filtered),
    );
  }

  /// 图像预处理
  Future<ProcessedImage> preprocessImage(Uint8List rawImage) async {
    // 1. 解码图像
    final decoded = await _decodeImage(rawImage);

    // 2. 方向校正（EXIF信息）
    final oriented = await _correctOrientation(decoded);

    // 3. 尺寸归一化（保持宽高比，最大边1920）
    final resized = await _resizeIfNeeded(oriented, maxSize: 1920);

    // 4. 对比度增强（可选，针对小票等低对比度图像）
    final enhanced = await _enhanceContrastIfNeeded(resized);

    return ProcessedImage(
      data: enhanced,
      originalWidth: decoded.width,
      originalHeight: decoded.height,
      processedWidth: resized.width,
      processedHeight: resized.height,
    );
  }

  /// VAD语音活动检测
  Future<List<AudioSegment>> _detectVoiceSegments(Uint8List audio) async {
    final segments = <AudioSegment>[];
    const frameSize = 480; // 30ms at 16kHz
    const threshold = 0.02;

    int speechStart = -1;
    int silenceCount = 0;
    const maxSilenceFrames = 15;

    for (int i = 0; i < audio.length; i += frameSize * 2) {
      final frameEnd = min(i + frameSize * 2, audio.length);
      final frame = audio.sublist(i, frameEnd);
      final energy = _calculateFrameEnergy(frame);

      if (energy > threshold) {
        if (speechStart == -1) {
          speechStart = i;
        }
        silenceCount = 0;
      } else {
        if (speechStart != -1) {
          silenceCount++;
          if (silenceCount >= maxSilenceFrames) {
            segments.add(AudioSegment(
              startMs: (speechStart / 32).round(),
              endMs: (i / 32).round(),
              isSpeech: true,
            ));
            speechStart = -1;
            silenceCount = 0;
          }
        }
      }
    }

    if (speechStart != -1) {
      segments.add(AudioSegment(
        startMs: (speechStart / 32).round(),
        endMs: (audio.length / 32).round(),
        isSpeech: true,
      ));
    }

    return segments;
  }

  double _calculateFrameEnergy(Uint8List frame) {
    if (frame.isEmpty) return 0;
    double sum = 0;
    for (int i = 0; i < frame.length - 1; i += 2) {
      final sample = (frame[i] | (frame[i + 1] << 8)).toSigned(16);
      sum += sample * sample;
    }
    return sqrt(sum / (frame.length / 2)) / 32768;
  }

  Future<Uint8List> _normalizeAudioFormat(Uint8List audio) async {
    // 实际实现需要音频格式转换
    return audio;
  }

  Future<Uint8List> _applyNoiseReduction(Uint8List audio) async {
    // 实际实现需要降噪处理
    return audio;
  }

  Uint8List _mergeSegments(List<AudioSegment> segments, Uint8List audio) {
    // 简化实现：返回原始音频
    return audio;
  }

  Duration _calculateDuration(List<AudioSegment> segments) {
    if (segments.isEmpty) return Duration.zero;
    final totalMs = segments.fold<int>(
      0,
      (sum, s) => sum + (s.endMs - s.startMs),
    );
    return Duration(milliseconds: totalMs);
  }

  Future<DecodedImage> _decodeImage(Uint8List data) async {
    // 实际实现需要图像解码
    return DecodedImage(data: data, width: 1920, height: 1080);
  }

  Future<DecodedImage> _correctOrientation(DecodedImage image) async {
    return image;
  }

  Future<DecodedImage> _resizeIfNeeded(DecodedImage image,
      {required int maxSize}) async {
    return image;
  }

  Future<Uint8List> _enhanceContrastIfNeeded(DecodedImage image) async {
    return image.data;
  }
}

/// 图像识别引擎
class ImageRecognitionEngine {
  final OCRService _ocrService;
  final ImageClassifier _classifier;
  final ReceiptParser _receiptParser;
  final ScreenshotParser _screenshotParser;

  ImageRecognitionEngine({
    OCRService? ocrService,
    ImageClassifier? classifier,
  })  : _ocrService = ocrService ?? OCRService(),
        _classifier = classifier ?? ImageClassifier(),
        _receiptParser = ReceiptParser(),
        _screenshotParser = ScreenshotParser();

  Future<void> initialize() async {
    await _classifier.initialize();
  }

  /// 检测图像类型
  Future<ImageType> detectType(ProcessedImage image) async {
    final classResult = await _classifier.classify(image);

    if (classResult.confidence > 0.7) {
      return classResult.type;
    }

    // 默认为一般图像
    return ImageType.general;
  }

  /// 处理图像
  Future<OCRResult> process(ProcessedImage image, ImageType type) async {
    switch (type) {
      case ImageType.receipt:
        return await _receiptParser.parse(image);
      case ImageType.screenshot:
        return await _screenshotParser.parse(image);
      case ImageType.bankStatement:
        return await _ocrService.recognize(image);
      case ImageType.general:
      default:
        return await _ocrService.recognize(image);
    }
  }
}

/// OCR服务
class OCRService {
  Future<OCRResult> recognize(ProcessedImage image) async {
    // 实际实现需要调用OCR API
    await Future.delayed(const Duration(milliseconds: 300));

    return OCRResult(
      text: '识别的文本内容',
      confidence: 0.8,
      detectedFields: {},
      transactions: [],
    );
  }
}

/// 图像分类器
class ImageClassifier {
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    await Future.delayed(const Duration(milliseconds: 200));
    _isInitialized = true;
  }

  Future<ImageClassificationResult> classify(ProcessedImage image) async {
    if (!_isInitialized) await initialize();

    // 模拟分类
    return ImageClassificationResult(
      type: ImageType.general,
      confidence: 0.8,
    );
  }
}

/// 小票解析器
class ReceiptParser {
  Future<OCRResult> parse(ProcessedImage image) async {
    // 实际实现需要专门的小票OCR
    await Future.delayed(const Duration(milliseconds: 400));

    return OCRResult(
      text: '小票内容',
      confidence: 0.85,
      detectedFields: {
        'merchant': '商家名称',
        'total': '金额',
        'date': '日期',
      },
      transactions: [],
    );
  }
}

/// 截图解析器
class ScreenshotParser {
  Future<OCRResult> parse(ProcessedImage image) async {
    // 实际实现需要专门的截图OCR
    await Future.delayed(const Duration(milliseconds: 400));

    return OCRResult(
      text: '截图内容',
      confidence: 0.8,
      detectedFields: {},
      transactions: [],
    );
  }
}

// ==================== 数据模型 ====================

/// 输入类型
enum InputType {
  voice,
  image,
  text,
  mixed,
}

/// 识别输入基类
abstract class RecognitionInput {
  InputType get type;
  NLUContext? get context;
  DateTime get timestamp;
}

/// 语音输入
class VoiceInput implements RecognitionInput {
  @override
  final InputType type = InputType.voice;
  final Uint8List audioData;
  @override
  final NLUContext? context;
  @override
  final DateTime timestamp;

  VoiceInput({
    required this.audioData,
    this.context,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// 图像输入
class ImageInput implements RecognitionInput {
  @override
  final InputType type = InputType.image;
  final Uint8List imageData;
  @override
  final NLUContext? context;
  @override
  final DateTime timestamp;

  ImageInput({
    required this.imageData,
    this.context,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// 文本输入
class TextInput implements RecognitionInput {
  @override
  final InputType type = InputType.text;
  final String text;
  @override
  final NLUContext? context;
  @override
  final DateTime timestamp;

  TextInput({
    required this.text,
    this.context,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// 混合输入
class MixedInput implements RecognitionInput {
  @override
  final InputType type = InputType.mixed;
  final VoiceInput? voiceInput;
  final ImageInput? imageInput;
  final TextInput? textInput;
  @override
  final DateTime timestamp;

  @override
  NLUContext? get context =>
      voiceInput?.context ?? imageInput?.context ?? textInput?.context;

  MixedInput({
    this.voiceInput,
    this.imageInput,
    this.textInput,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// 识别来源
enum RecognitionSource {
  voice,
  image,
  text,
  mixed,
}

/// 识别结果
class RecognitionResult {
  final RecognitionSource source;
  final String rawText;
  final List<ParsedTransaction> transactions;
  final double confidence;
  final ImageType? imageType;
  final List<RecognitionSource>? fusedFrom;
  final RecognitionMetadata metadata;

  const RecognitionResult({
    required this.source,
    required this.rawText,
    required this.transactions,
    required this.confidence,
    this.imageType,
    this.fusedFrom,
    required this.metadata,
  });

  bool get hasTransactions => transactions.isNotEmpty;
}

/// 识别元数据
class RecognitionMetadata {
  final double? asrConfidence;
  final double? ocrConfidence;
  final double? nluConfidence;
  final Map<String, String>? detectedFields;
  final Duration processingTime;

  const RecognitionMetadata({
    this.asrConfidence,
    this.ocrConfidence,
    this.nluConfidence,
    this.detectedFields,
    required this.processingTime,
  });
}

/// 图像类型
enum ImageType {
  receipt,       // 小票/发票
  screenshot,    // 截图
  bankStatement, // 银行账单
  general,       // 一般图像
}

extension ImageTypeExtension on ImageType {
  bool get needsNLU {
    switch (this) {
      case ImageType.receipt:
        return false;
      case ImageType.bankStatement:
        return false;
      default:
        return true;
    }
  }
}

/// 处理后的图像
class ProcessedImage {
  final Uint8List data;
  final int originalWidth;
  final int originalHeight;
  final int processedWidth;
  final int processedHeight;

  const ProcessedImage({
    required this.data,
    required this.originalWidth,
    required this.originalHeight,
    required this.processedWidth,
    required this.processedHeight,
  });
}

/// 解码后的图像
class DecodedImage {
  final Uint8List data;
  final int width;
  final int height;

  const DecodedImage({
    required this.data,
    required this.width,
    required this.height,
  });
}

/// OCR结果
class OCRResult {
  final String text;
  final double confidence;
  final Map<String, String> detectedFields;
  final List<ParsedTransaction> transactions;

  const OCRResult({
    required this.text,
    required this.confidence,
    required this.detectedFields,
    required this.transactions,
  });
}

/// 图像分类结果
class ImageClassificationResult {
  final ImageType type;
  final double confidence;

  const ImageClassificationResult({
    required this.type,
    required this.confidence,
  });
}
