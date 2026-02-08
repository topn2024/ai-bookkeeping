import 'dart:async';

import '../../models/import_candidate.dart';
import '../../models/transaction.dart';
import '../../models/category.dart';
import '../../core/di/service_locator.dart';
import '../../core/contracts/i_database_service.dart';
import '../ai_service.dart';
import '../location_service.dart';

/// Enhanced duplicate scorer with three-layer deduplication (第11.3节)
/// Layer 1: Exact match (external ID)
/// Layer 2: Feature match (amount + date + description similarity)
/// Layer 3: Semantic match (AI judgment + location + family cross-validation)
class EnhancedDuplicateScorer {
  final IDatabaseService _databaseService;
  final AIService? _aiService;
  final LocationService? _locationService;

  EnhancedDuplicateScorer({
    IDatabaseService? databaseService,
    AIService? aiService,
    LocationService? locationService,
  })  : _databaseService = databaseService ?? sl<IDatabaseService>(),
        _aiService = aiService,
        _locationService = locationService;

  /// Check all candidates for duplicates with three-layer mechanism
  Future<void> checkDuplicates(
    List<ImportCandidate> candidates, {
    ExternalSource? externalSource,
    String? familyLedgerId,
    void Function(int current, int total, DuplicateCheckStage stage)? onProgress,
  }) async {
    for (int i = 0; i < candidates.length; i++) {
      final candidate = candidates[i];

      // Layer 1: Exact match by external ID (100% confidence)
      onProgress?.call(i + 1, candidates.length, DuplicateCheckStage.exactMatch);
      if (candidate.externalId != null && externalSource != null) {
        final existing = await _databaseService.findTransactionByExternalId(
          candidate.externalId!,
          externalSource,
        );

        if (existing != null) {
          candidate.duplicateResult = DuplicateCheckResult(
            score: 100,
            level: DuplicateLevel.exact,
            reason: '交易单号完全匹配',
            matchedTransaction: existing,
            scoreBreakdown: {'精确匹配': 100},
          );
          candidate.applyDefaultAction();
          continue;
        }
      }

      // Layer 2: Feature match (70-95% confidence)
      onProgress?.call(i + 1, candidates.length, DuplicateCheckStage.featureMatch);
      final potentialDuplicates = await _databaseService.findPotentialDuplicates(
        date: candidate.date,
        amount: candidate.amount,
        type: candidate.type,
        dayRange: 1,
      );

      if (potentialDuplicates.isEmpty) {
        candidate.duplicateResult = DuplicateCheckResult.noDuplicate();
        candidate.applyDefaultAction();
        continue;
      }

      // Calculate feature score for each potential duplicate
      DuplicateCheckResult? bestResult;
      for (final existing in potentialDuplicates) {
        final result = await _calculateEnhancedScore(
          candidate,
          existing,
          familyLedgerId: familyLedgerId,
          onProgress: (stage) => onProgress?.call(i + 1, candidates.length, stage),
        );
        if (bestResult == null || result.score > bestResult.score) {
          bestResult = result;
        }
      }

      candidate.duplicateResult = bestResult ?? DuplicateCheckResult.noDuplicate();
      candidate.applyDefaultAction();
    }
  }

