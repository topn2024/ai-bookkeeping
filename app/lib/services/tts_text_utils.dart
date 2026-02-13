import 'package:flutter/foundation.dart';

/// TTS文本预处理工具
///
/// 将文本中的金额、特殊符号等转换为适合语音播报的格式
class TTSTextUtils {
  /// 预处理TTS文本，格式化金额等，使其更适合语音播报
  static String preprocessTextForTTS(String text) {
    // 移除波浪号（会被TTS读成"波浪号"或奇怪的音）
    // 移除其他装饰性符号
    String processed = text
        .replaceAll('~', '')
        .replaceAll('～', '') // 全角波浪号
        .replaceAll('♪', '')
        .replaceAll('♫', '')
        .replaceAll('★', '')
        .replaceAll('☆', '')
        .replaceAll('♥', '')
        .replaceAll('♡', '')
        .replaceAll('→', '')
        .replaceAll('←', '')
        .replaceAll('↑', '')
        .replaceAll('↓', '');

    // 移除 ¥ 符号（TTS会读成"人民币符号"）
    processed = processed.replaceAll('¥', '');

    // 格式化金额为口语化表达
    // 匹配 数字.00元 / 数字.X0元 / 数字.XY元 等模式
    processed = processed.replaceAllMapped(
      RegExp(r'(\d+)\.(\d{1,2})(元|块)'),
      (match) {
        final yuan = match.group(1)!;
        final decimal = match.group(2)!;
        final unit = match.group(3)!;
        final padded = decimal.padRight(2, '0');
        final jiao = padded[0];
        final fen = padded[1];

        if (jiao == '0' && fen == '0') {
          return '$yuan$unit';
        } else if (fen == '0') {
          return '$yuan$unit$jiao角';
        } else if (jiao == '0') {
          return '$yuan${unit}零$fen分';
        } else {
          return '$yuan$unit$jiao角$fen分';
        }
      },
    );

    // 处理没有"元/块"后缀的金额（如 ¥36.00 → 36）
    // 去掉纯数字后面多余的 .00
    processed = processed.replaceAllMapped(
      RegExp(r'(\d+)\.00(?!\d)'),
      (match) => match.group(1)!,
    );

    // 处理 .X0 结尾的（如 36.50 → 36.5）
    processed = processed.replaceAllMapped(
      RegExp(r'(\d+\.\d)0(?!\d)'),
      (match) => match.group(1)!,
    );

    // 清理多余空格
    processed = processed.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (text != processed) {
      debugPrint('TTS: 文本预处理: "$text" -> "$processed"');
    }

    return processed;
  }
}
