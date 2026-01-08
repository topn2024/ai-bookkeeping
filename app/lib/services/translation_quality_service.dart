import 'dart:convert';
import 'package:flutter/services.dart';

/// 翻译质量检查服务
///
/// 用于检查和验证各语言翻译文件的完整性和质量
/// 可在开发阶段使用，帮助发现翻译问题
class TranslationQualityService {
  TranslationQualityService._();
  static final TranslationQualityService instance = TranslationQualityService._();

  /// 基准语言（用于比较的参考语言）
  static const String baseLanguage = 'en';

  /// 支持的语言列表
  static const List<String> supportedLanguages = ['en', 'zh', 'ja', 'ko'];

  /// ARB 文件路径
  static String _getArbPath(String lang) => 'lib/l10n/app_$lang.arb';

  /// 翻译质量检查结果
  Future<TranslationQualityReport> checkTranslationQuality() async {
    final issues = <TranslationIssue>[];
    final stats = <String, TranslationStats>{};

    try {
      // 加载基准语言文件
      final baseContent = await _loadArbFile(baseLanguage);
      if (baseContent == null) {
        return TranslationQualityReport(
          issues: [
            TranslationIssue(
              type: IssueType.critical,
              language: baseLanguage,
              key: '',
              message: 'Failed to load base language file',
            )
          ],
          stats: {},
          overallScore: 0,
        );
      }

      final baseKeys = _extractKeys(baseContent);

      // 检查每种语言
      for (final lang in supportedLanguages) {
        if (lang == baseLanguage) {
          stats[lang] = TranslationStats(
            totalKeys: baseKeys.length,
            translatedKeys: baseKeys.length,
            missingKeys: 0,
            emptyValues: 0,
            placeholderMismatches: 0,
          );
          continue;
        }

        final content = await _loadArbFile(lang);
        if (content == null) {
          issues.add(TranslationIssue(
            type: IssueType.critical,
            language: lang,
            key: '',
            message: 'Failed to load language file',
          ));
          continue;
        }

        final langKeys = _extractKeys(content);
        final langIssues = <TranslationIssue>[];

        // 检查缺失的翻译
        int missingCount = 0;
        for (final key in baseKeys) {
          if (!langKeys.contains(key)) {
            missingCount++;
            langIssues.add(TranslationIssue(
              type: IssueType.missing,
              language: lang,
              key: key,
              message: 'Missing translation for key: $key',
            ));
          }
        }

        // 检查空值
        int emptyCount = 0;
        for (final entry in (content).entries) {
          if (!entry.key.startsWith('@') &&
              !entry.key.startsWith('@@') &&
              entry.value is String &&
              (entry.value as String).isEmpty) {
            emptyCount++;
            langIssues.add(TranslationIssue(
              type: IssueType.empty,
              language: lang,
              key: entry.key,
              message: 'Empty translation value for key: ${entry.key}',
            ));
          }
        }

        // 检查占位符不匹配
        int placeholderMismatchCount = 0;
        for (final key in langKeys) {
          if (baseKeys.contains(key)) {
            final basePlaceholders = _extractPlaceholders(baseContent[key]?.toString() ?? '');
            final langPlaceholders = _extractPlaceholders(content[key]?.toString() ?? '');

            if (!_setEquals(basePlaceholders, langPlaceholders)) {
              placeholderMismatchCount++;
              langIssues.add(TranslationIssue(
                type: IssueType.placeholderMismatch,
                language: lang,
                key: key,
                message: 'Placeholder mismatch for key: $key. '
                    'Expected: $basePlaceholders, Got: $langPlaceholders',
              ));
            }
          }
        }

        // 检查多余的翻译
        for (final key in langKeys) {
          if (!baseKeys.contains(key)) {
            langIssues.add(TranslationIssue(
              type: IssueType.extra,
              language: lang,
              key: key,
              message: 'Extra translation key not in base: $key',
            ));
          }
        }

        issues.addAll(langIssues);
        stats[lang] = TranslationStats(
          totalKeys: baseKeys.length,
          translatedKeys: baseKeys.length - missingCount,
          missingKeys: missingCount,
          emptyValues: emptyCount,
          placeholderMismatches: placeholderMismatchCount,
        );
      }

      // 计算整体分数
      final overallScore = _calculateOverallScore(stats);

      return TranslationQualityReport(
        issues: issues,
        stats: stats,
        overallScore: overallScore,
      );
    } catch (e) {
      return TranslationQualityReport(
        issues: [
          TranslationIssue(
            type: IssueType.critical,
            language: '',
            key: '',
            message: 'Error during quality check: $e',
          )
        ],
        stats: {},
        overallScore: 0,
      );
    }
  }

