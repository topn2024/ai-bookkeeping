import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/app_upgrade_service.dart';

/// 更新检查状态
class UpgradeState {
  final bool isChecking;
  final UpdateCheckResult? result;
  final String? error;

  const UpgradeState({
    this.isChecking = false,
    this.result,
    this.error,
  });

  UpgradeState copyWith({
    bool? isChecking,
    UpdateCheckResult? result,
    String? error,
  }) {
    return UpgradeState(
      isChecking: isChecking ?? this.isChecking,
      result: result ?? this.result,
      error: error,
    );
  }

  /// 是否有更新
  bool get hasUpdate => result?.hasUpdate ?? false;

  /// 是否强制更新
  bool get isForceUpdate => result?.isForceUpdate ?? false;

  /// 最新版本信息
  VersionInfo? get latestVersion => result?.latestVersion;
}

/// 更新检查 Provider
class UpgradeNotifier extends StateNotifier<UpgradeState> {
  UpgradeNotifier() : super(const UpgradeState());

  final _service = AppUpgradeService();

  /// 检查更新
  Future<UpdateCheckResult?> checkUpdate({bool force = false}) async {
    state = state.copyWith(isChecking: true, error: null);

    try {
      final result = await _service.checkUpdate(force: force);
      state = state.copyWith(isChecking: false, result: result);
      return result;
    } catch (e) {
      state = state.copyWith(isChecking: false, error: e.toString());
      return null;
    }
  }

  /// 清除更新提示（用户选择稍后更新后）
  void dismissUpdate() {
    if (state.result != null && !state.result!.isForceUpdate) {
      state = state.copyWith(
        result: UpdateCheckResult(
          hasUpdate: false,
          isForceUpdate: false,
          currentVersion: state.result!.currentVersion,
        ),
      );
    }
  }

  /// 清除缓存
  void clearCache() {
    _service.clearCache();
    state = const UpgradeState();
  }
}

/// 更新状态 Provider
final upgradeProvider =
    StateNotifierProvider<UpgradeNotifier, UpgradeState>((ref) {
  return UpgradeNotifier();
});
