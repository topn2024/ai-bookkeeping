import 'package:flutter/foundation.dart';

/// ASR异常类型
enum ASRExceptionType {
  /// 静音/纯噪音
  silence,

  /// 发音不清
  unclearPronunciation,

  /// 语速过快
  tooFast,

  /// 语速过慢
  tooSlow,

  /// 方言口音
  dialect,

  /// 背景干扰
  backgroundNoise,

  /// 中英混杂
  mixedLanguage,

  /// 数字歧义
  numberAmbiguity,

  /// 低置信度
  lowConfidence,
}

/// NLU异常类型
enum NLUExceptionType {
  /// 无关话题
  offTopic,

  /// 闲聊寒暄
  casualChat,

  /// 情绪宣泄
  emotionalVenting,

  /// 测试调戏
  testing,

  /// 脏话攻击
  offensive,

  /// 敏感话题
  sensitive,

  /// 模糊意图
  vagueIntent,

  /// 矛盾指令
  contradictory,

  /// 复合歧义
  compoundAmbiguity,
}

/// 操作层异常类型
enum OperationExceptionType {
  /// 越权操作
  unauthorized,

  /// 无效目标
  invalidTarget,

  /// 数据溢出
  dataOverflow,

  /// 频率异常
  frequencyAbuse,

  /// 时序冲突
  sequenceConflict,

  /// 权限不足
  insufficientPermission,

  /// 状态冲突
  stateConflict,
}

/// 异常处理动作
enum ExceptionAction {
  /// 重试
  retry,

  /// 确认
  confirm,

  /// 澄清
  clarify,

  /// 边界重定向
  boundaryRedirect,

  /// 问候并引导
  greetAndGuide,

  /// 共情并引导
  empathizeAndGuide,

  /// 阻止
  block,

  /// 确认合理性
  confirmReasonability,

  /// 节流
  throttle,

  /// 静默过滤
  silentFilter,

  /// 忽略
  ignore,
}

/// 异常响应
class ExceptionResponse {
  /// 响应文本
  final String text;

  /// 处理动作
  final ExceptionAction action;

  /// 是否应该语音输出
  final bool shouldSpeak;

  /// 建议的后续操作
  final String? suggestion;

  const ExceptionResponse({
    required this.text,
    required this.action,
    this.shouldSpeak = true,
    this.suggestion,
  });
}

/// ASR异常
class ASRException implements Exception {
  final ASRExceptionType type;
  final String? bestGuess;
  final double? confidence;
  final String message;

  const ASRException({
    required this.type,
    this.bestGuess,
    this.confidence,
    required this.message,
  });

  factory ASRException.silence() => const ASRException(
        type: ASRExceptionType.silence,
        message: '未检测到有效语音',
      );

  factory ASRException.lowConfidence(String? guess, double confidence) =>
      ASRException(
        type: ASRExceptionType.lowConfidence,
        bestGuess: guess,
        confidence: confidence,
        message: '识别置信度过低',
      );

  factory ASRException.numberAmbiguity(String input) => ASRException(
        type: ASRExceptionType.numberAmbiguity,
        bestGuess: input,
        message: '数字表达存在歧义',
      );

  @override
  String toString() => 'ASRException: $type - $message';
}

/// NLU异常
class NLUException implements Exception {
  final NLUExceptionType type;
  final String input;
  final String message;

  const NLUException({
    required this.type,
    required this.input,
    required this.message,
  });

  factory NLUException.offTopic(String input) => NLUException(
        type: NLUExceptionType.offTopic,
        input: input,
        message: '话题超出范围',
      );

  factory NLUException.vagueIntent(String input) => NLUException(
        type: NLUExceptionType.vagueIntent,
        input: input,
        message: '意图不明确',
      );

  factory NLUException.contradictory(String input) => NLUException(
        type: NLUExceptionType.contradictory,
        input: input,
        message: '指令存在矛盾',
      );

  @override
  String toString() => 'NLUException: $type - $message';
}

/// 操作层异常
class OperationException implements Exception {
  final OperationExceptionType type;
  final String? targetId;
  final dynamic value;
  final String message;

  const OperationException({
    required this.type,
    this.targetId,
    this.value,
    required this.message,
  });

