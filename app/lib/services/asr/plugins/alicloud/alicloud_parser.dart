import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/asr_exception.dart';

/// 阿里云ASR WebSocket响应类型
enum AliCloudMessageType {
  transcriptionStarted,
  transcriptionResultChanged,
  sentenceBegin,
  sentenceEnd,
  transcriptionCompleted,
  taskFailed,
  unknown,
}

/// 阿里云ASR WebSocket响应
class AliCloudWSResponse {
  final AliCloudMessageType type;
  final Map<String, dynamic> header;
  final Map<String, dynamic>? payload;

  const AliCloudWSResponse({
    required this.type,
    required this.header,
    this.payload,
  });

  /// 获取消息名称
  String get name => header['name'] as String? ?? '';

  /// 获取状态码
  int? get statusCode => header['status'] as int?;

  /// 获取状态文本
  String? get statusText => header['status_text'] as String?;

  /// 获取任务ID
  String? get taskId => header['task_id'] as String?;

  factory AliCloudWSResponse.fromJson(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    final header = map['header'] as Map<String, dynamic>? ?? {};
    final payload = map['payload'] as Map<String, dynamic>?;
    final name = header['name'] as String? ?? '';

    final type = _parseMessageType(name);

    return AliCloudWSResponse(
      type: type,
      header: header,
      payload: payload,
    );
  }

  static AliCloudMessageType _parseMessageType(String name) {
    switch (name) {
      case 'TranscriptionStarted':
        return AliCloudMessageType.transcriptionStarted;
      case 'TranscriptionResultChanged':
        return AliCloudMessageType.transcriptionResultChanged;
      case 'SentenceBegin':
        return AliCloudMessageType.sentenceBegin;
      case 'SentenceEnd':
        return AliCloudMessageType.sentenceEnd;
      case 'TranscriptionCompleted':
        return AliCloudMessageType.transcriptionCompleted;
      case 'TaskFailed':
        return AliCloudMessageType.taskFailed;
      default:
        return AliCloudMessageType.unknown;
    }
  }
}

/// 阿里云ASR句子结果
class AliCloudSentenceResult {
  final String text;
  final double? confidence;
  final int? beginTime;
  final int? endTime;
  final int? index;

  const AliCloudSentenceResult({
    required this.text,
    this.confidence,
    this.beginTime,
    this.endTime,
    this.index,
  });

  factory AliCloudSentenceResult.fromPayload(Map<String, dynamic> payload) {
    return AliCloudSentenceResult(
      text: payload['result'] as String? ?? '',
      confidence: (payload['confidence'] as num?)?.toDouble(),
      beginTime: payload['begin_time'] as int?,
      endTime: payload['time'] as int?,
      index: payload['index'] as int?,
    );
  }
}

/// 解析结果类型
enum AliCloudParsedResultType {
  serverReady,
  partialResult,
  sentenceEnd,
  completed,
  error,
}

/// 解析结果
class AliCloudParsedResult {
  final AliCloudParsedResultType type;
  final String? text;
  final double? confidence;
  final ASRException? error;

  const AliCloudParsedResult._({
    required this.type,
    this.text,
    this.confidence,
    this.error,
  });

  factory AliCloudParsedResult.serverReady() {
    return const AliCloudParsedResult._(
      type: AliCloudParsedResultType.serverReady,
    );
  }

  factory AliCloudParsedResult.partialResult({
    required String text,
    double? confidence,
  }) {
    return AliCloudParsedResult._(
      type: AliCloudParsedResultType.partialResult,
      text: text,
      confidence: confidence,
    );
  }

  factory AliCloudParsedResult.sentenceEnd({
    required String text,
    double? confidence,
  }) {
    return AliCloudParsedResult._(
      type: AliCloudParsedResultType.sentenceEnd,
      text: text,
      confidence: confidence,
    );
  }

  factory AliCloudParsedResult.completed() {
    return const AliCloudParsedResult._(
      type: AliCloudParsedResultType.completed,
    );
  }

  factory AliCloudParsedResult.error(ASRException error) {
    return AliCloudParsedResult._(
      type: AliCloudParsedResultType.error,
      error: error,
    );
  }
}

/// 阿里云ASR结果解析器
class AliCloudParser {
  /// 解析WebSocket消息
  AliCloudParsedResult? parse(String message) {
    try {
      final response = AliCloudWSResponse.fromJson(message);
      debugPrint('[AliCloudParser] 收到响应: ${response.name}');

      switch (response.type) {
        case AliCloudMessageType.transcriptionStarted:
          debugPrint('[AliCloudParser] 识别已开始，服务器就绪');
          return AliCloudParsedResult.serverReady();

        case AliCloudMessageType.transcriptionResultChanged:
          final text = response.payload?['result'] as String? ?? '';
          final confidence =
              (response.payload?['confidence'] as num?)?.toDouble();
          debugPrint('[AliCloudParser] 中间结果: $text');
          return AliCloudParsedResult.partialResult(
            text: text,
            confidence: confidence,
          );

        case AliCloudMessageType.sentenceBegin:
          debugPrint(
              '[AliCloudParser] 句子开始: index=${response.payload?['index']}, time=${response.payload?['time']}');
          return null;

        case AliCloudMessageType.sentenceEnd:
          final result =
              AliCloudSentenceResult.fromPayload(response.payload ?? {});
          debugPrint(
              '[AliCloudParser] 句子结束: "${result.text}", 置信度=${result.confidence}');

          // 只有非空结果才返回
          if (result.text.trim().isNotEmpty) {
            return AliCloudParsedResult.sentenceEnd(
              text: result.text,
              confidence: result.confidence,
            );
          } else {
            debugPrint('[AliCloudParser] 跳过空的句子结束结果');
            return null;
          }

        case AliCloudMessageType.transcriptionCompleted:
          debugPrint('[AliCloudParser] 识别完成');
          return AliCloudParsedResult.completed();

        case AliCloudMessageType.taskFailed:
          debugPrint('[AliCloudParser] 任务失败: ${response.statusText}');
          return AliCloudParsedResult.error(
            ASRException(
              '识别失败: ${response.statusText}',
              errorCode: ASRErrorCode.serverError,
            ),
          );

        case AliCloudMessageType.unknown:
          debugPrint('[AliCloudParser] 未知消息类型: ${response.name}');
          return null;
      }
    } catch (e) {
      debugPrint('[AliCloudParser] 解析消息失败: $e');
      return AliCloudParsedResult.error(
        ASRException(
          '解析结果失败: $e',
          errorCode: ASRErrorCode.unknown,
        ),
      );
    }
  }

  /// 解析REST API响应
  AliCloudParsedResult? parseRestResponse(Map<String, dynamic> data) {
    try {
      final status = data['status'] as int?;

      if (status == 20000000) {
        final text = data['result'] as String? ?? '';
        debugPrint('[AliCloudParser] REST识别成功: $text');
        return AliCloudParsedResult.sentenceEnd(
          text: text,
          confidence: 0.9, // REST API不返回置信度
        );
      } else {
        debugPrint(
            '[AliCloudParser] REST识别失败: status=$status, message=${data['message']}');
        return AliCloudParsedResult.error(
          ASRException(
            'ASR失败: ${data['message']}',
            errorCode: ASRErrorCode.serverError,
          ),
        );
      }
    } catch (e) {
      debugPrint('[AliCloudParser] 解析REST响应失败: $e');
      return AliCloudParsedResult.error(
        ASRException(
          '解析结果失败: $e',
          errorCode: ASRErrorCode.unknown,
        ),
      );
    }
  }
}