  /// Calculate enhanced duplicate score with three-layer analysis
  Future<DuplicateCheckResult> _calculateEnhancedScore(
    ImportCandidate candidate,
    Transaction existing, {
    String? familyLedgerId,
    void Function(DuplicateCheckStage stage)? onProgress,
  }) async {
    int score = 0;
    final reasons = <String>[];
    final scoreBreakdown = <String, int>{};

    // Layer 2: Feature matching
    // 2.1 Amount match (already filtered, base 30 points)
    score += 30;
    reasons.add('金额相同');
    scoreBreakdown['金额匹配'] = 30;

    // 2.2 Type match (10 points)
    if (candidate.type == existing.type) {
      score += 10;
      reasons.add('类型相同');
      scoreBreakdown['类型匹配'] = 10;
    }

    // 2.3 Category match (15 points for exact, 8 for same parent)
    final categoryScore = _calculateCategoryScore(candidate.category, existing.category);
    if (categoryScore > 0) {
      score += categoryScore;
      if (categoryScore == 15) {
        reasons.add('分类相同');
      } else {
        reasons.add('同属一级分类');
      }
      scoreBreakdown['分类匹配'] = categoryScore;
    }

    // 2.4 Time proximity (20 points max)
    final minutesDiff = candidate.date.difference(existing.date).inMinutes.abs();
    int timeScore = 0;
    if (minutesDiff <= 5) {
      timeScore = 20;
      reasons.add('时间高度接近(≤5分钟)');
    } else if (minutesDiff <= 30) {
      timeScore = 15;
      reasons.add('时间接近(≤30分钟)');
    } else if (minutesDiff <= 120) {
      timeScore = 8;
      reasons.add('时间较近(≤2小时)');
    }
    score += timeScore;
    scoreBreakdown['时间接近度'] = timeScore;

    // 2.5 Local semantic similarity (20 points max)
    final localSemanticScore = _calculateLocalSemanticSimilarity(
      candidate.note ?? '',
      existing.note ?? '',
      candidate.rawMerchant,
      existing.rawMerchant,
    );
    final localSemanticPoints = (localSemanticScore * 20).round();
    score += localSemanticPoints;
    if (localSemanticScore > 0.7) {
      reasons.add('备注语义高度相似');
    } else if (localSemanticScore > 0.4) {
      reasons.add('备注语义相似');
    }
    scoreBreakdown['本地语义相似度'] = localSemanticPoints;

    // Layer 3: Enhanced semantic matching (AI + location + family)
    onProgress?.call(DuplicateCheckStage.semanticMatch);

    // 3.1 AI semantic judgment (bonus 10 points)
    if (_aiService != null && score >= 50 && score < 85) {
      try {
        final aiScore = await _getAISemanticScore(candidate, existing);
        if (aiScore > 0) {
          score += aiScore;
          reasons.add('AI语义分析确认相似');
          scoreBreakdown['AI语义分析'] = aiScore;
        }
      } catch (e) {
        // AI service unavailable, continue without it
      }
    }

    // 3.2 Location proximity check (bonus 5 points)
    if (_locationService != null && existing.locationInfo != null) {
      final locationScore = await _calculateLocationScore(candidate, existing);
      if (locationScore > 0) {
        score += locationScore;
        reasons.add('同位置消费');
        scoreBreakdown['位置匹配'] = locationScore;
      }
    }

    // 3.3 Family cross-validation (bonus 5 points)
    if (familyLedgerId != null) {
      final familyScore = await _calculateFamilyCrossValidation(
        candidate,
        existing,
        familyLedgerId,
      );
      if (familyScore > 0) {
        score += familyScore;
        reasons.add('家庭成员重复消费检测');
        scoreBreakdown['家庭交叉验证'] = familyScore;
      }
    }

    // 2.6 Account match (5 points)
    if (candidate.accountId != null && candidate.accountId == existing.accountId) {
      score += 5;
      reasons.add('账户相同');
      scoreBreakdown['账户匹配'] = 5;
    }

    // Determine match layer
    // ignore: unused_local_variable
    DuplicateMatchLayer matchLayer;
    if (score >= 85) {
      matchLayer = DuplicateMatchLayer.feature;
    } else if (score >= 60) {
      matchLayer = DuplicateMatchLayer.semantic;
    } else {
      matchLayer = DuplicateMatchLayer.none;
    }

    return DuplicateCheckResult(
      score: score.clamp(0, 100),
      level: _getLevel(score),
      reason: reasons.join('、'),
      matchedTransaction: existing,
      scoreBreakdown: scoreBreakdown,
    );
  }

  /// Calculate category match score
  int _calculateCategoryScore(String? candidateCategory, String existingCategory) {
    if (candidateCategory == null) return 0;

    if (candidateCategory == existingCategory) {
      return 15;
    }

    final candidateParent = _getParentCategory(candidateCategory);
    final existingParent = _getParentCategory(existingCategory);

    if (candidateParent != null &&
        existingParent != null &&
        candidateParent == existingParent) {
      return 8;
    }

    if (candidateCategory == existingParent || candidateParent == existingCategory) {
      return 8;
    }

    return 0;
  }

  String? _getParentCategory(String categoryId) {
    final category = DefaultCategories.findById(categoryId);
    if (category != null) {
      return category.parentId ?? categoryId;
    }

    if (categoryId.contains('_')) {
      return categoryId.split('_').first;
    }

    return null;
  }

