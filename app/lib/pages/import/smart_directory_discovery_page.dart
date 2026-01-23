import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../services/import/smart_directory_scanner_service.dart';
import 'smart_format_detection_page.dart';

/// 智能目录发现页面
/// 原型设计 5.16：智能目录发现
/// 设计文档第11.1.1节：智能账单发现交互流程
/// - 扫描微信、支付宝、银行默认导出目录
/// - 扫描状态显示
/// - 发现的账单文件列表（可多选）
/// - 文件来源标识（微信/支付宝/银行）
/// - 重新扫描和浏览其他目录选项
/// - 导入选中文件按钮
class SmartDirectoryDiscoveryPage extends ConsumerStatefulWidget {
  const SmartDirectoryDiscoveryPage({super.key});

  @override
  ConsumerState<SmartDirectoryDiscoveryPage> createState() =>
      _SmartDirectoryDiscoveryPageState();
}

class _SmartDirectoryDiscoveryPageState
    extends ConsumerState<SmartDirectoryDiscoveryPage> {
  final SmartDirectoryScannerService _scannerService =
      SmartDirectoryScannerService();

  bool _isScanning = false;
  List<DiscoveredFile> _discoveredFiles = [];
  Set<String> _selectedFiles = {};

  // 扫描进度
  String _scanStatus = '';
  int _scanProgress = 0;
  int _scanTotal = 0;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _scanStatus = '准备扫描...';
      _scanProgress = 0;
      _scanTotal = 0;
      _discoveredFiles = [];
      _selectedFiles = {};
    });

    try {
      final files = await _scannerService.scanDefaultDirectories(
        onProgress: (stage, current, total, path) {
          setState(() {
            _scanProgress = current;
            _scanTotal = total;
            switch (stage) {
              case ScanStage.preparing:
                _scanStatus = '准备扫描目录...';
                break;
              case ScanStage.scanning:
                _scanStatus = '正在扫描: ${path ?? ""}';
                break;
              case ScanStage.analyzing:
                _scanStatus = '正在分析: ${path ?? ""}';
                break;
              case ScanStage.completed:
                _scanStatus = '扫描完成';
                break;
            }
          });
        },
      );

      // 转换为UI模型
      final uiFiles = files.map((f) => DiscoveredFile(
            id: f.id,
            fileName: f.fileName,
            source: f.source,
            recordCount: f.estimatedRecordCount,
            dateRange: f.dateRangeDisplay,
            fileSize: f.fileSizeDisplay,
            filePath: f.directoryPath,
            fullPath: f.fullPath,
            confidence: f.confidence,
          )).toList();

      setState(() {
        _isScanning = false;
        _discoveredFiles = uiFiles;
        // 默认选中置信度高于0.7的文件
        _selectedFiles = uiFiles
            .where((f) => f.confidence >= 0.7)
            .map((f) => f.id)
            .toSet();
      });
    } catch (e) {
      setState(() {
        _isScanning = false;
        _scanStatus = '扫描出错: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('发现账单'),
      ),
      body: Column(
        children: [
          _buildScanStatus(theme),
          Expanded(
            child: _isScanning
                ? _buildScanningIndicator(theme)
                : _buildFileList(theme),
          ),
          if (!_isScanning && _discoveredFiles.isNotEmpty)
            _buildBottomSection(context, theme),
        ],
      ),
    );
  }
            ),
          ),
          GestureDetector(
            onTap: _isScanning ? null : () => _browseDirectory(context),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Icon(
                Icons.folder_open,
                color: _isScanning
                    ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 扫描状态显示
  Widget _buildScanStatus(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isScanning ? Icons.radar : Icons.search,
              color: const Color(0xFF4CAF50),
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _isScanning ? '正在扫描目录...' : '已扫描默认目录',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isScanning
                ? '请稍候'
                : '找到 ${_discoveredFiles.length} 个可导入的账单文件',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// 扫描中指示器
  Widget _buildScanningIndicator(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: theme.colorScheme.primary,
            value: _scanTotal > 0 ? _scanProgress / _scanTotal : null,
          ),
          const SizedBox(height: 16),
          Text(
            _scanStatus,
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (_scanTotal > 0) ...[
            const SizedBox(height: 8),
            Text(
              '$_scanProgress / $_scanTotal',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 文件列表
  Widget _buildFileList(ThemeData theme) {
    if (_discoveredFiles.isEmpty) {
      return _buildEmptyState(theme);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            '发现的账单文件',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        ..._discoveredFiles.map((file) => _buildFileCard(theme, file)),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_off,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '未发现账单文件',
            style: TextStyle(
              fontSize: 16,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '请手动选择文件或检查下载目录',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileCard(ThemeData theme, DiscoveredFile file) {
    final isSelected = _selectedFiles.contains(file.id);
    final sourceColor = _getSourceColor(file.source);
    final sourceIcon = _getSourceIcon(file.source);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: sourceColor, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: isSelected,
                  onChanged: (v) => _toggleSelection(file.id),
                  activeColor: sourceColor,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: sourceColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(sourceIcon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.fileName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      '${file.recordCount}条记录 · ${file.dateRange} · ${file.fileSize}',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                  style: BorderStyle.solid,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.folder,
                  size: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  file.filePath,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getSourceColor(String source) {
    switch (source) {
      case 'wechat':
        return const Color(0xFF07C160);
      case 'alipay':
        return const Color(0xFF1677FF);
      case 'bank':
        return const Color(0xFFFF6B35);
      default:
        return Colors.grey;
    }
  }

  IconData _getSourceIcon(String source) {
    switch (source) {
      case 'wechat':
        return Icons.chat;
      case 'alipay':
        return Icons.account_balance_wallet;
      case 'bank':
        return Icons.account_balance;
      default:
        return Icons.description;
    }
  }

  /// 底部区域
  Widget _buildBottomSection(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _startScan,
                child: Row(
                  children: [
                    Icon(
                      Icons.refresh,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '重新扫描',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              GestureDetector(
                onTap: () => _browseDirectory(context),
                child: Row(
                  children: [
                    Icon(
                      Icons.folder_open,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '浏览其他目录',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _selectedFiles.isEmpty
                  ? null
                  : () => _importSelectedFiles(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                disabledBackgroundColor:
                    theme.colorScheme.primary.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                '导入选中的 ${_selectedFiles.length} 个文件',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleSelection(String fileId) {
    setState(() {
      if (_selectedFiles.contains(fileId)) {
        _selectedFiles.remove(fileId);
      } else {
        _selectedFiles.add(fileId);
      }
    });
  }

  void _browseDirectory(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls'],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        // 直接导入选中的文件
        final firstFile = result.files.first;
        if (firstFile.path != null && context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SmartFormatDetectionPage(
                filePath: firstFile.path!,
                fileName: firstFile.name,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择文件失败: $e')),
        );
      }
    }
  }

  void _importSelectedFiles(BuildContext context) {
    final selectedFile = _discoveredFiles.firstWhere(
      (f) => _selectedFiles.contains(f.id),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SmartFormatDetectionPage(
          filePath: selectedFile.fullPath,
          fileName: selectedFile.fileName,
        ),
      ),
    );
  }
}

/// 发现的文件
class DiscoveredFile {
  final String id;
  final String fileName;
  final String source;
  final int recordCount;
  final String dateRange;
  final String fileSize;
  final String filePath;
  final String fullPath;
  final double confidence;

  DiscoveredFile({
    required this.id,
    required this.fileName,
    required this.source,
    required this.recordCount,
    required this.dateRange,
    required this.fileSize,
    required this.filePath,
    this.fullPath = '',
    this.confidence = 0.5,
  });
}
