import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/asr_exception.dart';

/// 讯飞语音听写响应解析
class IFlytekIATResponse {
  /// 错误码
  final int code;

  /// 错误消息
  final String? message;

  /// session ID
  final String? sid;

  /// 数据
  final IFlytekIATData? data;

  const IFlytekIATResponse({
    required this.code,
    this.message,
    this.sid,
    this.data,
  });

  /// 是否成功
  bool get isSuccess => code == 0;

  /// 是否有结果
  bool get hasResult => data?.result != null;

  /// 是否为最终结果
  bool get isLast => data?.status == 2;

  factory IFlytekIATResponse.fromJson(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;

    return IFlytekIATResponse(
      code: map['code'] as int? ?? -1,
      message: map['message'] as String?,
      sid: map['sid'] as String?,
      data: map['data'] != null
          ? IFlytekIATData.fromJson(map['data'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// 讯飞语音听写数据
class IFlytekIATData {
  /// 状态（0: 开始, 1: 中间, 2: 结束）
  final int status;

  /// 结果
  final IFlytekIATResult? result;

  const IFlytekIATData({
    required this.status,
    this.result,
  });

  factory IFlytekIATData.fromJson(Map<String, dynamic> map) {
    return IFlytekIATData(
      status: map['status'] as int? ?? 0,
      result: map['result'] != null
          ? IFlytekIATResult.fromJson(map['result'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// 讯飞语音听写结果
class IFlytekIATResult {
  /// 句子序号
  final int sn;

  /// 是否为最后一段
  final bool ls;

  /// 动态修正标志（apd: 追加, rpl: 替换）
  final String? pgs;

  /// 替换范围 [start, end]
  final List<int>? rg;

  /// 结果状态（pgs: 处理中, rlt: 最终结果）
  final String? rst;

  /// 词列表
  final List<IFlytekIATWord> ws;

  const IFlytekIATResult({
    required this.sn,
    required this.ls,
    this.pgs,
    this.rg,
    this.rst,
    required this.ws,
  });

  /// 获取识别文本
  String get text {
    return ws.map((w) => w.text).join('');
  }

  /// 是否为句子结束
  bool get isSentenceEnd => rst == 'rlt';

  /// 是否为替换模式
  bool get isReplace => pgs == 'rpl';

  factory IFlytekIATResult.fromJson(Map<String, dynamic> map) {
    final wsList = (map['ws'] as List?) ?? [];
    final rgList = (map['rg'] as List?)?.cast<int>();

    return IFlytekIATResult(
      sn: map['sn'] as int? ?? 0,
      ls: map['ls'] as bool? ?? false,
      pgs: map['pgs'] as String?,
      rg: rgList,
      rst: map['rst'] as String?,
      ws: wsList
          .map((w) => IFlytekIATWord.fromJson(w as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 讯飞语音听写词
class IFlytekIATWord {
  /// 词开始时间（帧数）
  final int? bg;

  /// 词结束时间（帧数）
  final int? ed;

  /// 候选词列表
  final List<IFlytekIATCandidate> cw;

  const IFlytekIATWord({
    this.bg,
    this.ed,
    required this.cw,
  });

  /// 获取最佳候选词文本
  String get text {
    if (cw.isEmpty) return '';
    return cw.first.w;
  }

  factory IFlytekIATWord.fromJson(Map<String, dynamic> map) {
    final cwList = (map['cw'] as List?) ?? [];

    return IFlytekIATWord(
      bg: map['bg'] as int?,
      ed: map['ed'] as int?,
      cw: cwList
          .map((c) => IFlytekIATCandidate.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 讯飞语音听写候选词
class IFlytekIATCandidate {
  /// 词内容
  final String w;

  /// 置信度（仅开启nlp时有效）
  final double? sc;

  const IFlytekIATCandidate({
    required this.w,
    this.sc,
  });

  factory IFlytekIATCandidate.fromJson(Map<String, dynamic> map) {
    return IFlytekIATCandidate(
      w: map['w'] as String? ?? '',
      sc: (map['sc'] as num?)?.toDouble(),
    );
  }
}

/// 讯飞语音听写结果解析器
class IFlytekIATParser {
  /// 存储识别结果的段落（按sn索引）
  final List<String> _resultSegments = [];

  /// 记录上次输出的最后一个sn
  int _lastFinalSn = 0;

  /// 解析响应
  IFlytekIATParsedResult? parse(String message) {
    try {
      final response = IFlytekIATResponse.fromJson(message);
      debugPrint('[IFlytekIATParser] 收到消息: code=${response.code}');

      if (!response.isSuccess) {
        debugPrint(
            '[IFlytekIATParser] 错误: code=${response.code}, message=${response.message}');
        return IFlytekIATParsedResult.error(
          ASRException(
            '识别失败: ${response.message}',
            errorCode: ASRErrorCode.serverError,
          ),
        );
      }

      if (!response.hasResult) {
        return null;
      }

      final result = response.data!.result!;
      final segmentText = result.text;
      final sn = result.sn;
      final pgs = result.pgs;
      final rg = result.rg;
      final rst = result.rst;
      final isLast = response.isLast;

      debugPrint(
          '[IFlytekIATParser] 原始结果: sn=$sn, text="$segmentText", pgs=$pgs, rg=$rg, rst=$rst, isLast=$isLast');

      if (segmentText.isEmpty) {
        return isLast
            ? IFlytekIATParsedResult.completed()
            : null;
      }

      // 组装识别结果（根据sn和pgs规则）
      // 确保列表足够大
      while (_resultSegments.length < sn) {
        _resultSegments.add('');
      }

      if (result.isReplace && rg != null && rg.length == 2) {
        // 替换模式：清空rg指定范围，然后设置当前段落
        final startIdx = rg[0]; // 从1开始
        final endIdx = rg[1]; // 从1开始

        // 确保列表足够大
        while (_resultSegments.length <= endIdx) {
          _resultSegments.add('');
        }

        // 清空替换范围（包含startIdx和endIdx）
        // 注意：rg是从1开始，数组索引是从0开始
        for (int i = startIdx - 1; i <= endIdx - 1; i++) {
          _resultSegments[i] = '';
        }

        // 设置当前段落
        _resultSegments[sn - 1] = segmentText;
      } else {
        // 追加模式（apd或默认）：直接设置当前段落
        _resultSegments[sn - 1] = segmentText;
      }

      // 检测句子边界（rst=rlt表示句子结束）
      if (result.isSentenceEnd) {
        // 句子结束，提取从上次输出位置到当前sn的文本
        final sentenceSegments = <String>[];
        for (int i = _lastFinalSn; i < sn && i < _resultSegments.length; i++) {
          final seg = _resultSegments[i];
          // 过滤单独的标点符号
          if (seg.isNotEmpty &&
              seg.trim() != '？' &&
              seg.trim() != '.' &&
              seg.trim() != ',' &&
              seg.trim() != '。') {
            sentenceSegments.add(seg);
          }
        }

        final sentenceText = sentenceSegments.join('');
        debugPrint(
            '[IFlytekIATParser] 句子结束: sn=$sn, text="$sentenceText" (范围${_lastFinalSn + 1}-$sn)');

        // 更新已输出的位置
        _lastFinalSn = sn;

        if (sentenceText.isNotEmpty) {
          return IFlytekIATParsedResult.sentence(
            text: sentenceText,
            isFinal: true,
            isLast: isLast,
          );
        }
      } else {
        // 【关键修复】句子进行中时也要返回中间结果（isFinal=false）
        // 这样 InputPipeline 会调用 onPartialResult 回调
        // 然后 VoicePipelineController 会调用 _proactiveManager.stopMonitoring()
        // 防止用户说话时被主动对话打断
        final currentText = _resultSegments.join('');
        debugPrint('[IFlytekIATParser] 句子进行中: sn=$sn, rst=$rst, 当前文本="$currentText"');

        if (currentText.isNotEmpty) {
          return IFlytekIATParsedResult.sentence(
            text: currentText,
            isFinal: false,  // 中间结果
            isLast: false,
          );
        }
      }

      // 当isLast=true时，即使rst不是rlt，也应该输出累积的文本
      if (isLast) {
        // 提取所有未输出的文本
        final remainingSegments = <String>[];
        for (int i = _lastFinalSn; i < _resultSegments.length; i++) {
          final seg = _resultSegments[i];
          if (seg.isNotEmpty &&
              seg.trim() != '？' &&
              seg.trim() != '.' &&
              seg.trim() != ',' &&
              seg.trim() != '。') {
            remainingSegments.add(seg);
          }
        }

        final remainingText = remainingSegments.join('');
        if (remainingText.isNotEmpty) {
          debugPrint('[IFlytekIATParser] isLast=true，输出剩余文本: "$remainingText"');
          return IFlytekIATParsedResult.sentence(
            text: remainingText,
            isFinal: true,
            isLast: true,
          );
        }

        return IFlytekIATParsedResult.completed();
      }

      return null;
    } catch (e) {
      debugPrint('[IFlytekIATParser] 解析消息失败: $e');
      return IFlytekIATParsedResult.error(
        ASRException(
          '解析结果失败: $e',
          errorCode: ASRErrorCode.unknown,
        ),
      );
    }
  }

  /// 重置解析器状态
  void reset() {
    _resultSegments.clear();
    _lastFinalSn = 0;
  }
}

/// 解析结果类型
enum IFlytekIATParsedResultType {
  sentence,
  completed,
  error,
}

/// 解析结果
class IFlytekIATParsedResult {
  final IFlytekIATParsedResultType type;
  final String? text;
  final bool? isFinal;
  final bool? isLast;
  final ASRException? error;

  const IFlytekIATParsedResult._({
    required this.type,
    this.text,
    this.isFinal,
    this.isLast,
    this.error,
  });

  factory IFlytekIATParsedResult.sentence({
    required String text,
    required bool isFinal,
    required bool isLast,
  }) {
    return IFlytekIATParsedResult._(
      type: IFlytekIATParsedResultType.sentence,
      text: text,
      isFinal: isFinal,
      isLast: isLast,
    );
  }

  factory IFlytekIATParsedResult.completed() {
    return const IFlytekIATParsedResult._(
      type: IFlytekIATParsedResultType.completed,
    );
  }

  factory IFlytekIATParsedResult.error(ASRException error) {
    return IFlytekIATParsedResult._(
      type: IFlytekIATParsedResultType.error,
      error: error,
    );
  }
}
