import 'package:flutter/material.dart';
import '../../models/help_content.dart';
import '../../theme/app_theme.dart';
import 'page_help_detail_widget.dart';

/// 模块列表组件
class ModuleListWidget extends StatelessWidget {
  final Map<String, List<HelpContent>> moduleContents;
  final Map<String, String> moduleNames;
  final Map<String, IconData> moduleIcons;

  const ModuleListWidget({
    super.key,
    required this.moduleContents,
    required this.moduleNames,
    required this.moduleIcons,
  });

  @override
  Widget build(BuildContext context) {
    final modules = moduleContents.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: modules.length,
      itemBuilder: (context, index) {
        final module = modules[index];
        final contents = moduleContents[module] ?? [];
        final moduleName = moduleNames[module] ?? module;
        final icon = moduleIcons[module] ?? Icons.folder;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              _showModulePages(context, moduleName, contents);
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: AppColors.primary, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          moduleName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${contents.length} 个页面',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showModulePages(
    BuildContext context,
    String moduleName,
    List<HelpContent> contents,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(moduleName),
          ),
          body: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: contents.length,
            itemBuilder: (context, index) {
              final content = contents[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(content.title),
                  subtitle: Text(
                    content.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            PageHelpDetailWidget(content: content),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
