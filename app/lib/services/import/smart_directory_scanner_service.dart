import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'bill_format_detector.dart';

/// 扫描进度回调
typedef ScanProgressCallback = void Function(
  ScanStage stage,
  int current,
  int total,
  String? currentPath,
);

/// 智能目录扫描服务
/// 设计文档第11.1.1节：智能账单发现交互流程
/// - 扫描微信、支付宝、各银行的默认导出目录
/// - 识别可导入的账单文件
/// - 支持多平台（Android/iOS）
class SmartDirectoryScannerService {
  final BillFormatDetector _formatDetector = BillFormatDetector();

  /// 默认扫描目录配置
  static const Map<String, List<String>> _defaultDirectories = {
    'wechat': [
      '/storage/emulated/0/Download/WeChat',
      '/storage/emulated/0/tencent/MicroMsg/Download',
      '/storage/emulated/0/Android/data/com.tencent.mm/MicroMsg/Download',
      // iOS
      '/var/mobile/Containers/Data/Application/WeChat/Documents',
    ],
    'alipay': [
      '/storage/emulated/0/Download/Alipay',
      '/storage/emulated/0/alipay',
      '/storage/emulated/0/Android/data/com.eg.android.AlipayGphone',
      // iOS
      '/var/mobile/Containers/Data/Application/Alipay',
    ],
    'bank': [
      '/storage/emulated/0/Download',
      '/storage/emulated/0/Documents',
      // iOS
      '/var/mobile/Containers/Data/Application/Documents',
    ],
    'download': [
      '/storage/emulated/0/Download',
      '/storage/emulated/0/DCIM',
      '/storage/emulated/0/Documents',
    ],
  };

  /// 支持的账单文件扩展名
  static const List<String> _supportedExtensions = [
    '.csv',
    '.xlsx',
    '.xls',
  ];

  /// 账单文件名关键词
  static const List<String> _billKeywords = [
    '账单',
    'bill',
    '流水',
    '明细',
    '交易',
    'transaction',
    '微信',
    'wechat',
    '支付宝',
    'alipay',
    '银行',
    'bank',
    '招商',
    '工商',
    '建设',
    '农业',
    '中国银行',
  ];

  /// 扫描所有默认目录
  Future<List<DiscoveredBillFile>> scanDefaultDirectories({
    void Function(ScanStage stage, int current, int total, String? path)?
        onProgress,
  }) async {
    final discoveredFiles = <DiscoveredBillFile>[];
    final allPaths = <String>[];

    // 收集所有要扫描的目录
    for (final paths in _defaultDirectories.values) {
      allPaths.addAll(paths);
    }

    // 添加应用文档目录
    try {
      final appDir = await getApplicationDocumentsDirectory();
      allPaths.add(appDir.path);

      final downloadDir = await getDownloadsDirectory();
      if (downloadDir != null) {
        allPaths.add(downloadDir.path);
      }

      final externalDirs = await getExternalStorageDirectories();
      if (externalDirs != null) {
        for (final dir in externalDirs) {
          allPaths.add(dir.path);
          // 也扫描父目录的Download文件夹
          final downloadPath = '${dir.parent.path}/Download';
          allPaths.add(downloadPath);
        }
      }
    } catch (e) {
      // 权限问题或平台不支持，继续扫描其他目录
    }

    // 去重
    final uniquePaths = allPaths.toSet().toList();

    onProgress?.call(ScanStage.preparing, 0, uniquePaths.length, null);

    // 扫描每个目录
    for (int i = 0; i < uniquePaths.length; i++) {
      final dirPath = uniquePaths[i];
      onProgress?.call(ScanStage.scanning, i + 1, uniquePaths.length, dirPath);

      final files = await _scanDirectory(dirPath);
      discoveredFiles.addAll(files);
    }

    // 分析文件格式
    onProgress?.call(
        ScanStage.analyzing, 0, discoveredFiles.length, '正在分析文件格式...');

    for (int i = 0; i < discoveredFiles.length; i++) {
      final file = discoveredFiles[i];
      onProgress?.call(
          ScanStage.analyzing, i + 1, discoveredFiles.length, file.fileName);

      try {
        final formatResult =
            await _formatDetector.detectFromFile(file.fullPath);
        discoveredFiles[i] = file.copyWith(
          sourceType: formatResult.sourceType,
          confidence: formatResult.confidence,
          estimatedRecordCount: formatResult.estimatedRecordCount,
        );
      } catch (e) {
        // 无法检测格式，保留默认值
      }
    }

    // 按置信度和修改时间排序
    discoveredFiles.sort((a, b) {
      // 先按置信度排序
      final confidenceCompare = b.confidence.compareTo(a.confidence);
      if (confidenceCompare != 0) return confidenceCompare;
      // 再按修改时间排序
      return b.lastModified.compareTo(a.lastModified);
    });

    onProgress?.call(
        ScanStage.completed, discoveredFiles.length, discoveredFiles.length, null);

    return discoveredFiles;
  }

