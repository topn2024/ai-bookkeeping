import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ai_service.dart';

/// AI识别状态
enum AIRecognitionStatus {
  idle,        // 空闲
  processing,  // 处理中
  success,     // 成功
  error,       // 错误
}

/// AI记账状态
class AIBookkeepingState {
  final AIRecognitionStatus status;
  final AIRecognitionResult? result;
  final MultiAIRecognitionResult? multiResult;  // 多笔交易结果
  final String? errorMessage;
  final bool isRecording;  // 是否正在录音

  const AIBookkeepingState({
    this.status = AIRecognitionStatus.idle,
    this.result,
    this.multiResult,
    this.errorMessage,
    this.isRecording = false,
  });

  AIBookkeepingState copyWith({
    AIRecognitionStatus? status,
    AIRecognitionResult? result,
    MultiAIRecognitionResult? multiResult,
    String? errorMessage,
    bool? isRecording,
  }) {
    return AIBookkeepingState(
      status: status ?? this.status,
      result: result ?? this.result,
      multiResult: multiResult ?? this.multiResult,
      errorMessage: errorMessage ?? this.errorMessage,
      isRecording: isRecording ?? this.isRecording,
    );
  }

  bool get isProcessing => status == AIRecognitionStatus.processing;
  bool get isSuccess => status == AIRecognitionStatus.success;
  bool get isError => status == AIRecognitionStatus.error;
  bool get hasResult => result != null && result!.success;
  bool get hasMultiResult => multiResult != null && multiResult!.success;
  bool get isMultiTransaction => multiResult != null && multiResult!.isMultiple;
}

/// AI记账Notifier
class AIBookkeepingNotifier extends Notifier<AIBookkeepingState> {
  final AIService _aiService = AIService();

  @override
  AIBookkeepingState build() => const AIBookkeepingState();

  /// 图片识别
  Future<AIRecognitionResult> recognizeImage(File imageFile) async {
    state = state.copyWith(
      status: AIRecognitionStatus.processing,
      errorMessage: null,
    );

    try {
      final result = await _aiService.recognizeImage(imageFile);

      if (result.success) {
        state = state.copyWith(
          status: AIRecognitionStatus.success,
          result: result,
        );
      } else {
        state = state.copyWith(
          status: AIRecognitionStatus.error,
          errorMessage: result.errorMessage ?? '识别失败',
        );
      }

      return result;
    } catch (e) {
      state = state.copyWith(
        status: AIRecognitionStatus.error,
        errorMessage: e.toString(),
      );
      return AIRecognitionResult.error(e.toString());
    }
  }

  /// 批量图片识别（长截图/账单列表）
  Future<MultiAIRecognitionResult> recognizeImageBatch(File imageFile) async {
    state = state.copyWith(
      status: AIRecognitionStatus.processing,
      errorMessage: null,
    );

    try {
      final result = await _aiService.recognizeImageBatch(imageFile);

      if (result.success) {
        state = state.copyWith(
          status: AIRecognitionStatus.success,
          multiResult: result,
          // 兼容单笔场景
          result: result.first,
        );
      } else {
        state = state.copyWith(
          status: AIRecognitionStatus.error,
          errorMessage: result.errorMessage ?? '识别失败',
        );
      }

      return result;
    } catch (e) {
      state = state.copyWith(
        status: AIRecognitionStatus.error,
        errorMessage: e.toString(),
      );
      return MultiAIRecognitionResult.error(e.toString());
    }
  }

  /// 智能图片识别（自动检测单笔/多笔）
  ///
  /// 优先尝试批量识别，如果只识别到一笔则回退到单笔模式
  Future<void> recognizeImageSmart(File imageFile) async {
    state = state.copyWith(
      status: AIRecognitionStatus.processing,
      errorMessage: null,
    );

    try {
      // 尝试批量识别
      final multiResult = await _aiService.recognizeImageBatch(imageFile);

      if (multiResult.success && multiResult.count > 0) {
        state = state.copyWith(
          status: AIRecognitionStatus.success,
          multiResult: multiResult,
          result: multiResult.first,
        );
      } else {
        // 批量识别失败，回退到单笔识别
        final singleResult = await _aiService.recognizeImage(imageFile);
        if (singleResult.success) {
          state = state.copyWith(
            status: AIRecognitionStatus.success,
            result: singleResult,
            multiResult: MultiAIRecognitionResult.single(singleResult),
          );
        } else {
          state = state.copyWith(
            status: AIRecognitionStatus.error,
            errorMessage: singleResult.errorMessage ?? '识别失败',
          );
        }
      }
    } catch (e) {
      state = state.copyWith(
        status: AIRecognitionStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// 语音识别
  Future<AIRecognitionResult> recognizeVoice(String transcribedText) async {
    state = state.copyWith(
      status: AIRecognitionStatus.processing,
      errorMessage: null,
    );

    try {
      final result = await _aiService.recognizeVoice(transcribedText);

      if (result.success) {
        state = state.copyWith(
          status: AIRecognitionStatus.success,
          result: result,
        );
      } else {
        state = state.copyWith(
          status: AIRecognitionStatus.error,
          errorMessage: result.errorMessage ?? '识别失败',
        );
      }

      return result;
    } catch (e) {
      state = state.copyWith(
        status: AIRecognitionStatus.error,
        errorMessage: e.toString(),
      );
      return AIRecognitionResult.error(e.toString());
    }
  }

  /// 文本解析
  Future<AIRecognitionResult> parseText(String text) async {
    state = state.copyWith(
      status: AIRecognitionStatus.processing,
      errorMessage: null,
    );

    try {
      final result = await _aiService.parseText(text);

      if (result.success) {
        state = state.copyWith(
          status: AIRecognitionStatus.success,
          result: result,
        );
      } else {
        state = state.copyWith(
          status: AIRecognitionStatus.error,
          errorMessage: result.errorMessage ?? '解析失败',
        );
      }

      return result;
    } catch (e) {
      state = state.copyWith(
        status: AIRecognitionStatus.error,
        errorMessage: e.toString(),
      );
      return AIRecognitionResult.error(e.toString());
    }
  }

  /// 本地智能分类（离线模式）
  String suggestCategoryLocal(String description) {
    return _aiService.localSuggestCategory(description);
  }

  /// 判断是否是收入
  bool isIncomeType(String description) {
    return _aiService.isIncomeType(description);
  }

  /// 设置录音状态
  void setRecording(bool isRecording) {
    state = state.copyWith(isRecording: isRecording);
  }

  /// 重置状态
  void reset() {
    state = const AIBookkeepingState();
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(
      status: AIRecognitionStatus.idle,
      errorMessage: null,
    );
  }
}

/// AI记账Provider
final aiBookkeepingProvider =
    NotifierProvider<AIBookkeepingNotifier, AIBookkeepingState>(
        AIBookkeepingNotifier.new);

/// 智能分类建议Provider
final categorySuggestionProvider = FutureProvider.family<String?, String>((ref, description) async {
  if (description.isEmpty) return null;

  final aiService = AIService();
  // 首先尝试本地分类
  return aiService.localSuggestCategory(description);
});
