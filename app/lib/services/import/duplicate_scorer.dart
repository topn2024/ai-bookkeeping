import '../../models/import_candidate.dart';
import '../../models/transaction.dart';
import '../../models/category.dart';
import '../../core/di/service_locator.dart';
import '../../core/contracts/i_database_service.dart';

/// Service to calculate duplicate scores between import candidates and existing transactions
class DuplicateScorer {
  final IDatabaseService _databaseService;

  DuplicateScorer({
    IDatabaseService? databaseService,
  })  : _databaseService = databaseService ?? sl<IDatabaseService>();

  /// Check all candidates for duplicates
  Future<void> checkDuplicates(
    List<ImportCandidate> candidates, {
    ExternalSource? externalSource,
    void Function(int current, int total)? onProgress,
  }) async {
    for (int i = 0; i < candidates.length; i++) {
      final candidate = candidates[i];

      // Check for exact match first (by external ID)
      if (candidate.externalId != null && externalSource != null) {
        final existing = await _databaseService.findTransactionByExternalId(
          candidate.externalId!,
          externalSource,
        );

        if (existing != null) {
          candidate.duplicateResult = DuplicateCheckResult.exactMatch(existing);
          candidate.applyDefaultAction();
          onProgress?.call(i + 1, candidates.length);
          continue;
        }
      }

      // Find potential duplicates by feature matching
      final potentialDuplicates = await _databaseService.findPotentialDuplicates(
        date: candidate.date,
        amount: candidate.amount,
        type: candidate.type,
        dayRange: 1,
      );

      if (potentialDuplicates.isEmpty) {
        candidate.duplicateResult = DuplicateCheckResult.noDuplicate();
        candidate.applyDefaultAction();
        onProgress?.call(i + 1, candidates.length);
        continue;
      }

      // Calculate score for each potential duplicate
      DuplicateCheckResult? bestResult;
      for (final existing in potentialDuplicates) {
        final result = _calculateScore(candidate, existing);
        if (bestResult == null || result.score > bestResult.score) {
          bestResult = result;
        }
      }

      candidate.duplicateResult = bestResult ?? DuplicateCheckResult.noDuplicate();
      candidate.applyDefaultAction();
      onProgress?.call(i + 1, candidates.length);
    }
  }

  /// Calculate duplicate score between a candidate and an existing transaction
  DuplicateCheckResult _calculateScore(
    ImportCandidate candidate,
    Transaction existing,
  ) {
    int score = 0;
    final reasons = <String>[];
    final scoreBreakdown = <String, int>{};

    // 1. Date is within 1 day (required - already filtered)
    // Amount matches (required - already filtered)
    score += 30;
    reasons.add('金额相同');
    scoreBreakdown['金额匹配'] = 30;

    // 2. Type matches (10 points)
    if (candidate.type == existing.type) {
      score += 10;
      reasons.add('类型相同');
      scoreBreakdown['类型匹配'] = 10;
    }

    // 3. Category matches (15 points for exact, 8 for same parent)
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

    // 4. Time proximity (20 points)
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

    // 5. Semantic similarity (20 points)
    final semanticScore = _calculateSemanticSimilarity(
      candidate.note ?? '',
      existing.note ?? '',
      candidate.rawMerchant,
      existing.rawMerchant,
    );
    final semanticPoints = (semanticScore * 20).round();
    score += semanticPoints;
    if (semanticScore > 0.7) {
      reasons.add('备注语义高度相似');
    } else if (semanticScore > 0.4) {
      reasons.add('备注语义相似');
    }
    scoreBreakdown['语义相似度'] = semanticPoints;

    // 6. Account matches (5 points)
    if (candidate.accountId != null && candidate.accountId == existing.accountId) {
      score += 5;
      reasons.add('账户相同');
      scoreBreakdown['账户匹配'] = 5;
    }

    return DuplicateCheckResult(
      score: score,
      level: _getLevel(score),
      reason: reasons.join('、'),
      matchedTransaction: existing,
      scoreBreakdown: scoreBreakdown,
    );
  }

  /// Calculate category match score
  int _calculateCategoryScore(String? candidateCategory, String existingCategory) {
    if (candidateCategory == null) return 0;

    // Exact match
    if (candidateCategory == existingCategory) {
      return 15;
    }

    // Check if same parent category
    final candidateParent = _getParentCategory(candidateCategory);
    final existingParent = _getParentCategory(existingCategory);

    if (candidateParent != null &&
        existingParent != null &&
        candidateParent == existingParent) {
      return 8;
    }

    // Check if one is parent of the other
    if (candidateCategory == existingParent || candidateParent == existingCategory) {
      return 8;
    }

    return 0;
  }

  /// Get parent category ID
  String? _getParentCategory(String categoryId) {
    // Use the DefaultCategories to find parent
    final category = DefaultCategories.findById(categoryId);
    if (category != null) {
      return category.parentId ?? categoryId;
    }

    // Fallback: parse from ID format (e.g., food_lunch -> food)
    if (categoryId.contains('_')) {
      return categoryId.split('_').first;
    }

    return null;
  }

  /// Calculate semantic similarity between two texts
  double _calculateSemanticSimilarity(
    String note1,
    String note2,
    String? merchant1,
    String? merchant2,
  ) {
    // Combine text for comparison
    final text1 = [note1, merchant1].where((s) => s != null && s.isNotEmpty).join(' ');
    final text2 = [note2, merchant2].where((s) => s != null && s.isNotEmpty).join(' ');

    if (text1.isEmpty && text2.isEmpty) return 0.5;
    if (text1.isEmpty || text2.isEmpty) return 0.0;

    // Use local similarity calculation (fast and reliable for deduplication)
    return _calculateLocalSimilarity(text1, text2);
  }

  /// Calculate similarity locally (Jaccard similarity)
  double _calculateLocalSimilarity(String text1, String text2) {
    final words1 = _tokenize(text1);
    final words2 = _tokenize(text2);

    if (words1.isEmpty || words2.isEmpty) return 0.0;

    // Check for exact match
    if (text1.toLowerCase() == text2.toLowerCase()) return 1.0;

    // Jaccard similarity
    final intersection = words1.intersection(words2);
    final union = words1.union(words2);

    if (union.isEmpty) return 0.0;

    double jaccardScore = intersection.length / union.length;

    // Boost score if merchant names match
    final merchant1 = _extractMerchant(text1);
    final merchant2 = _extractMerchant(text2);
    if (merchant1 != null && merchant2 != null && merchant1 == merchant2) {
      jaccardScore = (jaccardScore + 0.5).clamp(0.0, 1.0);
    }

    return jaccardScore;
  }

  /// Tokenize text into words
  Set<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\u4e00-\u9fff]+'), ' ')
        .split(' ')
        .where((w) => w.isNotEmpty && w.length > 1)
        .toSet();
  }

  /// Extract merchant name from text
  String? _extractMerchant(String text) {
    // Common merchant patterns
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

  /// Get duplicate level from score
  DuplicateLevel _getLevel(int score) {
    if (score >= 85) return DuplicateLevel.high;
    if (score >= 60) return DuplicateLevel.medium;
    if (score >= 40) return DuplicateLevel.low;
    return DuplicateLevel.none;
  }
}
