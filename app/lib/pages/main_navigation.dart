import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/glass_components.dart';
import '../services/app_upgrade_service.dart';
import '../services/secure_storage_service.dart';
import '../services/global_voice_assistant_manager.dart';
import '../services/voice_navigation_executor.dart';
import '../providers/global_voice_assistant_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_update_dialog.dart';
import '../l10n/l10n.dart';
import '../providers/ledger_context_provider.dart';
import 'home_page.dart';
import 'analysis_center_page.dart';
import 'profile_page.dart';
import 'enhanced_voice_assistant_page.dart';
import 'add_transaction_page.dart';

/// 主导航页面
/// 底部导航：首页 | 分析 | ➕ | 小记 | 我的
/// - 首页（仪表盘）
/// - 分析（数据分析中心）
/// - ➕（单击手动记账，长按语音记账）
/// - 小记（语音助手）
/// - 我的（个人中心，包含预算）
class MainNavigation extends ConsumerStatefulWidget {
  const MainNavigation({super.key});

  /// 获取FAB按钮的GlobalKey（用于功能引导）
  static GlobalKey get fabKey => _MainNavigationState._fabKey;

  /// 获取小记导航栏的GlobalKey（用于功能引导）
  static GlobalKey get xiaojiNavKey => _MainNavigationState._xiaojiNavKey;

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _hasCheckedUpdate = false;
  bool _isRecording = false;
  bool _hasPermission = false;
  late AnimationController _pulseController;
  OverlayEntry? _recordingOverlay;

  // 双击退出相关
  DateTime? _lastBackPressTime;

  // GlobalKey for feature guide
  static final GlobalKey _fabKey = GlobalKey();
  static final GlobalKey _xiaojiNavKey = GlobalKey();

  // 录音自动停止配置
  static const int _maxRecordingSeconds = 15;  // 最大录音时长
  Timer? _recordingTimer;
  Timer? _countdownTimer;
  int _remainingSeconds = _maxRecordingSeconds;
  VoidCallback? _voiceStateListener;

