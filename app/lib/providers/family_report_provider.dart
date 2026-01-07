import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/family_report.dart';
import '../models/member.dart';
import '../services/family_report_service.dart';

/// FamilyReportService Provider
final familyReportServiceProvider = Provider<FamilyReportService>((ref) {
  return FamilyReportService();
});

/// 报表状态
class FamilyReportState {
  final FamilyFinancialReport? report;
  final bool isLoading;
  final String? error;

  const FamilyReportState({
    this.report,
    this.isLoading = false,
    this.error,
  });

  FamilyReportState copyWith({
    FamilyFinancialReport? report,
    bool? isLoading,
    String? error,
  }) {
    return FamilyReportState(
      report: report ?? this.report,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 报表 Notifier
class FamilyReportNotifier extends Notifier<FamilyReportState> {
  @override
  FamilyReportState build() {
    return const FamilyReportState();
  }

  FamilyReportService get _reportService =>
      ref.read(familyReportServiceProvider);

  /// 生成报表
  Future<void> generateReport({
    required String ledgerId,
    required ReportPeriodType periodType,
    required DateTime startDate,
    required DateTime endDate,
    required List<LedgerMember> members,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final report = await _reportService.generateReport(
        ledgerId: ledgerId,
        periodType: periodType,
        startDate: startDate,
        endDate: endDate,
        members: members,
      );
      state = state.copyWith(report: report, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 生成月度报表
  Future<void> generateMonthlyReport({
    required String ledgerId,
    required int year,
    required int month,
    required List<LedgerMember> members,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final report = await _reportService.generateMonthlyReport(
        ledgerId: ledgerId,
        year: year,
        month: month,
        members: members,
      );
      state = state.copyWith(report: report, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 生成周报
  Future<void> generateWeeklyReport({
    required String ledgerId,
    required DateTime weekStart,
    required List<LedgerMember> members,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final report = await _reportService.generateWeeklyReport(
        ledgerId: ledgerId,
        weekStart: weekStart,
        members: members,
      );
      state = state.copyWith(report: report, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 生成年度报表
  Future<void> generateYearlyReport({
    required String ledgerId,
    required int year,
    required List<LedgerMember> members,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final report = await _reportService.generateYearlyReport(
        ledgerId: ledgerId,
        year: year,
        members: members,
      );
      state = state.copyWith(report: report, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 清除报表
  void clearReport() {
    state = const FamilyReportState();
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// 报表 Provider
final familyReportProvider =
    NotifierProvider<FamilyReportNotifier, FamilyReportState>(
        FamilyReportNotifier.new);

/// 报表参数
class ReportParams {
  final String ledgerId;
  final ReportPeriodType periodType;
  final DateTime startDate;
  final DateTime endDate;
  final List<LedgerMember> members;

  const ReportParams({
    required this.ledgerId,
    required this.periodType,
    required this.startDate,
    required this.endDate,
    required this.members,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReportParams &&
        other.ledgerId == ledgerId &&
        other.periodType == periodType &&
        other.startDate == startDate &&
        other.endDate == endDate;
  }

  @override
  int get hashCode =>
      ledgerId.hashCode ^
      periodType.hashCode ^
      startDate.hashCode ^
      endDate.hashCode;
}

/// 按需生成报表 Provider
final generateReportProvider =
    FutureProvider.family<FamilyFinancialReport, ReportParams>(
        (ref, params) async {
  final reportService = ref.watch(familyReportServiceProvider);
  return reportService.generateReport(
    ledgerId: params.ledgerId,
    periodType: params.periodType,
    startDate: params.startDate,
    endDate: params.endDate,
    members: params.members,
  );
});

/// 月度报表参数
class MonthlyReportParams {
  final String ledgerId;
  final int year;
  final int month;
  final List<LedgerMember> members;

  const MonthlyReportParams({
    required this.ledgerId,
    required this.year,
    required this.month,
    required this.members,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MonthlyReportParams &&
        other.ledgerId == ledgerId &&
        other.year == year &&
        other.month == month;
  }

  @override
  int get hashCode => ledgerId.hashCode ^ year.hashCode ^ month.hashCode;
}

/// 月度报表 Provider
final monthlyReportProvider =
    FutureProvider.family<FamilyFinancialReport, MonthlyReportParams>(
        (ref, params) async {
  final reportService = ref.watch(familyReportServiceProvider);
  return reportService.generateMonthlyReport(
    ledgerId: params.ledgerId,
    year: params.year,
    month: params.month,
    members: params.members,
  );
});

/// 收支汇总 Provider（从报表中提取）
final reportSummaryProvider = Provider<IncomeExpenseSummary?>((ref) {
  return ref.watch(familyReportProvider).report?.summary;
});

/// 分类分析 Provider（从报表中提取）
final reportCategoryAnalysisProvider = Provider<List<CategoryAnalysis>>((ref) {
  return ref.watch(familyReportProvider).report?.categoryAnalysis ?? [];
});

/// 成员分析 Provider（从报表中提取）
final reportMemberAnalysisProvider = Provider<List<MemberAnalysis>>((ref) {
  return ref.watch(familyReportProvider).report?.memberAnalysis ?? [];
});

/// 趋势分析 Provider（从报表中提取）
final reportTrendAnalysisProvider = Provider<TrendAnalysis?>((ref) {
  return ref.watch(familyReportProvider).report?.trendAnalysis;
});

/// 洞察建议 Provider（从报表中提取）
final reportInsightsProvider = Provider<List<FinancialInsight>>((ref) {
  return ref.watch(familyReportProvider).report?.insights ?? [];
});
