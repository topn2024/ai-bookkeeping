import 'dart:math';
import 'package:flutter/material.dart';

/// 文字缩放级别
enum TextScaleLevel {
  /// 最小 (0.85x)
  smallest,

  /// 较小 (0.925x)
  smaller,

  /// 正常 (1.0x)
  normal,

  /// 较大 (1.15x)
  larger,

  /// 大 (1.3x)
  large,

  /// 最大 (1.5x)
  largest,

  /// 超大 (2.0x) - 用于低视力用户
  extraLarge,

  /// 自定义
  custom,
}

/// 文字缩放配置
class TextScaleConfig {
  /// 是否跟随系统设置
  final bool followSystem;

  /// 缩放级别
  final TextScaleLevel level;

  /// 自定义缩放比例（仅当level为custom时使用）
  final double customScale;

  /// 最小缩放比例
  final double minScale;

  /// 最大缩放比例
  final double maxScale;

  /// 是否允许超过最大限制
  final bool allowExceedMax;

  const TextScaleConfig({
    this.followSystem = true,
    this.level = TextScaleLevel.normal,
    this.customScale = 1.0,
    this.minScale = 0.85,
    this.maxScale = 2.0,
    this.allowExceedMax = false,
  });

  /// 获取实际缩放比例
  double get scale {
    if (level == TextScaleLevel.custom) {
      return customScale.clamp(minScale, allowExceedMax ? 10.0 : maxScale);
    }
    return _getLevelScale(level);
  }

  double _getLevelScale(TextScaleLevel level) {
    switch (level) {
      case TextScaleLevel.smallest:
        return 0.85;
      case TextScaleLevel.smaller:
        return 0.925;
      case TextScaleLevel.normal:
        return 1.0;
      case TextScaleLevel.larger:
        return 1.15;
      case TextScaleLevel.large:
        return 1.3;
      case TextScaleLevel.largest:
        return 1.5;
      case TextScaleLevel.extraLarge:
        return 2.0;
      case TextScaleLevel.custom:
        return customScale;
    }
  }

  TextScaleConfig copyWith({
    bool? followSystem,
    TextScaleLevel? level,
    double? customScale,
    double? minScale,
    double? maxScale,
    bool? allowExceedMax,
  }) {
    return TextScaleConfig(
      followSystem: followSystem ?? this.followSystem,
      level: level ?? this.level,
      customScale: customScale ?? this.customScale,
      minScale: minScale ?? this.minScale,
      maxScale: maxScale ?? this.maxScale,
      allowExceedMax: allowExceedMax ?? this.allowExceedMax,
    );
  }
}

/// 文字缩放服务
/// 提供文字缩放支持，确保用户可以根据需要调整文字大小
class TextScalingService {
  static final TextScalingService _instance = TextScalingService._internal();
  factory TextScalingService() => _instance;
  TextScalingService._internal();

  /// 当前配置
  TextScaleConfig _config = const TextScaleConfig();

  /// 配置变更监听器
  final List<void Function(TextScaleConfig)> _listeners = [];

  /// 系统缩放比例
  double _systemScale = 1.0;

  /// 获取当前配置
  TextScaleConfig get config => _config;

  /// 获取系统缩放比例
  double get systemScale => _systemScale;

  /// 获取最终缩放比例
  double get effectiveScale {
    if (_config.followSystem) {
      return _systemScale.clamp(_config.minScale, _config.maxScale);
    }
    return _config.scale;
  }

  /// 获取TextScaler
  TextScaler get textScaler => TextScaler.linear(effectiveScale);

  /// 初始化（从BuildContext获取系统设置）
  void initialize(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    _systemScale = mediaQuery.textScaler.scale(1.0);
  }

  /// 更新系统缩放比例
  void updateSystemScale(double scale) {
    _systemScale = scale;
    if (_config.followSystem) {
      _notifyListeners();
    }
  }

  /// 设置配置
  void setConfig(TextScaleConfig config) {
    _config = config;
    _notifyListeners();
  }

  /// 设置是否跟随系统
  void setFollowSystem(bool follow) {
    _config = _config.copyWith(followSystem: follow);
    _notifyListeners();
  }

  /// 设置缩放级别
  void setLevel(TextScaleLevel level) {
    _config = _config.copyWith(
      level: level,
      followSystem: false,
    );
    _notifyListeners();
  }