  factory OperationException.unauthorized(String operation) => OperationException(
        type: OperationExceptionType.unauthorized,
        message: '操作未授权: $operation',
      );

  factory OperationException.dataOverflow(dynamic value) => OperationException(
        type: OperationExceptionType.dataOverflow,
        value: value,
        message: '数据超出合理范围',
      );

  factory OperationException.frequencyAbuse() => const OperationException(
        type: OperationExceptionType.frequencyAbuse,
        message: '请求过于频繁',
      );

  @override
  String toString() => 'OperationException: $type - $message';
}

/// 语音异常处理器
///
/// 基于设计文档18.12实现四层异常处理
class VoiceExceptionHandler {
  /// 处理语音识别层异常
  ExceptionResponse handleASRException(ASRException e) {
    debugPrint('[ExceptionHandler] ASR异常: ${e.type}');

    switch (e.type) {
      case ASRExceptionType.silence:
        return const ExceptionResponse(
          text: '没听清，再说一次？',
          action: ExceptionAction.retry,
        );

      case ASRExceptionType.unclearPronunciation:
        if (e.bestGuess != null) {
          return ExceptionResponse(
            text: "你是说'${e.bestGuess}'吗？",
            action: ExceptionAction.confirm,
          );
        }
        return const ExceptionResponse(
          text: '没听清楚，能再说一遍吗？',
          action: ExceptionAction.retry,
        );

      case ASRExceptionType.tooFast:
        return const ExceptionResponse(
          text: '说得有点快，能慢点再说一遍吗？',
          action: ExceptionAction.retry,
        );

      case ASRExceptionType.tooSlow:
        return const ExceptionResponse(
          text: '好的，我在听',
          action: ExceptionAction.ignore,
          shouldSpeak: false,
        );

      case ASRExceptionType.dialect:
        if (e.bestGuess != null) {
          return ExceptionResponse(
            text: "你是说'${e.bestGuess}'吗？",
            action: ExceptionAction.confirm,
          );
        }
        return const ExceptionResponse(
          text: '有点没听懂，能再说一遍吗？',
          action: ExceptionAction.retry,
        );

      case ASRExceptionType.backgroundNoise:
        return const ExceptionResponse(
          text: '环境有点吵，能再说一遍吗？',
          action: ExceptionAction.retry,
        );

      case ASRExceptionType.mixedLanguage:
        return const ExceptionResponse(
          text: '好的，我听到了',
          action: ExceptionAction.ignore,
          shouldSpeak: false,
        );

      case ASRExceptionType.numberAmbiguity:
        return ExceptionResponse(
          text: '${e.bestGuess}，是多少来着？',
          action: ExceptionAction.clarify,
        );

      case ASRExceptionType.lowConfidence:
        if (e.bestGuess != null) {
          return ExceptionResponse(
            text: "你是说'${e.bestGuess}'吗？",
            action: ExceptionAction.confirm,
          );
        }
        return const ExceptionResponse(
          text: '没太听清，再说一遍？',
          action: ExceptionAction.retry,
        );
    }
  }

  /// 处理语义理解层异常
  ExceptionResponse handleNLUException(NLUException e) {
    debugPrint('[ExceptionHandler] NLU异常: ${e.type}');

    switch (e.type) {
      case NLUExceptionType.offTopic:
        return const ExceptionResponse(
          text: '这个我不太懂，记账的事我在行～',
          action: ExceptionAction.boundaryRedirect,
        );

      case NLUExceptionType.casualChat:
        return const ExceptionResponse(
          text: '你好呀～要记账吗？',
          action: ExceptionAction.greetAndGuide,
        );

      case NLUExceptionType.emotionalVenting:
        return const ExceptionResponse(
          text: '理解你的心情～要看看花了多少吗？',
          action: ExceptionAction.empathizeAndGuide,
        );

      case NLUExceptionType.testing:
        return const ExceptionResponse(
          text: '我是你的记账小助手，专业的～',
          action: ExceptionAction.boundaryRedirect,
        );

      case NLUExceptionType.offensive:
        return const ExceptionResponse(
          text: '看起来你心情不太好，需要帮忙记账吗？',
          action: ExceptionAction.empathizeAndGuide,
        );

      case NLUExceptionType.sensitive:
        return const ExceptionResponse(
          text: '这个话题我不方便聊，记账找我～',
          action: ExceptionAction.boundaryRedirect,
        );

      case NLUExceptionType.vagueIntent:
        return const ExceptionResponse(
          text: "你说的'那个'是指哪一笔？",
          action: ExceptionAction.clarify,
        );

      case NLUExceptionType.contradictory:
        return const ExceptionResponse(
          text: '支出还是收入？',
          action: ExceptionAction.clarify,
        );

      case NLUExceptionType.compoundAmbiguity:
        return const ExceptionResponse(
          text: '一步一步来，先说第一件事？',
          action: ExceptionAction.clarify,
        );
    }
  }