  // 页面列表（不包含中间的+按钮）
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pages = [
      const HomePage(),
      const AnalysisCenterPage(),
      EnhancedVoiceAssistantPage(onBack: _goToHome),  // 小记宠物助手
      const ProfilePage(),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowUpdate();
      _initializeLedgerContext();
      _checkMicrophonePermission();
      _setupVoiceNavigationExecutor();
    });
  }

  /// 检查并请求麦克风权限（应用启动时统一请求）
  Future<void> _checkMicrophonePermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) {
      setState(() {
        _hasPermission = true;
      });
      return;
    }

    // 如果没有授权，主动请求
    debugPrint('[MainNavigation] 麦克风权限未授予，发起权限请求');
    final requestStatus = await Permission.microphone.request();
    setState(() {
      _hasPermission = requestStatus.isGranted;
    });

    if (!requestStatus.isGranted) {
      debugPrint('[MainNavigation] 用户拒绝了麦克风权限');
    } else {
      debugPrint('[MainNavigation] 麦克风权限已授予');
    }
  }

  /// 请求麦克风权限
  Future<bool> _requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    setState(() {
      _hasPermission = status.isGranted;
    });
    return status.isGranted;
  }

  /// 返回首页
  void _goToHome() {
    setState(() => _currentIndex = 0);
  }

  /// 设置语音导航执行器
  void _setupVoiceNavigationExecutor() {
    debugPrint('[MainNavigation] 设置语音导航标签切换器');
    // 设置标签切换器，允许语音导航切换底部标签
    VoiceNavigationExecutor.instance.setTabSwitcher((index) {
      debugPrint('[MainNavigation] 切换到标签: $index');
      if (mounted) {
        setState(() {
          // 将语音导航索引映射到底部导航索引
          // 语音导航: 0=首页, 1=报表, 2=预算, 3=储蓄, 4=钱龄
          // 底部导航: 0=首页, 1=分析, 2=小记, 3=我的
          switch (index) {
            case 0: // 首页
              _currentIndex = 0;
              break;
            case 1: // 报表/分析
              _currentIndex = 1;
              break;
            default:
              _currentIndex = 0;
          }
        });
      }
    });
  }

  /// 初始化账本上下文
  Future<void> _initializeLedgerContext() async {
    try {
      final secureStorage = SecureStorageService();
      String? userId = await secureStorage.getUserId();

      // 如果没有用户ID，使用guest ID
      if (userId == null || userId.isEmpty) {
        userId = 'guest';
      }

      // 初始化账本上下文
      await ref.read(ledgerContextProvider.notifier).initialize(userId);
    } catch (e) {
      debugPrint('Failed to initialize ledger context in MainNavigation: $e');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _recordingTimer?.cancel();
    _countdownTimer?.cancel();
    _removeRecordingOverlay();

    // 清理语音导航执行器
    VoiceNavigationExecutor.instance.setTabSwitcher(null);

    // 移除语音状态监听器
    if (_voiceStateListener != null) {
      try {
        final voiceManager = ref.read(globalVoiceAssistantProvider);
        voiceManager.removeListener(_voiceStateListener!);
      } catch (_) {
        // 忽略清理错误
      }
      _voiceStateListener = null;
    }

    super.dispose();
  }

  Future<void> _checkAndShowUpdate() async {
    if (_hasCheckedUpdate) return;
    _hasCheckedUpdate = true;

    try {
      final result = AppUpgradeService().lastCheckResult;
      if (result != null && result.hasUpdate && result.latestVersion != null) {
        if (mounted) {
          await AppUpdateDialog.show(
            context,
            versionInfo: result.latestVersion!,
            isForceUpdate: result.isForceUpdate,
          );
        }
      }
    } catch (e) {
      debugPrint('检查更新失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 小记页面（index=2）不显示底部导航栏
    final isVoiceAssistantPage = _currentIndex == 2;

    return PopScope(
      canPop: false,  // 始终拦截返回手势
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackGesture();
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
        bottomNavigationBar: isVoiceAssistantPage ? null : _buildBottomNavBar(context),
        floatingActionButton: isVoiceAssistantPage ? null : _buildCenterButton(context),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      ),
    );
  }

  /// 处理返回手势
  void _handleBackGesture() {
    // 如果在非首页，返回首页
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
      return;
    }

    // 在首页，双击退出
    final now = DateTime.now();
    if (_lastBackPressTime != null &&
        now.difference(_lastBackPressTime!) < const Duration(seconds: 2)) {
      // 两次返回间隔小于2秒，退出应用
      Navigator.of(context).pop();
      return;
    }

    // 第一次按返回，显示提示
    _lastBackPressTime = now;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('再滑一次退出应用'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// 中间的+按钮
  /// 单击：手动记账
  /// 长按：直接开始语音录音
  Widget _buildCenterButton(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, 8),  // 向下偏移
      child: Container(
        key: _fabKey,  // Add key for feature guide
        child: GestureDetector(
          onTap: () {
          // 单击进入手动记账
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddTransactionPage()),
          );
        },
        onLongPressStart: (_) {
          // 长按直接开始录音
          _startRecording();
        },
        onLongPressEnd: (_) {
          // 松开结束录音
          _stopRecording();
        },
        onLongPressCancel: () {
          // 取消录音
          _stopRecording();
        },
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final isRecording = _isRecording;
            return Container(
              width: isRecording ? 72 : 64,
              height: isRecording ? 72 : 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isRecording
                      ? [AppTheme.expenseColor, AppTheme.expenseColor.withValues(alpha: 0.85)]
                      : [AppTheme.primaryColor, AppTheme.primaryColor.withValues(alpha: 0.85)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (isRecording ? AppTheme.expenseColor : AppTheme.primaryColor)
                        .withValues(alpha: 0.4),
                    blurRadius: isRecording ? 24 : 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                isRecording ? Icons.mic : Icons.add,
                color: Colors.white,
                size: isRecording ? 36 : 32,
              ),
            );
          },
        ),
      ),
      ),
    );
  }

  /// 开始录音
  Future<void> _startRecording() async {
    // 检查权限
    if (!_hasPermission) {
      final granted = await _requestMicrophonePermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('需要麦克风权限才能使用语音功能'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }
    }

    setState(() {
      _isRecording = true;
      _remainingSeconds = _maxRecordingSeconds;
    });
    _pulseController.repeat();
    _showRecordingOverlay();

    // 启动倒计时
    _startCountdown();

    // 启动自动停止计时器
    _recordingTimer = Timer(
      Duration(seconds: _maxRecordingSeconds),
      () {
        if (_isRecording) {
          _stopRecording(reason: '已达到最大录音时长');
        }
      },
    );

    // 使用 GlobalVoiceAssistantManager 开始录音
    try {
      final voiceManager = ref.read(globalVoiceAssistantProvider);

      // 监听状态变化
      _voiceStateListener = () {
        if (!_isRecording) return;

        final state = voiceManager.ballState;
        if (state == FloatingBallState.processing) {
          // 录音结束，正在处理
          _removeRecordingOverlay();
        } else if (state == FloatingBallState.success || state == FloatingBallState.error) {
          // 处理完成
          setState(() => _isRecording = false);
          _pulseController.stop();
          _pulseController.reset();
        }
      };
      voiceManager.addListener(_voiceStateListener!);

      await voiceManager.startRecording();
    } catch (e) {
      debugPrint('启动语音识别失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('语音服务启动失败: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      _stopRecording();
    }
  }

  /// 启动倒计时
  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isRecording) {
        timer.cancel();
        return;
      }
      setState(() {
        _remainingSeconds--;
      });
      _updateOverlay();

      // 最后3秒提示
      if (_remainingSeconds <= 3 && _remainingSeconds > 0) {
        // 可以添加震动反馈
      }
    });
  }

  /// 停止录音
  Future<void> _stopRecording({String? reason}) async {
    if (!_isRecording) return;

    // 取消计时器
    _recordingTimer?.cancel();
    _countdownTimer?.cancel();

    setState(() {
      _isRecording = false;
    });
    _pulseController.stop();
    _pulseController.reset();
    _removeRecordingOverlay();

    // 移除状态监听器并停止语音识别
    try {
      final voiceManager = ref.read(globalVoiceAssistantProvider);

      // 移除监听器
      if (_voiceStateListener != null) {
        voiceManager.removeListener(_voiceStateListener!);
        _voiceStateListener = null;
      }

      await voiceManager.stopRecording();
    } catch (e) {
      debugPrint('停止语音识别失败: $e');
    }

    // 显示提示（如果有特定原因）
    if (mounted && reason != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(reason),
          duration: const Duration(seconds: 2),
        ),
      );
    }
    // 处理结果会通过 GlobalVoiceAssistantManager 的状态更新和TTS播报反馈给用户
  }

  /// 更新浮层显示
  void _updateOverlay() {
    _recordingOverlay?.markNeedsBuild();
  }

  /// 显示录音状态浮层
  void _showRecordingOverlay() {
    _removeRecordingOverlay();

    _recordingOverlay = OverlayEntry(
      builder: (context) => _RecordingOverlay(
        animation: _pulseController,
        remainingSeconds: _remainingSeconds,
        maxSeconds: _maxRecordingSeconds,
        errorMessage: null,
      ),
    );

    Overlay.of(context).insert(_recordingOverlay!);
  }

  /// 移除录音状态浮层
  void _removeRecordingOverlay() {
    _recordingOverlay?.remove();
    _recordingOverlay = null;
  }

  /// 底部导航栏
  Widget _buildBottomNavBar(BuildContext context) {
    return Container(
      key: _xiaojiNavKey,  // Add key for the navigation bar (targeting xiaoji tab)
      child: GlassBottomNavigation(
      currentIndex: _currentIndex,
      onTap: (index) {
        // 跳过中间的占位项(index=2)
        if (index == 2) return;
        final actualIndex = index > 2 ? index - 1 : index;
        setState(() => _currentIndex = actualIndex);
      },
      items: [
        GlassBottomNavItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home,
          label: context.l10n.home,
        ),
        GlassBottomNavItem(
          icon: Icons.analytics_outlined,
          activeIcon: Icons.analytics,
          label: context.l10n.trends,
        ),
        // 中间占位（给FAB留空间）
        const GlassBottomNavItem(
          label: '',
          isPlaceholder: true,
        ),
        // 小记宠物助手
        const GlassBottomNavItem(
          icon: Icons.pets_outlined,
          activeIcon: Icons.pets,
          label: '小记',
        ),
        GlassBottomNavItem(
          icon: Icons.person_outline,
          activeIcon: Icons.person,
          label: context.l10n.profile,
        ),
      ],
    ),
    );
  }
}