  /// 扫描单个目录
  Future<List<DiscoveredBillFile>> _scanDirectory(String dirPath) async {
    final discoveredFiles = <DiscoveredBillFile>[];

    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) return discoveredFiles;

      await for (final entity in dir.list(recursive: false, followLinks: false)) {
        if (entity is File) {
          final file = await _analyzeFile(entity);
          if (file != null) {
            discoveredFiles.add(file);
          }
        }
      }
    } catch (e) {
      // 权限问题，跳过该目录
    }

    return discoveredFiles;
  }

  /// 分析单个文件是否为账单文件
  Future<DiscoveredBillFile?> _analyzeFile(File file) async {
    final fileName = file.path.split('/').last.split('\\').last;
    final extension = fileName.contains('.')
        ? '.${fileName.split('.').last.toLowerCase()}'
        : '';

    // 检查扩展名
    if (!_supportedExtensions.contains(extension)) {
      return null;
    }

    // 检查文件名是否包含账单关键词
    final lowerFileName = fileName.toLowerCase();
    bool hasKeyword = false;
    String? matchedKeyword;

    for (final keyword in _billKeywords) {
      if (lowerFileName.contains(keyword.toLowerCase())) {
        hasKeyword = true;
        matchedKeyword = keyword;
        break;
      }
    }

    // 如果文件名不包含关键词，但在微信/支付宝目录下，也认为是账单
    final filePath = file.path.toLowerCase();
    final inWechatDir =
        filePath.contains('wechat') || filePath.contains('micromsg');
    final inAlipayDir = filePath.contains('alipay');

    if (!hasKeyword && !inWechatDir && !inAlipayDir) {
      // 对于Download目录下的CSV文件，尝试读取文件头判断
      if (extension == '.csv') {
        try {
          final content = await file.readAsString();
          final firstLine = content.split('\n').first.toLowerCase();
          // 检查CSV头是否包含账单特征
          if (firstLine.contains('交易时间') ||
              firstLine.contains('transaction') ||
              firstLine.contains('金额') ||
              firstLine.contains('amount') ||
              firstLine.contains('收支') ||
              firstLine.contains('备注')) {
            hasKeyword = true;
            matchedKeyword = '交易';
          }
        } catch (e) {
          return null;
        }
      } else {
        return null;
      }
    }

    // 获取文件信息
    final stat = await file.stat();
    final fileSize = stat.size;
    final lastModified = stat.modified;

    // 检测来源
    String source = 'generic';
    if (inWechatDir || lowerFileName.contains('微信') || lowerFileName.contains('wechat')) {
      source = 'wechat';
    } else if (inAlipayDir || lowerFileName.contains('支付宝') || lowerFileName.contains('alipay')) {
      source = 'alipay';
    } else if (lowerFileName.contains('银行') ||
        lowerFileName.contains('bank') ||
        lowerFileName.contains('招商') ||
        lowerFileName.contains('工商') ||
        lowerFileName.contains('建设') ||
        lowerFileName.contains('农业')) {
      source = 'bank';
    }

    return DiscoveredBillFile(
      id: file.path.hashCode.toString(),
      fileName: fileName,
      fullPath: file.path,
      directoryPath: file.parent.path,
      source: source,
      fileSize: fileSize,
      lastModified: lastModified,
      matchedKeyword: matchedKeyword,
      sourceType: BillSourceType.unknown,
      confidence: 0.5, // 默认置信度，后续会更新
      estimatedRecordCount: 0,
    );
  }

  /// 扫描指定目录
  Future<List<DiscoveredBillFile>> scanDirectory(
    String dirPath, {
    bool recursive = false,
    void Function(int scanned, String? currentFile)? onProgress,
  }) async {
    final discoveredFiles = <DiscoveredBillFile>[];
    int scannedCount = 0;

    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) return discoveredFiles;

      await for (final entity
          in dir.list(recursive: recursive, followLinks: false)) {
        if (entity is File) {
          scannedCount++;
          onProgress?.call(scannedCount, entity.path);

          final file = await _analyzeFile(entity);
          if (file != null) {
            // 检测格式
            try {
              final formatResult =
                  await _formatDetector.detectFromFile(file.fullPath);
              discoveredFiles.add(file.copyWith(
                sourceType: formatResult.sourceType,
                confidence: formatResult.confidence,
                estimatedRecordCount: formatResult.estimatedRecordCount,
              ));
            } catch (e) {
              discoveredFiles.add(file);
            }
          }
        }
      }
    } catch (e) {
      // 权限问题
    }

    // 排序
    discoveredFiles.sort((a, b) => b.lastModified.compareTo(a.lastModified));

    return discoveredFiles;
  }

  /// 获取最近导入过的目录
  Future<List<String>> getRecentDirectories() async {
    try {
      // 从SharedPreferences读取最近使用的目录
      final prefs = await SharedPreferences.getInstance();
      final recentDirs = prefs.getStringList('recent_import_directories') ?? [];
      return recentDirs;
    } catch (e) {
      return [];
    }
  }

  /// 保存最近使用的目录
  Future<void> saveRecentDirectory(String path) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recentDirs = prefs.getStringList('recent_import_directories') ?? [];

      // 移除重复项
      recentDirs.remove(path);

      // 添加到开头
      recentDirs.insert(0, path);

      // 只保留最近10个
      if (recentDirs.length > 10) {
        recentDirs.removeRange(10, recentDirs.length);
      }

      await prefs.setStringList('recent_import_directories', recentDirs);
    } catch (e) {
      // 忽略错误
    }
  }
}

