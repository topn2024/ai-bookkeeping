import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 颜色选择器组件
class ColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  final String title;
  final ValueChanged<Color>? onColorChanged;

  const ColorPickerDialog({
    super.key,
    required this.initialColor,
    this.title = '选择颜色',
    this.onColorChanged,
  });

  static Future<Color?> show(
    BuildContext context, {
    required Color initialColor,
    String title = '选择颜色',
  }) {
    return showDialog<Color>(
      context: context,
      builder: (context) => ColorPickerDialog(
        initialColor: initialColor,
        title: title,
      ),
    );
  }

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Color _selectedColor;
  late TextEditingController _hexController;
  late double _hue;
  late double _saturation;
  late double _lightness;

  // 预设颜色
  static const List<Color> presetColors = [
    // 红色系
    Color(0xFFFFEBEE), Color(0xFFFFCDD2), Color(0xFFEF9A9A),
    Color(0xFFE57373), Color(0xFFF44336), Color(0xFFD32F2F),
    Color(0xFFC62828), Color(0xFFB71C1C),
    // 粉色系
    Color(0xFFFCE4EC), Color(0xFFF8BBD0), Color(0xFFF48FB1),
    Color(0xFFF06292), Color(0xFFE91E63), Color(0xFFC2185B),
    Color(0xFFAD1457), Color(0xFF880E4F),
    // 紫色系
    Color(0xFFF3E5F5), Color(0xFFE1BEE7), Color(0xFFCE93D8),
    Color(0xFFBA68C8), Color(0xFF9C27B0), Color(0xFF7B1FA2),
    Color(0xFF6A1B9A), Color(0xFF4A148C),
    // 蓝色系
    Color(0xFFE3F2FD), Color(0xFFBBDEFB), Color(0xFF90CAF9),
    Color(0xFF64B5F6), Color(0xFF2196F3), Color(0xFF1976D2),
    Color(0xFF1565C0), Color(0xFF0D47A1),
    // 青色系
    Color(0xFFE0F7FA), Color(0xFFB2EBF2), Color(0xFF80DEEA),
    Color(0xFF4DD0E1), Color(0xFF00BCD4), Color(0xFF0097A7),
    Color(0xFF00838F), Color(0xFF006064),
    // 绿色系
    Color(0xFFE8F5E9), Color(0xFFC8E6C9), Color(0xFFA5D6A7),
    Color(0xFF81C784), Color(0xFF4CAF50), Color(0xFF388E3C),
    Color(0xFF2E7D32), Color(0xFF1B5E20),
    // 黄色系
    Color(0xFFFFFDE7), Color(0xFFFFF9C4), Color(0xFFFFF59D),
    Color(0xFFFFF176), Color(0xFFFFEB3B), Color(0xFFFBC02D),
    Color(0xFFF9A825), Color(0xFFF57F17),
    // 橙色系
    Color(0xFFFFF3E0), Color(0xFFFFE0B2), Color(0xFFFFCC80),
    Color(0xFFFFB74D), Color(0xFFFF9800), Color(0xFFF57C00),
    Color(0xFFEF6C00), Color(0xFFE65100),
    // 灰色系
    Color(0xFFFAFAFA), Color(0xFFF5F5F5), Color(0xFFEEEEEE),
    Color(0xFFE0E0E0), Color(0xFF9E9E9E), Color(0xFF757575),
    Color(0xFF616161), Color(0xFF424242),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedColor = widget.initialColor;
    _hexController = TextEditingController(
      text: _colorToHex(_selectedColor),
    );
    _updateHSL();
  }

  void _updateHSL() {
    final hsl = HSLColor.fromColor(_selectedColor);
    _hue = hsl.hue;
    _saturation = hsl.saturation;
    _lightness = hsl.lightness;
  }

  void _updateColorFromHSL() {
    setState(() {
      _selectedColor = HSLColor.fromAHSL(1.0, _hue, _saturation, _lightness).toColor();
      _hexController.text = _colorToHex(_selectedColor);
    });
    widget.onColorChanged?.call(_selectedColor);
  }

  String _colorToHex(Color color) {
    return color.value.toRadixString(16).padLeft(8, '0').toUpperCase().substring(2);
  }

  Color? _hexToColor(String hex) {
    try {
      hex = hex.replaceAll('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      } else if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
    } catch (e) {
      // 无效的十六进制
    }
    return null;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _hexController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 320,
        height: 400,
        child: Column(
          children: [
            // 当前选中颜色预览
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: _selectedColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).dividerColor,
                ),
              ),
              child: Center(
                child: Text(
                  '#${_colorToHex(_selectedColor)}',
                  style: TextStyle(
                    color: _selectedColor.computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 标签页
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: '预设'),
                Tab(text: '调色板'),
                Tab(text: '自定义'),
              ],
            ),
            const SizedBox(height: 8),
            // 标签页内容
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPresetColors(),
                  _buildHSLPicker(),
                  _buildCustomInput(),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selectedColor),
          child: const Text('确定'),
        ),
      ],
    );
  }

  Widget _buildPresetColors() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: presetColors.length,
      itemBuilder: (context, index) {
        final color = presetColors[index];
        final isSelected = color.value == _selectedColor.value;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedColor = color;
              _hexController.text = _colorToHex(color);
              _updateHSL();
            });
            widget.onColorChanged?.call(color);
          },
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              border: isSelected
                  ? Border.all(color: Colors.black, width: 2)
                  : null,
            ),
            child: isSelected
                ? Icon(
                    Icons.check,
                    size: 16,
                    color: color.computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white,
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _buildHSLPicker() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // 色相滑块
          _buildSlider(
            label: '色相',
            value: _hue,
            max: 360,
            gradient: LinearGradient(
              colors: List.generate(
                7,
                (i) => HSLColor.fromAHSL(1.0, i * 60.0, 1.0, 0.5).toColor(),
              ),
            ),
            onChanged: (value) {
              _hue = value;
              _updateColorFromHSL();
            },
          ),
          const SizedBox(height: 16),
          // 饱和度滑块
          _buildSlider(
            label: '饱和度',
            value: _saturation,
            max: 1,
            gradient: LinearGradient(
              colors: [
                HSLColor.fromAHSL(1.0, _hue, 0, _lightness).toColor(),
                HSLColor.fromAHSL(1.0, _hue, 1, _lightness).toColor(),
              ],
            ),
            onChanged: (value) {
              _saturation = value;
              _updateColorFromHSL();
            },
          ),
          const SizedBox(height: 16),
          // 亮度滑块
          _buildSlider(
            label: '亮度',
            value: _lightness,
            max: 1,
            gradient: LinearGradient(
              colors: [
                HSLColor.fromAHSL(1.0, _hue, _saturation, 0).toColor(),
                HSLColor.fromAHSL(1.0, _hue, _saturation, 0.5).toColor(),
                HSLColor.fromAHSL(1.0, _hue, _saturation, 1).toColor(),
              ],
            ),
            onChanged: (value) {
              _lightness = value;
              _updateColorFromHSL();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double max,
    required Gradient gradient,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(
              max == 1
                  ? '${(value * 100).round()}%'
                  : '${value.round()}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 24,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 24,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 10,
              ),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              trackShape: const RoundedRectSliderTrackShape(),
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: Colors.transparent,
              thumbColor: Colors.white,
              overlayColor: Colors.white.withOpacity(0.2),
            ),
            child: Slider(
              value: value,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomInput() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('十六进制颜色值'),
          const SizedBox(height: 8),
          TextField(
            controller: _hexController,
            decoration: const InputDecoration(
              prefixText: '#',
              hintText: 'RRGGBB',
              helperText: '输入6位十六进制颜色值',
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Fa-f]')),
              LengthLimitingTextInputFormatter(6),
            ],
            onChanged: (value) {
              final color = _hexToColor(value);
              if (color != null) {
                setState(() {
                  _selectedColor = color;
                  _updateHSL();
                });
                widget.onColorChanged?.call(color);
              }
            },
          ),
          const SizedBox(height: 24),
          const Text('RGB 值'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildRGBField('R', _selectedColor.red, (v) {
                  setState(() {
                    _selectedColor = _selectedColor.withRed(v);
                    _hexController.text = _colorToHex(_selectedColor);
                    _updateHSL();
                  });
                  widget.onColorChanged?.call(_selectedColor);
                }),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildRGBField('G', _selectedColor.green, (v) {
                  setState(() {
                    _selectedColor = _selectedColor.withGreen(v);
                    _hexController.text = _colorToHex(_selectedColor);
                    _updateHSL();
                  });
                  widget.onColorChanged?.call(_selectedColor);
                }),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildRGBField('B', _selectedColor.blue, (v) {
                  setState(() {
                    _selectedColor = _selectedColor.withBlue(v);
                    _hexController.text = _colorToHex(_selectedColor);
                    _updateHSL();
                  });
                  widget.onColorChanged?.call(_selectedColor);
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRGBField(String label, int value, ValueChanged<int> onChanged) {
    return TextField(
      decoration: InputDecoration(
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(3),
      ],
      controller: TextEditingController(text: value.toString()),
      onChanged: (text) {
        final v = int.tryParse(text);
        if (v != null && v >= 0 && v <= 255) {
          onChanged(v);
        }
      },
    );
  }
}

/// 颜色选择按钮
class ColorPickerButton extends StatelessWidget {
  final Color color;
  final String? label;
  final VoidCallback? onTap;
  final double size;

  const ColorPickerButton({
    super.key,
    required this.color,
    this.label,
    this.onTap,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).dividerColor,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: label != null
            ? Center(
                child: Text(
                  label!,
                  style: TextStyle(
                    fontSize: 10,
                    color: color.computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

/// 颜色选择行组件
class ColorPickerRow extends StatelessWidget {
  final String label;
  final String? description;
  final Color color;
  final ValueChanged<Color> onColorChanged;

  const ColorPickerRow({
    super.key,
    required this.label,
    this.description,
    required this.color,
    required this.onColorChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      subtitle: description != null ? Text(description!) : null,
      trailing: ColorPickerButton(
        color: color,
        onTap: () async {
          final newColor = await ColorPickerDialog.show(
            context,
            initialColor: color,
            title: label,
          );
          if (newColor != null) {
            onColorChanged(newColor);
          }
        },
      ),
    );
  }
}
