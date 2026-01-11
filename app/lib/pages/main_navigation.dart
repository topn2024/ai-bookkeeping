import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/glass_components.dart';
import '../services/app_upgrade_service.dart';
import '../services/secure_storage_service.dart';
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

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  int _currentIndex = 0;
  bool _hasCheckedUpdate = false;

  // 页面列表（不包含中间的+按钮）
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const HomePage(),
      const AnalysisCenterPage(),
      EnhancedVoiceAssistantPage(onBack: _goToHome),  // 小记宠物助手
      const ProfilePage(),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowUpdate();
      _initializeLedgerContext();
    });
  }

  /// 返回首页
  void _goToHome() {
    setState(() => _currentIndex = 0);
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

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: isVoiceAssistantPage ? null : _buildBottomNavBar(context),
      floatingActionButton: isVoiceAssistantPage ? null : _buildCenterButton(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  /// 中间的+按钮
  /// 单击：手动记账
  /// 长按：语音记账（底部浮层）
  Widget _buildCenterButton(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, 8),  // 向下偏移
      child: GestureDetector(
        onTap: () {
          // 单击进入手动记账
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddTransactionPage()),
          );
        },
        onLongPress: () {
          // 长按显示底部语音录入浮层
          _showVoiceRecordingSheet(context);
        },
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryColor,
                AppTheme.primaryColor.withValues(alpha: 0.85),
              ],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.add,
            color: Colors.white,
            size: 32,
          ),
        ),
      ),
    );
  }

  /// 显示语音录入底部浮层
  void _showVoiceRecordingSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const VoiceRecordingSheet(),
    );
  }

  /// 底部导航栏
  Widget _buildBottomNavBar(BuildContext context) {
    return GlassBottomNavigation(
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
    );
  }
}

/// 语音录入底部浮层
class VoiceRecordingSheet extends StatefulWidget {
  const VoiceRecordingSheet({super.key});

  @override
  State<VoiceRecordingSheet> createState() => _VoiceRecordingSheetState();
}

class _VoiceRecordingSheetState extends State<VoiceRecordingSheet>
    with SingleTickerProviderStateMixin {
  bool _isRecording = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _toggleRecording() {
    setState(() {
      _isRecording = !_isRecording;
      if (_isRecording) {
        _pulseController.repeat();
      } else {
        _pulseController.stop();
        _pulseController.reset();
        // 模拟器提示
        _showSimulatorHint();
      }
    });
  }

  void _showSimulatorHint() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('语音识别需要真机环境'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖动条
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // 标题
            Text(
              _isRecording ? '正在聆听...' : '按住说话',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _isRecording ? AppTheme.expenseColor : AppTheme.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isRecording ? '松开结束录音' : '长按麦克风开始语音记账',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 32),

            // 语音按钮
            GestureDetector(
              onTapDown: (_) => _toggleRecording(),
              onTapUp: (_) {
                if (_isRecording) _toggleRecording();
              },
              onTapCancel: () {
                if (_isRecording) _toggleRecording();
              },
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // 波浪效果
                      if (_isRecording) ...[
                        Container(
                          width: 120 + (_pulseController.value * 30),
                          height: 120 + (_pulseController.value * 30),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.expenseColor.withValues(
                              alpha: 0.1 * (1 - _pulseController.value),
                            ),
                          ),
                        ),
                        Container(
                          width: 100 + (_pulseController.value * 15),
                          height: 100 + (_pulseController.value * 15),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.expenseColor.withValues(
                              alpha: 0.15 * (1 - _pulseController.value),
                            ),
                          ),
                        ),
                      ],
                      // 主按钮
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: _isRecording
                                ? [AppTheme.expenseColor, AppTheme.expenseColor.withValues(alpha: 0.85)]
                                : [AppTheme.primaryColor, AppTheme.primaryColor.withValues(alpha: 0.85)],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (_isRecording ? AppTheme.expenseColor : AppTheme.primaryColor)
                                  .withValues(alpha: 0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Icon(
                          _isRecording ? Icons.mic : Icons.mic_none,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // 提示文字
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lightbulb_outline, size: 16, color: AppTheme.textSecondaryColor),
                const SizedBox(width: 4),
                Text(
                  '试试说"午餐花了35元"',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