  /// 检查特定语言的翻译质量
  Future<List<TranslationIssue>> checkLanguage(String language) async {
    final report = await checkTranslationQuality();
    return report.issues.where((i) => i.language == language).toList();
  }

  /// 获取翻译完成度
  Future<Map<String, double>> getTranslationCompleteness() async {
    final report = await checkTranslationQuality();
    final completeness = <String, double>{};

    for (final entry in report.stats.entries) {
      final stats = entry.value;
      if (stats.totalKeys > 0) {
        completeness[entry.key] = stats.translatedKeys / stats.totalKeys;
      } else {
        completeness[entry.key] = 0;
      }
    }

    return completeness;
  }

  /// 验证翻译文件格式
  Future<List<TranslationIssue>> validateArbFormat(String language) async {
    final issues = <TranslationIssue>[];

    try {
      final content = await _loadArbFile(language);
      if (content == null) {
        issues.add(TranslationIssue(
          type: IssueType.critical,
          language: language,
          key: '',
          message: 'Failed to load language file',
        ));
        return issues;
      }

      // 检查必需的元数据
      if (!content.containsKey('@@locale')) {
        issues.add(TranslationIssue(
          type: IssueType.warning,
          language: language,
          key: '@@locale',
          message: 'Missing @@locale metadata',
        ));
      }

      // 检查带占位符的键是否有对应的元数据
      for (final entry in (content).entries) {
        if (entry.key.startsWith('@') || entry.key.startsWith('@@')) {
          continue;
        }

        final value = entry.value?.toString() ?? '';
        final placeholders = _extractPlaceholders(value);

        if (placeholders.isNotEmpty) {
          final metaKey = '@${entry.key}';
          if (!content.containsKey(metaKey)) {
            issues.add(TranslationIssue(
              type: IssueType.warning,
              language: language,
              key: entry.key,
              message: 'Key with placeholders missing metadata: ${entry.key}',
            ));
          } else {
            // 检查元数据中的占位符定义
            final meta = content[metaKey] as Map<String, dynamic>?;
            final definedPlaceholders = (meta?['placeholders'] as Map<String, dynamic>?)?.keys.toSet() ?? {};

            for (final placeholder in placeholders) {
              if (!definedPlaceholders.contains(placeholder)) {
                issues.add(TranslationIssue(
                  type: IssueType.warning,
                  language: language,
                  key: entry.key,
                  message: 'Undefined placeholder: {$placeholder} in key: ${entry.key}',
                ));
              }
            }
          }
        }
      }
    } catch (e) {
      issues.add(TranslationIssue(
        type: IssueType.critical,
        language: language,
        key: '',
        message: 'Error validating ARB format: $e',
      ));
    }

    return issues;
  }

  /// 加载 ARB 文件（开发模式下使用）
  Future<Map<String, dynamic>?> _loadArbFile(String lang) async {
    try {
      final path = _getArbPath(lang);
      final content = await rootBundle.loadString(path);
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      // 在生产环境中，ARB 文件已编译，无法直接访问
      // 此服务主要用于开发阶段
      return null;
    }
  }

  /// 提取翻译键（排除元数据）
  Set<String> _extractKeys(Map<String, dynamic>? content) {
    if (content == null) return {};
    return content.keys
        .where((key) => !key.startsWith('@'))
        .toSet();
  }

  /// 提取占位符
  Set<String> _extractPlaceholders(String text) {
    final regex = RegExp(r'\{(\w+)\}');
    return regex.allMatches(text).map((m) => m.group(1)!).toSet();
  }

  /// 比较两个 Set 是否相等
  bool _setEquals<T>(Set<T> a, Set<T> b) {
    if (a.length != b.length) return false;
    return a.every((e) => b.contains(e));
  }

  /// 计算整体分数
  double _calculateOverallScore(Map<String, TranslationStats> stats) {
    if (stats.isEmpty) return 0;

    double totalScore = 0;
    for (final stat in stats.values) {
      if (stat.totalKeys > 0) {
        final completeness = stat.translatedKeys / stat.totalKeys;
        final qualityPenalty = (stat.emptyValues + stat.placeholderMismatches) / stat.totalKeys;
        totalScore += (completeness - qualityPenalty).clamp(0, 1);
      }
    }

    return (totalScore / stats.length * 100).clamp(0, 100);
  }

