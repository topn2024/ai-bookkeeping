import 'package:flutter/material.dart';
import '../../models/help_content.dart';
import '../../theme/app_theme.dart';

/// 帮助搜索组件
class HelpSearchWidget extends StatefulWidget {
  final Function(String) onSearch;
  final Function(HelpContent) onResultTap;

  const HelpSearchWidget({
    super.key,
    required this.onSearch,
    required this.onResultTap,
  });

  @override
  State<HelpSearchWidget> createState() => _HelpSearchWidgetState();
}

class _HelpSearchWidgetState extends State<HelpSearchWidget> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(
          hintText: '搜索帮助内容...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _controller.clear();
                    widget.onSearch('');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey.shade100,
        ),
        onChanged: (value) {
          widget.onSearch(value);
        },
      ),
    );
  }
}
