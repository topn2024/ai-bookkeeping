import 'dart:typed_data';
import 'dart:io';
import '../ai_service.dart';
import '../qwen_service.dart';

/// 文本解析服务
///
/// 负责处理所有文本和音频相关的 AI 解析功能：
/// - 自然语言文本解析
/// - 语音转文本后的解析
/// - 音频直接识别
/// - 邮件账单解析
///
/// 这是从 AIService 中提取的专注于文本/音频解析的服务
class TextParsingService {
  static final TextParsingService _instance = TextParsingService._internal();
  final QwenService _qwenService = QwenService();

  factory TextParsingService() => _instance;
  TextParsingService._internal();

  /// 解析自然语言文本
  ///
  /// 从自然语言描述中提取交易信息，使用千问模型
  ///
  /// [text] 用户输入的自然语言描述
  /// 返回识别结果 [AIRecognitionResult]
  Future<AIRecognitionResult> parseText(String text) async {
    try {
      final qwenResult = await _qwenService.parseBookkeepingText(text);
      return AIRecognitionResult.fromQwenResult(qwenResult);
    } catch (e) {
      return AIRecognitionResult.error('文本解析失败: $e');
    }
  }

  /// 解析语音转文本结果
  ///
  /// 处理语音识别后的文本，提取交易信息
  ///
  /// [transcribedText] 语音转文本的结果
  Future<AIRecognitionResult> parseVoiceText(String transcribedText) async {
    return parseText(transcribedText);
  }

  /// 从音频数据直接识别
  ///
  /// 直接从音频数据中识别记账信息，使用千问音频模型
  ///
  /// [audioData] 音频数据（字节数组）
  /// [format] 音频格式（默认 wav）
  Future<AIRecognitionResult> parseAudio(
    Uint8List audioData, {
    String format = 'wav',
  }) async {
    try {
      final qwenResult = await _qwenService.recognizeAudio(audioData, format: format);
      return AIRecognitionResult.fromQwenResult(qwenResult);
    } catch (e) {
      return AIRecognitionResult.error('音频识别失败: $e');
    }
  }

  /// 从音频文件识别
  ///
  /// [audioFile] 音频文件
  Future<AIRecognitionResult> parseAudioFile(File audioFile) async {
    try {
      final qwenResult = await _qwenService.recognizeAudioFile(audioFile);
      return AIRecognitionResult.fromQwenResult(qwenResult);
    } catch (e) {
      return AIRecognitionResult.error('音频文件识别失败: $e');
    }
  }

  /// 音频识别 - 支持多笔交易
  ///
  /// 一次语音输入可以识别多笔消费/收入
  ///
  /// [audioData] 音频数据
  /// [format] 音频格式
  Future<MultiAIRecognitionResult> parseAudioMulti(
    Uint8List audioData, {
    String format = 'wav',
  }) async {
    try {
      final qwenResult = await _qwenService.recognizeAudioMulti(audioData, format: format);
      return MultiAIRecognitionResult.fromQwenResult(qwenResult);
    } catch (e) {
      return MultiAIRecognitionResult.error('音频识别失败: $e');
    }
  }

  /// 解析邮件账单
  ///
  /// 从信用卡账单邮件中提取多条交易记录
  ///
  /// [emailContent] 邮件内容
  Future<List<AIRecognitionResult>> parseEmailBill(String emailContent) async {
    try {
      final qwenResults = await _qwenService.parseEmailBill(emailContent);
      return qwenResults.map((r) => AIRecognitionResult.fromQwenResult(r)).toList();
    } catch (e) {
      return [AIRecognitionResult.error('账单解析失败: $e')];
    }
  }

  /// 通用对话接口
  ///
  /// 用于需要 AI 辅助但不适合其他特定方法的场景
  ///
  /// [prompt] 对话提示语
  Future<String> chat(String prompt) async {
    try {
      final result = await _qwenService.chat(prompt);
      return result ?? '';
    } catch (e) {
      return '';
    }
  }
}