/// 录音状态浮层（长按+号时显示）
class _RecordingOverlay extends StatelessWidget {
  final Animation<double> animation;
  final int remainingSeconds;
  final int maxSeconds;
  final String? errorMessage;

  const _RecordingOverlay({
    required this.animation,
    required this.remainingSeconds,
    required this.maxSeconds,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    final isWarning = remainingSeconds <= 3;
    final progress = remainingSeconds / maxSeconds;

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 倒计时显示
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isWarning
                    ? Colors.orange.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 18,
                    color: isWarning ? Colors.orange : Colors.white70,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${remainingSeconds}s',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isWarning ? Colors.orange : Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 波浪动画
            AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // 外层波浪
                    Container(
                      width: 140 + (animation.value * 40),
                      height: 140 + (animation.value * 40),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (isWarning ? Colors.orange : AppTheme.expenseColor)
                            .withValues(alpha: 0.1 * (1 - animation.value)),
                      ),
                    ),
                    // 中层波浪
                    Container(
                      width: 120 + (animation.value * 25),
                      height: 120 + (animation.value * 25),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (isWarning ? Colors.orange : AppTheme.expenseColor)
                            .withValues(alpha: 0.15 * (1 - animation.value)),
                      ),
                    ),
                    // 内层波浪
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (isWarning ? Colors.orange : AppTheme.expenseColor)
                            .withValues(alpha: 0.1),
                      ),
                    ),
                    // 进度环
                    SizedBox(
                      width: 96,
                      height: 96,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 3,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isWarning ? Colors.orange : Colors.white,
                        ),
                      ),
                    ),
                    // 麦克风图标
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isWarning
                              ? [Colors.orange, Colors.orange.withValues(alpha: 0.85)]
                              : [AppTheme.expenseColor, AppTheme.expenseColor.withValues(alpha: 0.85)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (isWarning ? Colors.orange : AppTheme.expenseColor)
                                .withValues(alpha: 0.4),
                            blurRadius: 24,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.mic,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 32),

            // 提示文字
            Text(
              isWarning ? '即将自动停止...' : '正在聆听...',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isWarning ? Colors.orange : Colors.white,
              ),
            ),
            const SizedBox(height: 8),

            // 错误提示或正常提示
            if (errorMessage != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber, size: 16, color: Colors.orange),
                    const SizedBox(width: 6),
                    Text(
                      errorMessage!,
                      style: const TextStyle(fontSize: 13, color: Colors.orange),
                    ),
                  ],
                ),
              )
            else
              Text(
                '松开结束录音',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),

            const SizedBox(height: 24),

            // 示例提示
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 16,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '试试说"午餐花了35元"',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