  /// 生成翻译报告（用于开发调试）
  String generateReport(TranslationQualityReport report) {
    final buffer = StringBuffer();

    buffer.writeln('=== Translation Quality Report ===\n');
    buffer.writeln('Overall Score: ${report.overallScore.toStringAsFixed(1)}%\n');

    buffer.writeln('Language Statistics:');
    for (final entry in report.stats.entries) {
      final stats = entry.value;
      final completeness = stats.totalKeys > 0
          ? (stats.translatedKeys / stats.totalKeys * 100).toStringAsFixed(1)
          : '0.0';
      buffer.writeln('  ${entry.key}:');
      buffer.writeln('    - Completeness: $completeness%');
      buffer.writeln('    - Translated: ${stats.translatedKeys}/${stats.totalKeys}');
      buffer.writeln('    - Missing: ${stats.missingKeys}');
      buffer.writeln('    - Empty values: ${stats.emptyValues}');
      buffer.writeln('    - Placeholder mismatches: ${stats.placeholderMismatches}');
    }

    if (report.issues.isNotEmpty) {
      buffer.writeln('\nIssues (${report.issues.length} total):');

      final criticalIssues = report.issues.where((i) => i.type == IssueType.critical).toList();
      final missingIssues = report.issues.where((i) => i.type == IssueType.missing).toList();
      final warningIssues = report.issues.where((i) => i.type == IssueType.warning).toList();

      if (criticalIssues.isNotEmpty) {
        buffer.writeln('\n  Critical (${criticalIssues.length}):');
        for (final issue in criticalIssues.take(10)) {
          buffer.writeln('    - [${issue.language}] ${issue.message}');
        }
        if (criticalIssues.length > 10) {
          buffer.writeln('    ... and ${criticalIssues.length - 10} more');
        }
      }

      if (missingIssues.isNotEmpty) {
        buffer.writeln('\n  Missing Translations (${missingIssues.length}):');
        final byLanguage = <String, List<TranslationIssue>>{};
        for (final issue in missingIssues) {
          byLanguage.putIfAbsent(issue.language, () => []).add(issue);
        }
        for (final entry in byLanguage.entries) {
          buffer.writeln('    ${entry.key}: ${entry.value.length} keys missing');
        }
      }

      if (warningIssues.isNotEmpty) {
        buffer.writeln('\n  Warnings (${warningIssues.length}):');
        for (final issue in warningIssues.take(10)) {
          buffer.writeln('    - [${issue.language}] ${issue.message}');
        }
        if (warningIssues.length > 10) {
          buffer.writeln('    ... and ${warningIssues.length - 10} more');
        }
      }
    }

    return buffer.toString();
  }
}

/// 翻译质量报告
class TranslationQualityReport {
  final List<TranslationIssue> issues;
  final Map<String, TranslationStats> stats;
  final double overallScore;

  const TranslationQualityReport({
    required this.issues,
    required this.stats,
    required this.overallScore,
  });

  /// 是否通过质量检查
  bool get passed => overallScore >= 90 && !hasBlockingIssues;

  /// 是否有阻塞性问题
  bool get hasBlockingIssues =>
      issues.any((i) => i.type == IssueType.critical);

  /// 获取特定类型的问题
  List<TranslationIssue> getIssuesByType(IssueType type) =>
      issues.where((i) => i.type == type).toList();

  /// 获取特定语言的问题
  List<TranslationIssue> getIssuesByLanguage(String language) =>
      issues.where((i) => i.language == language).toList();
}

/// 翻译问题
class TranslationIssue {
  final IssueType type;
  final String language;
  final String key;
  final String message;

  const TranslationIssue({
    required this.type,
    required this.language,
    required this.key,
    required this.message,
  });

  @override
  String toString() => '[$type] $language:$key - $message';
}

/// 翻译统计
class TranslationStats {
  final int totalKeys;
  final int translatedKeys;
  final int missingKeys;
  final int emptyValues;
  final int placeholderMismatches;

  const TranslationStats({
    required this.totalKeys,
    required this.translatedKeys,
    required this.missingKeys,
    required this.emptyValues,
    required this.placeholderMismatches,
  });

  /// 完成百分比
  double get completionPercentage =>
      totalKeys > 0 ? translatedKeys / totalKeys * 100 : 0;
}

/// 问题类型
enum IssueType {
  critical,           // 严重问题
  missing,            // 缺失翻译
  empty,              // 空值
  placeholderMismatch,// 占位符不匹配
  extra,              // 多余的翻译
  warning,            // 警告
}
