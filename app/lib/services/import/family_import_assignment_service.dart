import '../../models/import_candidate.dart';
import '../database_service.dart';

/// Simple Member class for family import assignment
class Member {
  final String id;
  final String name;
  final String ledgerId;

  Member({required this.id, required this.name, required this.ledgerId});

  factory Member.fromMap(Map<String, dynamic> map) {
    return Member(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      ledgerId: map['ledgerId'] as String? ?? '',
    );
  }
}

/// Service for assigning imported transactions to family members (第11章家庭成员导入分配)
class FamilyImportAssignmentService {
  final DatabaseService _databaseService;

  FamilyImportAssignmentService({
    DatabaseService? databaseService,
  }) : _databaseService = databaseService ?? DatabaseService();

  /// Get family members for assignment
  Future<List<Member>> getFamilyMembers(String ledgerId) async {
    final maps = await _databaseService.getMembersByLedgerId(ledgerId);
    return maps.map((m) => Member.fromMap(m)).toList();
  }

  /// Assign candidate to family member
  void assignToMember(ImportCandidate candidate, String memberId) {
    candidate.assignedMemberId = memberId;
  }

  /// Batch assign candidates to member
  void batchAssignToMember(List<ImportCandidate> candidates, String memberId) {
    for (final candidate in candidates) {
      candidate.assignedMemberId = memberId;
    }
  }

  /// Auto-assign based on patterns (smart assignment)
  Future<void> autoAssignByPattern(
    List<ImportCandidate> candidates,
    String ledgerId,
  ) async {
    final members = await getFamilyMembers(ledgerId);
    if (members.isEmpty) return;

    // Get historical patterns for each member
    final memberPatterns = <String, MemberSpendingPattern>{};
    for (final member in members) {
      final pattern = await _getMemberSpendingPattern(member.id, ledgerId);
      memberPatterns[member.id] = pattern;
    }

    // Assign based on patterns
    for (final candidate in candidates) {
      final bestMember = _findBestMatchingMember(candidate, memberPatterns);
      if (bestMember != null) {
        candidate.assignedMemberId = bestMember;
        candidate.assignmentConfidence = memberPatterns[bestMember]!.confidence;
      }
    }
  }

  /// Get spending pattern for a member
  Future<MemberSpendingPattern> _getMemberSpendingPattern(
    String memberId,
    String ledgerId,
  ) async {
    try {
      var transactions = await _databaseService.getTransactionsByMember(
        memberId,
      );
      // Limit to 100 records locally
      if (transactions.length > 100) {
        transactions = transactions.take(100).toList();
      }

      final categoryFrequency = <String, int>{};
      final merchantFrequency = <String, int>{};
      final amountRanges = <AmountRange>[];

      for (final tx in transactions) {
        // Count category frequency
        categoryFrequency[tx.category] = (categoryFrequency[tx.category] ?? 0) + 1;

        // Count merchant frequency
        if (tx.rawMerchant != null) {
          merchantFrequency[tx.rawMerchant!] =
              (merchantFrequency[tx.rawMerchant!] ?? 0) + 1;
        }

        // Track amount ranges
        amountRanges.add(AmountRange(
          min: tx.amount * 0.8,
          max: tx.amount * 1.2,
          category: tx.category,
        ));
      }

      return MemberSpendingPattern(
        memberId: memberId,
        categoryFrequency: categoryFrequency,
        merchantFrequency: merchantFrequency,
        amountRanges: amountRanges,
        confidence: transactions.length > 20 ? 0.8 : 0.5,
      );
    } catch (e) {
      return MemberSpendingPattern(
        memberId: memberId,
        categoryFrequency: {},
        merchantFrequency: {},
        amountRanges: [],
        confidence: 0.0,
      );
    }
  }

  /// Find best matching member for a candidate
  String? _findBestMatchingMember(
    ImportCandidate candidate,
    Map<String, MemberSpendingPattern> patterns,
  ) {
    String? bestMember;
    double bestScore = 0.0;

    for (final entry in patterns.entries) {
      final score = _calculateMatchScore(candidate, entry.value);
      if (score > bestScore && score > 0.3) {
        bestScore = score;
        bestMember = entry.key;
      }
    }

    return bestMember;
  }

  /// Calculate match score between candidate and pattern
  double _calculateMatchScore(
    ImportCandidate candidate,
    MemberSpendingPattern pattern,
  ) {
    double score = 0.0;
    int factors = 0;

    // Category match
    if (candidate.category != null) {
      final categoryCount = pattern.categoryFrequency[candidate.category] ?? 0;
      final totalCategories = pattern.categoryFrequency.values.fold(0, (a, b) => a + b);
      if (totalCategories > 0) {
        score += (categoryCount / totalCategories) * 0.4;
        factors++;
      }
    }

    // Merchant match
    if (candidate.rawMerchant != null) {
      final merchantCount = pattern.merchantFrequency[candidate.rawMerchant] ?? 0;
      if (merchantCount > 0) {
        score += 0.4;
        factors++;
      }
    }

    // Amount range match
    final inRange = pattern.amountRanges.any((r) =>
        candidate.amount >= r.min &&
        candidate.amount <= r.max &&
        (candidate.category == null || candidate.category == r.category));
    if (inRange) {
      score += 0.2;
      factors++;
    }

    return factors > 0 ? score * pattern.confidence : 0.0;
  }
}

/// Member spending pattern for auto-assignment
class MemberSpendingPattern {
  final String memberId;
  final Map<String, int> categoryFrequency;
  final Map<String, int> merchantFrequency;
  final List<AmountRange> amountRanges;
  final double confidence;

  MemberSpendingPattern({
    required this.memberId,
    required this.categoryFrequency,
    required this.merchantFrequency,
    required this.amountRanges,
    required this.confidence,
  });
}

/// Amount range for pattern matching
class AmountRange {
  final double min;
  final double max;
  final String category;

  AmountRange({
    required this.min,
    required this.max,
    required this.category,
  });
}

/// Extension to add family assignment fields to ImportCandidate
extension FamilyImportCandidateExtension on ImportCandidate {
  static final _assignedMemberIds = <int, String?>{};
  static final _assignmentConfidences = <int, double>{};

  String? get assignedMemberId => _assignedMemberIds[hashCode];
  set assignedMemberId(String? value) => _assignedMemberIds[hashCode] = value;

  double get assignmentConfidence => _assignmentConfidences[hashCode] ?? 0.0;
  set assignmentConfidence(double value) => _assignmentConfidences[hashCode] = value;
}
