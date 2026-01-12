import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 功能引导状态
class FeatureGuideState {
  /// 首页引导是否已显示
  final bool homeGuideShown;

  /// 是否正在加载
  final bool isLoading;

  const FeatureGuideState({
    this.homeGuideShown = false,
    this.isLoading = true,
  });

  FeatureGuideState copyWith({
    bool? homeGuideShown,
    bool? isLoading,
  }) {
    return FeatureGuideState(
      homeGuideShown: homeGuideShown ?? this.homeGuideShown,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// 功能引导状态管理
class FeatureGuideNotifier extends StateNotifier<FeatureGuideState> {
  static const String _keyHomeGuide = 'guide_shown_home_guide';

  FeatureGuideNotifier() : super(const FeatureGuideState()) {
    _loadState();
  }

  /// 加载引导状态
  Future<void> _loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final homeGuideShown = prefs.getBool(_keyHomeGuide) ?? false;

      state = FeatureGuideState(
        homeGuideShown: homeGuideShown,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('[FeatureGuideProvider] Error loading state: $e');
      state = const FeatureGuideState(isLoading: false);
    }
  }

  /// 是否应该显示首页引导
  bool shouldShowHomeGuide() {
    return !state.isLoading && !state.homeGuideShown;
  }

  /// 标记首页引导已显示
  Future<void> markHomeGuideShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyHomeGuide, true);

      state = state.copyWith(homeGuideShown: true);
    } catch (e) {
      debugPrint('[FeatureGuideProvider] Error marking guide shown: $e');
    }
  }

  /// 重置首页引导状态（用于测试）
  Future<void> resetHomeGuide() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyHomeGuide);

      state = state.copyWith(homeGuideShown: false);
      debugPrint('[FeatureGuideProvider] Home guide reset');
    } catch (e) {
      debugPrint('[FeatureGuideProvider] Error resetting guide: $e');
    }
  }
}

/// Provider
final featureGuideProvider =
    StateNotifierProvider<FeatureGuideNotifier, FeatureGuideState>(
  (ref) => FeatureGuideNotifier(),
);