  /// 设置自定义缩放比例
  void setCustomScale(double scale) {
    _config = _config.copyWith(
      level: TextScaleLevel.custom,
      customScale: scale,
      followSystem: false,
    );
    _notifyListeners();
  }

  /// 增大文字
  void increaseScale() {
    final currentScale = effectiveScale;
    final newScale = min(currentScale + 0.1, _config.maxScale);
    setCustomScale(newScale);
  }

  /// 减小文字
  void decreaseScale() {
    final currentScale = effectiveScale;
    final newScale = max(currentScale - 0.1, _config.minScale);
    setCustomScale(newScale);
  }

  /// 重置为正常
  void resetScale() {
    _config = _config.copyWith(
      level: TextScaleLevel.normal,
      followSystem: true,
    );
    _notifyListeners();
  }

  /// 添加监听器
  void addListener(void Function(TextScaleConfig) listener) {
    _listeners.add(listener);
  }

  /// 移除监听器
  void removeListener(void Function(TextScaleConfig) listener) {
    _listeners.remove(listener);
  }

  /// 通知监听器
  void _notifyListeners() {
    for (final listener in _listeners) {
      listener(_config);
    }
  }

  // ==================== 辅助方法 ====================

  /// 获取级别显示名称
  String getLevelName(TextScaleLevel level) {
    switch (level) {
      case TextScaleLevel.smallest:
        return '最小 (85%)';
      case TextScaleLevel.smaller:
        return '较小 (92.5%)';
      case TextScaleLevel.normal:
        return '正常 (100%)';
      case TextScaleLevel.larger:
        return '较大 (115%)';
      case TextScaleLevel.large:
        return '大 (130%)';
      case TextScaleLevel.largest:
        return '最大 (150%)';
      case TextScaleLevel.extraLarge:
        return '超大 (200%)';
      case TextScaleLevel.custom:
        return '自定义';
    }
  }

  /// 获取当前级别名称
  String get currentLevelName {
    if (_config.followSystem) {
      return '跟随系统 (${(_systemScale * 100).toStringAsFixed(0)}%)';
    }
    if (_config.level == TextScaleLevel.custom) {
      return '自定义 (${(_config.customScale * 100).toStringAsFixed(0)}%)';
    }
    return getLevelName(_config.level);
  }

  /// 缩放文字大小
  double scaleFont(double fontSize) {
    return fontSize * effectiveScale;
  }

  /// 获取响应式字体大小（根据屏幕尺寸和缩放比例）
  double responsiveFontSize(
    BuildContext context,
    double baseFontSize, {
    double minFontSize = 10,
    double maxFontSize = 40,
  }) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;

    // 基于屏幕宽度的缩放因子
    double screenFactor = 1.0;
    if (screenWidth < 360) {
      screenFactor = 0.9;
    } else if (screenWidth > 600) {
      screenFactor = 1.1;
    }

    final scaledSize = baseFontSize * effectiveScale * screenFactor;
    return scaledSize.clamp(minFontSize, maxFontSize);
  }

  /// 检查文字是否会溢出
  bool willTextOverflow(
    String text,
    TextStyle style,
    double maxWidth,
  ) {
    final scaledStyle = style.copyWith(
      fontSize: (style.fontSize ?? 14) * effectiveScale,
    );

    final textPainter = TextPainter(
      text: TextSpan(text: text, style: scaledStyle),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: double.infinity);

    return textPainter.width > maxWidth;
  }

  /// 获取自适应最大行数
  int getAdaptiveMaxLines(
    double containerHeight,
    double lineHeight,
  ) {
    final scaledLineHeight = lineHeight * effectiveScale;
    return (containerHeight / scaledLineHeight).floor().clamp(1, 100);
  }
}

/// 文字缩放包装组件
class TextScaleWrapper extends StatefulWidget {
  final Widget child;

  const TextScaleWrapper({
    super.key,
    required this.child,
  });

  @override
  State<TextScaleWrapper> createState() => _TextScaleWrapperState();
}

class _TextScaleWrapperState extends State<TextScaleWrapper> {
  final _service = TextScalingService();

  @override
  void initState() {
    super.initState();
    _service.addListener(_onConfigChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _service.initialize(context);
  }

  @override
  void dispose() {
    _service.removeListener(_onConfigChanged);
    super.dispose();
  }

  void _onConfigChanged(TextScaleConfig config) {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: _service.textScaler,
      ),
      child: widget.child,
    );
  }
}

