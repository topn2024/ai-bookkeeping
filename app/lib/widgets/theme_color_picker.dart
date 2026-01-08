import 'package:flutter/material.dart';
import '../services/personalization_settings_service.dart';

/// Theme color picker widget (第22章主题色自定义选择器)
class ThemeColorPicker extends StatefulWidget {
  final ThemeColorSetting currentColor;
  final ValueChanged<ThemeColorSetting> onColorChanged;

  const ThemeColorPicker({
    super.key,
    required this.currentColor,
    required this.onColorChanged,
  });

  @override
  State<ThemeColorPicker> createState() => _ThemeColorPickerState();
}

class _ThemeColorPickerState extends State<ThemeColorPicker> {
  late ThemeColorSetting _selectedColor;
  bool _showCustomPicker = false;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.currentColor;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final presets = PersonalizationSettingsService.presetColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '选择你喜欢的主题色',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 16),

        // Preset colors
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ...presets.map((preset) => _buildColorOption(preset)),
            _buildCustomColorButton(),
          ],
        ),

        // Custom color picker
        if (_showCustomPicker) ...[
          const SizedBox(height: 24),
          _buildCustomColorPicker(),
        ],

        // Preview
        const SizedBox(height: 24),
        _buildPreview(),
      ],
    );
  }

  Widget _buildColorOption(ThemeColorSetting colorSetting) {
    final isSelected = _selectedColor.id == colorSetting.id;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedColor = colorSetting;
          _showCustomPicker = false;
        });
        widget.onColorChanged(colorSetting);
      },
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: colorSetting.color,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: Colors.white, width: 3)
                  : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: colorSetting.color.withValues(alpha: 0.5),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 24)
                : null,
          ),
          const SizedBox(height: 4),
          Text(
            colorSetting.name,
            style: TextStyle(
              fontSize: 12,
              color: isSelected
                  ? colorSetting.color
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomColorButton() {
    final isCustom = _selectedColor.id == 'custom';

    return GestureDetector(
      onTap: () {
        setState(() {
          _showCustomPicker = true;
        });
      },
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Colors.red,
                  Colors.orange,
                  Colors.yellow,
                  Colors.green,
                  Colors.blue,
                  Colors.purple,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: isCustom ? Border.all(color: Colors.white, width: 3) : null,
            ),
            child: const Icon(Icons.palette, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            '自定义',
            style: TextStyle(
              fontSize: 12,
              color: isCustom
                  ? _selectedColor.color
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: isCustom ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomColorPicker() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '自定义颜色',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 16),

          // Hue slider
          _buildHueSlider(),
          const SizedBox(height: 16),

          // Saturation slider
          _buildSaturationSlider(),
          const SizedBox(height: 16),

          // Brightness slider
          _buildBrightnessSlider(),
        ],
      ),
    );
  }

  Widget _buildHueSlider() {
    final hsl = HSLColor.fromColor(_selectedColor.color);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('色相', style: TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 12,
            trackShape: _GradientTrackShape(
              gradient: LinearGradient(
                colors: List.generate(
                  360,
                  (i) => HSLColor.fromAHSL(1, i.toDouble(), 0.8, 0.5).toColor(),
                ),
              ),
            ),
          ),
          child: Slider(
            value: hsl.hue,
            min: 0,
            max: 360,
            onChanged: (value) {
              final newColor = hsl.withHue(value).toColor();
              setState(() {
                _selectedColor = ThemeColorSetting.custom(newColor);
              });
              widget.onColorChanged(_selectedColor);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSaturationSlider() {
    final hsl = HSLColor.fromColor(_selectedColor.color);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('饱和度', style: TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        Slider(
          value: hsl.saturation,
          min: 0,
          max: 1,
          activeColor: _selectedColor.color,
          onChanged: (value) {
            final newColor = hsl.withSaturation(value).toColor();
            setState(() {
              _selectedColor = ThemeColorSetting.custom(newColor);
            });
            widget.onColorChanged(_selectedColor);
          },
        ),
      ],
    );
  }

  Widget _buildBrightnessSlider() {
    final hsl = HSLColor.fromColor(_selectedColor.color);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('亮度', style: TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        Slider(
          value: hsl.lightness,
          min: 0.2,
          max: 0.8,
          activeColor: _selectedColor.color,
          onChanged: (value) {
            final newColor = hsl.withLightness(value).toColor();
            setState(() {
              _selectedColor = ThemeColorSetting.custom(newColor);
            });
            widget.onColorChanged(_selectedColor);
          },
        ),
      ],
    );
  }

  Widget _buildPreview() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '预览效果',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          // Sample transaction card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _selectedColor.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _selectedColor.color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.restaurant, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('午餐', style: TextStyle(fontWeight: FontWeight.w500)),
                      Text('今天 12:30', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                Text(
                  '¥35.00',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _selectedColor.color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Sample button
          FilledButton(
            onPressed: () {},
            style: FilledButton.styleFrom(
              backgroundColor: _selectedColor.color,
            ),
            child: const Text('记账'),
          ),
        ],
      ),
    );
  }
}

/// Custom gradient track shape for hue slider
class _GradientTrackShape extends SliderTrackShape {
  final LinearGradient gradient;

  _GradientTrackShape({required this.gradient});

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 4;
    final trackWidth = parentBox.size.width;
    final trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    return Rect.fromLTWH(offset.dx, trackTop, trackWidth, trackHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
  }) {
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;

    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
    context.canvas.drawRRect(rrect, paint);
  }
}
