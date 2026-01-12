import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/guide_step.dart';
import '../widgets/feature_guide/guide_overlay.dart';

/// 功能引导服务
///
/// 单例模式，管理应用内的功能引导流程
class FeatureGuideService {
  static final FeatureGuideService _instance = FeatureGuideService._();
  static FeatureGuideService get instance => _instance;
  FeatureGuideService._();

  // 当前的overlay entry
  OverlayEntry? _overlayEntry;

  // 当前步骤索引
  int _currentStepIndex = 0;

  // 引导步骤列表
  List<GuideStep>? _steps;

  // 完成回调
  VoidCallback? _onComplete;

  // 跳过回调
  VoidCallback? _onSkip;

  /// 显示引导
  ///
  /// [context] 上下文
  /// [steps] 引导步骤列表
  /// [onComplete] 完成所有步骤时的回调
  /// [onSkip] 跳过引导时的回调
  Future<void> showGuide({
    required BuildContext context,
    required List<GuideStep> steps,
    VoidCallback? onComplete,
    VoidCallback? onSkip,
  }) async {
    // 检查引导是否已显示过
    if (await _hasShownGuide(steps.first.id)) {
      debugPrint('[FeatureGuide] Guide already shown: ${steps.first.id}');
      return;
    }

    // 如果已经有引导在显示，先移除
    if (_overlayEntry != null) {
      removeGuide();
    }

    // 初始化状态
    _steps = steps;
    _currentStepIndex = 0;
    _onComplete = onComplete;
    _onSkip = onSkip;

    // 延迟一小段时间，确保页面布局完成
    await Future.delayed(const Duration(milliseconds: 300));

    // 创建并插入overlay
    _showOverlay(context);
  }

  /// 显示overlay
  void _showOverlay(BuildContext context) {
    if (_steps == null || _steps!.isEmpty) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => GuideOverlay(
        step: _steps![_currentStepIndex],
        currentIndex: _currentStepIndex,
        totalSteps: _steps!.length,
        onNext: next,
        onSkip: skip,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  /// 更新overlay（切换步骤时）
  void _updateOverlay() {
    _overlayEntry?.markNeedsBuild();
  }

  /// 下一步
  void next() {
    if (_steps == null) return;

    if (_currentStepIndex < _steps!.length - 1) {
      // 还有下一步，继续
      _currentStepIndex++;
      _updateOverlay();
    } else {
      // 已经是最后一步，完成引导
      complete();
    }
  }

  /// 跳过引导
  void skip() {
    debugPrint('[FeatureGuide] Guide skipped');
    removeGuide();
    _onSkip?.call();
  }

  /// 完成引导
  void complete() async {
    if (_steps == null) return;

    debugPrint('[FeatureGuide] Guide completed: ${_steps!.first.id}');

    // 标记为已显示
    await _markAsShown(_steps!.first.id);

    // 移除overlay
    removeGuide();

    // 调用完成回调
    _onComplete?.call();
  }

  /// 移除引导overlay
  void removeGuide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _steps = null;
    _currentStepIndex = 0;
  }

  /// 检查引导是否已显示过
  Future<bool> _hasShownGuide(String guideId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('guide_shown_$guideId') ?? false;
  }

  /// 标记引导为已显示
  Future<void> _markAsShown(String guideId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('guide_shown_$guideId', true);
  }

  /// 重置引导状态（用于测试）
  Future<void> resetGuide(String guideId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('guide_shown_$guideId');
    debugPrint('[FeatureGuide] Guide reset: $guideId');
  }

  /// 重置所有引导状态（用于测试）
  Future<void> resetAllGuides() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith('guide_shown_')).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
    debugPrint('[FeatureGuide] All guides reset');
  }
}