/// 可缩放文本组件（不溢出）
class ScalableText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow overflow;
  final TextAlign? textAlign;
  final bool softWrap;

  /// 最小字体大小（当缩放后溢出时使用）
  final double minFontSize;

  /// 是否自动调整大小以适应容器
  final bool autoFit;

  const ScalableText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow = TextOverflow.ellipsis,
    this.textAlign,
    this.softWrap = true,
    this.minFontSize = 10,
    this.autoFit = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!autoFit) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
        textAlign: textAlign,
        softWrap: softWrap,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final service = TextScalingService();
        final effectiveStyle = style ?? DefaultTextStyle.of(context).style;
        final baseFontSize = effectiveStyle.fontSize ?? 14;

        // 计算适合容器的字体大小
        double fontSize = baseFontSize * service.effectiveScale;

        // 逐步减小字体直到适合
        while (fontSize > minFontSize) {
          final testStyle = effectiveStyle.copyWith(fontSize: fontSize);
          final textPainter = TextPainter(
            text: TextSpan(text: text, style: testStyle),
            maxLines: maxLines,
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: constraints.maxWidth);

          if (!textPainter.didExceedMaxLines) {
            break;
          }

          fontSize -= 1;
        }

        return Text(
          text,
          style: effectiveStyle.copyWith(fontSize: max(fontSize, minFontSize)),
          maxLines: maxLines,
          overflow: overflow,
          textAlign: textAlign,
          softWrap: softWrap,
        );
      },
    );
  }
}

/// 文字缩放设置面板
class TextScaleSettingsPanel extends StatefulWidget {
  final VoidCallback? onChanged;

  const TextScaleSettingsPanel({
    super.key,
    this.onChanged,
  });

  @override
  State<TextScaleSettingsPanel> createState() => _TextScaleSettingsPanelState();
}

class _TextScaleSettingsPanelState extends State<TextScaleSettingsPanel> {
  final _service = TextScalingService();

  @override
  void initState() {
    super.initState();
    _service.addListener(_onConfigChanged);
  }

  @override
  void dispose() {
    _service.removeListener(_onConfigChanged);
    super.dispose();
  }

  void _onConfigChanged(TextScaleConfig config) {
    setState(() {});
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '文字大小',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 16),

        // 跟随系统开关
        SwitchListTile(
          title: const Text('跟随系统设置'),
          subtitle: Text(
            '当前系统: ${(_service.systemScale * 100).toStringAsFixed(0)}%',
          ),
          value: _service.config.followSystem,
          onChanged: (value) => _service.setFollowSystem(value),
        ),

        const Divider(),

        // 预设级别
        if (!_service.config.followSystem) ...[
          const Text('预设大小'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: TextScaleLevel.values
                .where((l) => l != TextScaleLevel.custom)
                .map((level) => ChoiceChip(
                      label: Text(_service.getLevelName(level)),
                      selected: _service.config.level == level,
                      onSelected: (_) => _service.setLevel(level),
                    ))
                .toList(),
          ),

          const SizedBox(height: 16),

          // 自定义滑块
          Text(
            '自定义: ${(_service.effectiveScale * 100).toStringAsFixed(0)}%',
          ),
          Slider(
            value: _service.effectiveScale,
            min: _service.config.minScale,
            max: _service.config.maxScale,
            divisions: (((_service.config.maxScale - _service.config.minScale) * 10).round()),
            label: '${(_service.effectiveScale * 100).toStringAsFixed(0)}%',
            onChanged: (value) => _service.setCustomScale(value),
          ),

          // 快捷按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: _service.effectiveScale > _service.config.minScale
                    ? _service.decreaseScale
                    : null,
                tooltip: '减小文字',
              ),
              TextButton(
                onPressed: _service.resetScale,
                child: const Text('重置'),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: _service.effectiveScale < _service.config.maxScale
                    ? _service.increaseScale
                    : null,
                tooltip: '增大文字',
              ),
            ],
          ),
        ],

        const SizedBox(height: 16),

        // 预览
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: theme.dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '预览效果',
                style: theme.textTheme.labelMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '这是一段示例文字',
                style: TextStyle(
                  fontSize: 16 * _service.effectiveScale,
                ),
              ),
              Text(
                '今天支出 ¥128.50',
                style: TextStyle(
                  fontSize: 14 * _service.effectiveScale,
                  color: theme.colorScheme.primary,
                ),
              ),
              Text(
                '餐饮 - 午餐',
                style: TextStyle(
                  fontSize: 12 * _service.effectiveScale,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
