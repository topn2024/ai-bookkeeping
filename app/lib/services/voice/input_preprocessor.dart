import 'package:flutter/foundation.dart';

import 'exception_handler.dart';

/// 预处理结果
class PreprocessResult {
  /// 是否有效
  final bool isValid;

  /// 处理后的文本
  final String? processedText;

  /// 异常（如果无效）
  final PreprocessException? exception;

  /// 检测到的特征
  final InputFeatures features;

  const PreprocessResult._({
    required this.isValid,
    this.processedText,
    this.exception,
    required this.features,
  });

  factory PreprocessResult.valid(String text, InputFeatures features) =>
      PreprocessResult._(
        isValid: true,
        processedText: text,
        features: features,
      );

  factory PreprocessResult.invalid(PreprocessException exception) =>
      PreprocessResult._(
        isValid: false,
        exception: exception,
        features: const InputFeatures(),
      );
}

/// 输入特征
class InputFeatures {
  /// 原始长度
  final int originalLength;

  /// 处理后长度
  final int processedLength;

  /// 是否包含数字
  final bool hasNumbers;

  /// 是否包含金额
  final bool hasAmount;

  /// 是否包含日期
  final bool hasDate;

  /// 是否为问句
  final bool isQuestion;

  /// 检测到的语言
  final DetectedLanguage language;

  const InputFeatures({
    this.originalLength = 0,
    this.processedLength = 0,
    this.hasNumbers = false,
    this.hasAmount = false,
    this.hasDate = false,
    this.isQuestion = false,
    this.language = DetectedLanguage.chinese,
  });
}

/// 检测到的语言
enum DetectedLanguage {
  chinese,
  english,
  mixed,
  unknown,
}

/// 输入预处理器
///
/// 职责：
/// - 噪声检测与过滤
/// - 输入长度限制
/// - 特殊字符过滤
/// - 基本特征提取
/// - 安全检查（注入攻击等）
class InputPreprocessor {
  /// 配置
  final PreprocessorConfig config;

  InputPreprocessor({PreprocessorConfig? config})
      : config = config ?? const PreprocessorConfig();

  // ==================== 公共API ====================

  /// 预处理输入
  PreprocessResult process(String input) {
    debugPrint('[InputPreprocessor] 处理输入: ${input.length}字');

    // 1. 基本清理
    var text = _basicClean(input);

    // 2. 长度检查
    if (text.length < config.minLength) {
      return PreprocessResult.invalid(PreprocessException.tooShort());
    }

    if (text.length > config.maxLength) {
      return PreprocessResult.invalid(PreprocessException.tooLong());
    }

    // 3. 安全检查
    if (_containsMaliciousPattern(text)) {
      return PreprocessResult.invalid(
        const PreprocessException(
          type: PreprocessExceptionType.malformedInput,
          message: '输入包含不安全内容',
        ),
      );
    }

    // 4. 噪声检测
    if (_isNoise(text)) {
      return PreprocessResult.invalid(
        const PreprocessException(
          type: PreprocessExceptionType.malformedInput,
          message: '无效输入',
        ),
      );
    }

    // 5. 规范化
    text = _normalize(text);

    // 6. 提取特征
    final features = _extractFeatures(input, text);

    debugPrint('[InputPreprocessor] 处理完成: ${text.length}字');
    return PreprocessResult.valid(text, features);
  }

  /// 快速检查是否为有效输入
  bool isValidInput(String input) {
    final cleaned = _basicClean(input);
    return cleaned.length >= config.minLength &&
        cleaned.length <= config.maxLength &&
        !_isNoise(cleaned);
  }

  // ==================== 内部方法 ====================

  /// 基本清理
  String _basicClean(String input) {
    var text = input.trim();

    // 移除零宽字符
    text = text.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');

    // 移除控制字符
    text = text.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');

    // 规范化空白
    text = text.replaceAll(RegExp(r'\s+'), ' ');

    return text.trim();
  }

  /// 规范化
  String _normalize(String input) {
    var text = input;

    // 全角转半角数字
    text = _fullWidthToHalfWidth(text);

    // 规范化标点
    text = _normalizePunctuation(text);

    // 规范化数字表达
    text = _normalizeNumbers(text);

    return text;
  }

  /// 全角转半角
  String _fullWidthToHalfWidth(String input) {
    final buffer = StringBuffer();
    for (final char in input.runes) {
      if (char >= 0xFF10 && char <= 0xFF19) {
        // 全角数字
        buffer.writeCharCode(char - 0xFF10 + 0x30);
      } else if (char >= 0xFF21 && char <= 0xFF3A) {
        // 全角大写字母
        buffer.writeCharCode(char - 0xFF21 + 0x41);
      } else if (char >= 0xFF41 && char <= 0xFF5A) {
        // 全角小写字母
        buffer.writeCharCode(char - 0xFF41 + 0x61);
      } else {
        buffer.writeCharCode(char);
      }
    }
    return buffer.toString();
  }

