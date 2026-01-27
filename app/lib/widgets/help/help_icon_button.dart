import 'package:flutter/material.dart';
import '../../services/help_content_service.dart';
import 'page_help_detail_widget.dart';

/// 帮助图标按钮组件
/// 可以添加到任何页面的AppBar中，点击后显示该页面的帮助内容
class HelpIconButton extends StatelessWidget {
  /// 页面ID，对应帮助内容中的pageId
  final String pageId;

  /// 图标颜色
  final Color? iconColor;

  const HelpIconButton({
    super.key,
    required this.pageId,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        Icons.help_outline,
        color: iconColor,
      ),
      tooltip: '查看帮助',
      onPressed: () => _showHelp(context),
    );
  }

  void _showHelp(BuildContext context) {
    final helpService = HelpContentService();
    final content = helpService.getContentByPageId(pageId);

    if (content == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('暂无帮助内容'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PageHelpDetailWidget(content: content),
      ),
    );
  }
}

/// 浮动帮助按钮组件
class FloatingHelpButton extends StatelessWidget {
  final String pageId;
  final Color? backgroundColor;
  final Color? iconColor;

  const FloatingHelpButton({
    super.key,
    required this.pageId,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      mini: true,
      backgroundColor: backgroundColor ?? Colors.blue.shade100,
      onPressed: () => _showHelp(context),
      child: Icon(
        Icons.help_outline,
        color: iconColor ?? Colors.blue.shade700,
      ),
    );
  }

  void _showHelp(BuildContext context) {
    final helpService = HelpContentService();
    final content = helpService.getContentByPageId(pageId);

    if (content == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('暂无帮助内容'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PageHelpDetailWidget(content: content),
      ),
    );
  }
}
