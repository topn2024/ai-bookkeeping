import '../core/asr_models.dart';

/// ASR后处理接口
///
/// 对ASR结果进行后处理
abstract class ASRPostprocessor {
  /// 处理完整结果
  ASRResult process(ASRResult result);

  /// 处理部分结果
  ASRPartialResult processPartial(ASRPartialResult result);

  /// 处理文本
  String processText(String text);
}

/// 组合后处理器
///
/// 按顺序执行多个后处理器
class CompositePostprocessor implements ASRPostprocessor {
  final List<ASRPostprocessor> processors;

  CompositePostprocessor(this.processors);

  @override
  ASRResult process(ASRResult result) {
    var current = result;
    for (final processor in processors) {
      current = processor.process(current);
    }
    return current;
  }

  @override
  ASRPartialResult processPartial(ASRPartialResult result) {
    var current = result;
    for (final processor in processors) {
      current = processor.processPartial(current);
    }
    return current;
  }

  @override
  String processText(String text) {
    var current = text;
    for (final processor in processors) {
      current = processor.processText(current);
    }
    return current;
  }
}

/// 记账领域ASR优化器
///
/// 针对记账场景的ASR结果优化
class BookkeepingASROptimizer implements ASRPostprocessor {
  /// 记账专用热词表
  static const List<HotWord> bookkeepingHotWords = [
    // 金额表达
    HotWord('块钱', weight: 2.0),
    HotWord('元', weight: 2.0),
    HotWord('毛', weight: 1.5),
    HotWord('分', weight: 1.5),

    // 常见分类
    HotWord('早餐', weight: 1.8),
    HotWord('午餐', weight: 1.8),
    HotWord('晚餐', weight: 1.8),
    HotWord('外卖', weight: 1.8),
    HotWord('打车', weight: 1.8),
    HotWord('地铁', weight: 1.8),
    HotWord('公交', weight: 1.8),
    HotWord('房租', weight: 1.8),
    HotWord('水电费', weight: 1.8),

    // 时间表达
    HotWord('今天', weight: 1.5),
    HotWord('昨天', weight: 1.5),
    HotWord('前天', weight: 1.5),
    HotWord('上周', weight: 1.5),
    HotWord('上个月', weight: 1.5),

    // 动作词
    HotWord('花了', weight: 1.8),
    HotWord('买了', weight: 1.8),
    HotWord('充值', weight: 1.8),
    HotWord('转账', weight: 1.8),
    HotWord('收入', weight: 1.8),
    HotWord('工资', weight: 1.8),

    // 打断相关（高优先级）
    HotWord('停', weight: 2.5),
    HotWord('等等', weight: 2.5),
    HotWord('等一下', weight: 2.5),
    HotWord('算了', weight: 2.5),
    HotWord('不对', weight: 2.5),
    HotWord('不是', weight: 2.5),
    HotWord('停止', weight: 2.5),
    HotWord('打住', weight: 2.5),
    HotWord('继续', weight: 2.0),

    // 确认相关
    HotWord('好的', weight: 1.8),
    HotWord('确认', weight: 1.8),
    HotWord('对', weight: 1.8),
    HotWord('是的', weight: 1.8),
    HotWord('取消', weight: 2.0),
    HotWord('不要', weight: 2.0),

    // 自动化相关
    HotWord('支付宝', weight: 2.0),
    HotWord('微信', weight: 2.0),
    HotWord('同步', weight: 1.8),
    HotWord('导入', weight: 1.8),
    HotWord('账单', weight: 1.8),
  ];

  @override
  ASRResult process(ASRResult result) {
    var text = result.text;
    text = postProcessNumbers(text);
    text = normalizeAmountUnit(text);

    return result.copyWith(text: text);
  }

  @override
  ASRPartialResult processPartial(ASRPartialResult result) {
    var text = result.text;
    text = postProcessNumbers(text);

    return ASRPartialResult(
      text: text,
      isFinal: result.isFinal,
      index: result.index,
      confidence: result.confidence,
      pluginId: result.pluginId,
    );
  }

  @override
  String processText(String text) {
    var result = postProcessNumbers(text);
    result = normalizeAmountUnit(result);
    return result;
  }

  /// 后处理：数字识别纠错
  String postProcessNumbers(String text) {
    const corrections = {
      '一': '1',
      '二': '2',
      '三': '3',
      '四': '4',
      '五': '5',
      '六': '6',
      '七': '7',
      '八': '8',
      '九': '9',
      '十': '10',
      '两': '2',
      '俩': '2',
      '零': '0',
    };

    var result = text;

    // 处理"十五"这种形式
    result = result.replaceAllMapped(
      RegExp(r'十([一二三四五六七八九])'),
      (m) => '1${corrections[m.group(1)]}',
    );

    // 处理单独的"十"
    result = result.replaceAll('十', '10');

    // 处理"一百二十三"这种形式
    result = result.replaceAllMapped(
      RegExp(r'([一二三四五六七八九])百([一二三四五六七八九零])?十?([一二三四五六七八九])?'),
      (m) {
        final hundreds = corrections[m.group(1)] ?? '0';
        final tens =
            m.group(2) != null ? (corrections[m.group(2)] ?? '0') : '0';
        final ones =
            m.group(3) != null ? (corrections[m.group(3)] ?? '0') : '0';
        return '$hundreds$tens$ones';
      },
    );

    // 处理"二十"这种形式
    result = result.replaceAllMapped(
      RegExp(r'([一二三四五六七八九])十([一二三四五六七八九])?'),
      (m) {
        final tens = corrections[m.group(1)] ?? '0';
        final ones =
            m.group(2) != null ? (corrections[m.group(2)] ?? '0') : '0';
        return '$tens$ones';
      },
    );

    return result;
  }

  /// 后处理：金额单位标准化
  String normalizeAmountUnit(String text) {
    return text
        .replaceAll(RegExp(r'块钱?'), '元')
        .replaceAll(RegExp(r'毛'), '角')
        .replaceAllMapped(
          RegExp(r'(\d+)元(\d)角'),
          (m) => '${m.group(1)}.${m.group(2)}元',
        )
        .replaceAllMapped(
          RegExp(r'(\d+)元(\d)分'),
          (m) => '${m.group(1)}.0${m.group(2)}元',
        );
  }
}