  /// Calculate local semantic similarity using Jaccard
  double _calculateLocalSemanticSimilarity(
    String note1,
    String note2,
    String? merchant1,
    String? merchant2,
  ) {
    final text1 = [note1, merchant1].where((s) => s != null && s.isNotEmpty).join(' ');
    final text2 = [note2, merchant2].where((s) => s != null && s.isNotEmpty).join(' ');

    if (text1.isEmpty && text2.isEmpty) return 0.5;
    if (text1.isEmpty || text2.isEmpty) return 0.0;

    if (text1.toLowerCase() == text2.toLowerCase()) return 1.0;

    final words1 = _tokenize(text1);
    final words2 = _tokenize(text2);

    if (words1.isEmpty || words2.isEmpty) return 0.0;

    final intersection = words1.intersection(words2);
    final union = words1.union(words2);

    if (union.isEmpty) return 0.0;

    double jaccardScore = intersection.length / union.length;

    // Boost for merchant match
    final m1 = _extractMerchant(text1);
    final m2 = _extractMerchant(text2);
    if (m1 != null && m2 != null && m1 == m2) {
      jaccardScore = (jaccardScore + 0.5).clamp(0.0, 1.0);
    }

    return jaccardScore;
  }

  Set<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\u4e00-\u9fff]+'), ' ')
        .split(' ')
        .where((w) => w.isNotEmpty && w.length > 1)
        .toSet();
  }

  String? _extractMerchant(String text) {
    final patterns = [
      RegExp(r'(星巴克|瑞幸|麦当劳|肯德基|美团|饿了么|滴滴|淘宝|京东|拼多多)'),
      RegExp(r'^(\S{2,6})(店|超市|便利店|餐厅|咖啡|外卖)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return match.group(1);
      }
    }

    return null;
  }

  /// Get AI semantic score (Layer 3.1)
  Future<int> _getAISemanticScore(
    ImportCandidate candidate,
    Transaction existing,
  ) async {
    if (_aiService == null) return 0;

    try {
      final prompt = '''
判断以下两笔交易是否为同一笔交易的重复记录：

交易1（待导入）：
- 时间：${candidate.date}
- 金额：${candidate.amount}
- 商户：${candidate.rawMerchant ?? '未知'}
- 备注：${candidate.note ?? '无'}

交易2（已存在）：
- 时间：${existing.date}
- 金额：${existing.amount}
- 商户：${existing.rawMerchant ?? '未知'}
- 备注：${existing.note ?? '无'}

请仅回复"是"或"否"。
''';

      final response = await _aiService.chat(prompt).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('AI semantic score request timed out');
        },
      );
      if (response.toLowerCase().contains('是')) {
        return 10; // AI confirms duplicate
      }
    } catch (e) {
      // AI service error, return 0
    }

    return 0;
  }

  /// Calculate location proximity score (Layer 3.2)
  Future<int> _calculateLocationScore(
    ImportCandidate candidate,
    Transaction existing,
  ) async {
    // If existing transaction has location info and we can get current location
    if (existing.locationInfo == null || _locationService == null) return 0;

    // For imported transactions, we don't have location data
    // But we can check if there's a pattern of transactions at the same location
    // This is a simplified implementation
    return 0;
  }

  /// Calculate family cross-validation score (Layer 3.3)
  Future<int> _calculateFamilyCrossValidation(
    ImportCandidate candidate,
    Transaction existing,
    String familyLedgerId,
  ) async {
    // Check if another family member has a similar transaction
    // This helps detect cases like: husband pays for family dinner,
    // but wife also imported her payment record for the same dinner
    try {
      final familyTransactions = await _databaseService.findFamilyDuplicates(
        ledgerId: familyLedgerId,
        date: candidate.date,
        amount: candidate.amount,
      );

      if (familyTransactions.isNotEmpty) {
        return 5; // Found potential family duplicate
      }
    } catch (e) {
      // Database error, return 0
    }

    return 0;
  }

  /// Get duplicate level from score
  DuplicateLevel _getLevel(int score) {
    if (score >= 85) return DuplicateLevel.high;
    if (score >= 60) return DuplicateLevel.medium;
    if (score >= 40) return DuplicateLevel.low;
    return DuplicateLevel.none;
  }
}

/// Duplicate check stage for progress reporting
enum DuplicateCheckStage {
  exactMatch,   // Layer 1
  featureMatch, // Layer 2
  semanticMatch, // Layer 3
}

/// Duplicate match layer
enum DuplicateMatchLayer {
  exact,    // Layer 1: External ID match
  feature,  // Layer 2: Feature match
  semantic, // Layer 3: Semantic match
  none,     // No match
}

/// Extension to add matchLayer to DuplicateCheckResult
extension DuplicateCheckResultExtension on DuplicateCheckResult {
  /// Get the match layer description
  String get matchLayerDescription {
    if (level == DuplicateLevel.exact) return '第一层：精确匹配';
    if (score >= 85) return '第二层：特征匹配';
    if (score >= 60) return '第三层：语义匹配';
    return '无匹配';
  }
}