  /// 处理操作层异常
  ExceptionResponse handleOperationException(OperationException e) {
    debugPrint('[ExceptionHandler] 操作异常: ${e.type}');

    switch (e.type) {
      case OperationExceptionType.unauthorized:
        return const ExceptionResponse(
          text: '这个操作风险较高，需要在设置里手动操作',
          action: ExceptionAction.block,
        );

      case OperationExceptionType.invalidTarget:
        return const ExceptionResponse(
          text: '没找到这笔记录，是哪天的？',
          action: ExceptionAction.clarify,
        );

      case OperationExceptionType.dataOverflow:
        return ExceptionResponse(
          text: '${e.value}？这是真的吗？',
          action: ExceptionAction.confirmReasonability,
        );

      case OperationExceptionType.frequencyAbuse:
        return const ExceptionResponse(
          text: '慢点慢点，我在处理上一条',
          action: ExceptionAction.throttle,
        );

      case OperationExceptionType.sequenceConflict:
        return const ExceptionResponse(
          text: '你还没记账呢，要先记一笔吗？',
          action: ExceptionAction.clarify,
        );

      case OperationExceptionType.insufficientPermission:
        return const ExceptionResponse(
          text: '这个需要管理员权限，要申请吗？',
          action: ExceptionAction.clarify,
        );

      case OperationExceptionType.stateConflict:
        return const ExceptionResponse(
          text: '现在是离线状态，先记本地？',
          action: ExceptionAction.clarify,
        );
    }
  }

  /// 处理预处理异常
  ExceptionResponse handlePreprocessException(PreprocessException e) {
    debugPrint('[ExceptionHandler] 预处理异常: ${e.type}');

    switch (e.type) {
      case PreprocessExceptionType.tooLong:
        return const ExceptionResponse(
          text: '说太多了，分几次说？',
          action: ExceptionAction.retry,
        );

      case PreprocessExceptionType.tooShort:
        return const ExceptionResponse(
          text: '没听清，再说一次？',
          action: ExceptionAction.retry,
        );

      case PreprocessExceptionType.malformedInput:
        return const ExceptionResponse(
          text: '好的，记账找我～',
          action: ExceptionAction.silentFilter,
          shouldSpeak: false,
        );
    }
  }

  /// 检查金额是否合理
  bool isReasonableAmount(double amount) {
    // 金额应该在合理范围内
    return amount > 0 && amount < 10000000; // 1000万以内
  }

  /// 检查是否是危险操作
  bool isDangerousOperation(String operation) {
    const dangerousOps = [
      '删除所有',
      '清空',
      '注销账号',
      '重置',
    ];
    return dangerousOps.any((op) => operation.contains(op));
  }
}

/// 预处理异常类型
enum PreprocessExceptionType {
  /// 输入过长
  tooLong,

  /// 输入过短
  tooShort,

  /// 格式异常
  malformedInput,
}

/// 预处理异常
class PreprocessException implements Exception {
  final PreprocessExceptionType type;
  final String message;

  const PreprocessException({
    required this.type,
    required this.message,
  });

  factory PreprocessException.tooLong() => const PreprocessException(
        type: PreprocessExceptionType.tooLong,
        message: '输入过长',
      );

  factory PreprocessException.tooShort() => const PreprocessException(
        type: PreprocessExceptionType.tooShort,
        message: '输入过短',
      );

  @override
  String toString() => 'PreprocessException: $type - $message';
}