/// 扫描阶段
enum ScanStage {
  preparing,  // 准备中
  scanning,   // 扫描目录
  analyzing,  // 分析文件格式
  completed,  // 完成
}

/// 发现的账单文件
class DiscoveredBillFile {
  final String id;
  final String fileName;
  final String fullPath;
  final String directoryPath;
  final String source; // wechat, alipay, bank, generic
  final int fileSize;
  final DateTime lastModified;
  final String? matchedKeyword;
  final BillSourceType sourceType;
  final double confidence;
  final int estimatedRecordCount;

  DiscoveredBillFile({
    required this.id,
    required this.fileName,
    required this.fullPath,
    required this.directoryPath,
    required this.source,
    required this.fileSize,
    required this.lastModified,
    this.matchedKeyword,
    this.sourceType = BillSourceType.unknown,
    this.confidence = 0.5,
    this.estimatedRecordCount = 0,
  });

  DiscoveredBillFile copyWith({
    String? id,
    String? fileName,
    String? fullPath,
    String? directoryPath,
    String? source,
    int? fileSize,
    DateTime? lastModified,
    String? matchedKeyword,
    BillSourceType? sourceType,
    double? confidence,
    int? estimatedRecordCount,
  }) {
    return DiscoveredBillFile(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      fullPath: fullPath ?? this.fullPath,
      directoryPath: directoryPath ?? this.directoryPath,
      source: source ?? this.source,
      fileSize: fileSize ?? this.fileSize,
      lastModified: lastModified ?? this.lastModified,
      matchedKeyword: matchedKeyword ?? this.matchedKeyword,
      sourceType: sourceType ?? this.sourceType,
      confidence: confidence ?? this.confidence,
      estimatedRecordCount: estimatedRecordCount ?? this.estimatedRecordCount,
    );
  }

  /// 获取来源显示名称
  String get sourceDisplayName {
    switch (source) {
      case 'wechat':
        return '微信';
      case 'alipay':
        return '支付宝';
      case 'bank':
        return '银行';
      default:
        return '其他';
    }
  }

  /// 获取文件大小显示
  String get fileSizeDisplay {
    if (fileSize < 1024) {
      return '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  /// 获取日期范围显示（从文件名推断）
  String get dateRangeDisplay {
    // 尝试从文件名中提取日期
    final patterns = [
      RegExp(r'(\d{4})[-_]?(\d{2})'), // 2024-12 或 202412
      RegExp(r'(\d{4})年(\d{1,2})月'),
      RegExp(r'Q([1-4])[-_]?(\d{4})'), // Q4-2024
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(fileName);
      if (match != null) {
        if (match.groupCount >= 2) {
          return '${match.group(1)}年${match.group(2)}月';
        }
      }
    }

    // 使用修改时间
    return '${lastModified.year}年${lastModified.month}月';
  }
}