  /// 规范化标点
  String _normalizePunctuation(String input) {
    return input
        .replaceAll('。', '.')
        .replaceAll('，', ',')
        .replaceAll('！', '!')
        .replaceAll('？', '?')
        .replaceAll('：', ':')
        .replaceAll('；', ';');
  }

  /// 规范化数字表达
  String _normalizeNumbers(String input) {
    // 中文数字映射
    const chineseNumbers = {
      '零': '0', '一': '1', '二': '2', '三': '3', '四': '4',
      '五': '5', '六': '6', '七': '7', '八': '8', '九': '9',
      '两': '2', '〇': '0',
    };

    var text = input;
    chineseNumbers.forEach((chinese, arabic) {
      text = text.replaceAll(chinese, arabic);
    });

    // 处理"十"的特殊情况
    text = text.replaceAllMapped(RegExp(r'(\d?)十(\d?)'), (match) {
      final before = match.group(1) ?? '';
      final after = match.group(2) ?? '';
      if (before.isEmpty && after.isEmpty) {
        return '10';
      } else if (before.isEmpty) {
        return '1$after';
      } else if (after.isEmpty) {
        return '${before}0';
      } else {
        return '$before$after';
      }
    });

    // 处理"百"
    text = text.replaceAllMapped(RegExp(r'(\d)百(\d{0,2})'), (match) {
      final hundreds = match.group(1) ?? '1';
      final rest = match.group(2) ?? '';
      final paddedRest = rest.padRight(2, '0');
      return '$hundreds$paddedRest';
    });

    return text;
  }

  /// 检测是否为噪声
  bool _isNoise(String input) {
    // 纯标点
    if (RegExp(r'^[^\w\u4e00-\u9fa5]+$').hasMatch(input)) {
      return true;
    }

    // 重复字符
    if (RegExp(r'^(.)\1{3,}$').hasMatch(input)) {
      return true;
    }

    // 纯数字且长度小于2
    if (RegExp(r'^\d{1}$').hasMatch(input)) {
      return true;
    }

    return false;
  }

  /// 检测恶意模式
  bool _containsMaliciousPattern(String input) {
    final maliciousPatterns = [
      // SQL注入
      RegExp(r"('\s*(or|and)\s*'|--\s*$|;\s*drop|;\s*delete)", caseSensitive: false),
      // XSS
      RegExp(r'<script|javascript:|on\w+\s*=', caseSensitive: false),
      // 命令注入
      RegExp(r'[;&|`$]|\.\./|/etc/passwd', caseSensitive: false),
    ];

    for (final pattern in maliciousPatterns) {
      if (pattern.hasMatch(input)) {
        debugPrint('[InputPreprocessor] 检测到恶意模式');
        return true;
      }
    }

    return false;
  }

  /// 提取特征
  InputFeatures _extractFeatures(String original, String processed) {
    // 检测数字
    final hasNumbers = RegExp(r'\d').hasMatch(processed);

    // 检测金额
    final hasAmount = RegExp(r'\d+(\.\d+)?\s*(元|块|￥|\$)').hasMatch(processed) ||
        RegExp(r'(元|块|￥|\$)\s*\d+').hasMatch(processed);

    // 检测日期
    final hasDate = RegExp(r'(今天|昨天|前天|明天|上周|本周|这周|上个月|本月)').hasMatch(processed) ||
        RegExp(r'\d{1,2}[月/.-]\d{1,2}').hasMatch(processed);

    // 检测问句
    final isQuestion = processed.endsWith('?') ||
        processed.endsWith('吗') ||
        processed.endsWith('呢') ||
        RegExp(r'(什么|哪|几|多少|怎么|为什么|是不是)').hasMatch(processed);

    // 检测语言
    final language = _detectLanguage(processed);

    return InputFeatures(
      originalLength: original.length,
      processedLength: processed.length,
      hasNumbers: hasNumbers,
      hasAmount: hasAmount,
      hasDate: hasDate,
      isQuestion: isQuestion,
      language: language,
    );
  }

  /// 检测语言
  DetectedLanguage _detectLanguage(String input) {
    final chineseCount = RegExp(r'[\u4e00-\u9fa5]').allMatches(input).length;
    final englishCount = RegExp(r'[a-zA-Z]').allMatches(input).length;

    if (chineseCount > 0 && englishCount > 0) {
      return DetectedLanguage.mixed;
    } else if (chineseCount > 0) {
      return DetectedLanguage.chinese;
    } else if (englishCount > 0) {
      return DetectedLanguage.english;
    }
    return DetectedLanguage.unknown;
  }
}

/// 预处理器配置
class PreprocessorConfig {
  /// 最小输入长度
  final int minLength;

  /// 最大输入长度
  final int maxLength;

  /// 是否启用安全检查
  final bool enableSecurityCheck;

  const PreprocessorConfig({
    this.minLength = 1,
    this.maxLength = 500,
    this.enableSecurityCheck = true,
  });
}
