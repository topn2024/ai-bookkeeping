import 'package:flutter/material.dart';
import '../services/offline_capability_service.dart';

/// 离线状态顶部提示条
///
/// 根据设计文档21.2.1.2，在离线时显示清晰但不突兀的提示横幅
class OfflineStatusBar extends StatelessWidget {
  final NetworkStatusInfo status;
  final VoidCallback? onRetryPressed;
  final VoidCallback? onDetailsPressed;

  const OfflineStatusBar({
    super.key,
    required this.status,
    this.onRetryPressed,
    this.onDetailsPressed,
  });

  @override
  Widget build(BuildContext context) {
    // 在线时不显示
    if (status.isOnline) {
      return const SizedBox.shrink();
    }

    final _ = Theme.of(context);
    final isWeak = status.status == NetworkStatus.weak;

    return Material(
      color: isWeak
          ? const Color(0xFFFEF3C7) // 弱网：浅黄色
          : const Color(0xFFFFEBEE), // 离线：浅红色
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // 图标
              Icon(
                isWeak ? Icons.signal_cellular_alt : Icons.cloud_off,
                color: isWeak
                    ? const Color(0xFFD97706)
                    : const Color(0xFFEF5350),
                size: 20,
              ),
              const SizedBox(width: 12),

              // 文字
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isWeak ? '网络连接不稳定' : '当前处于离线模式',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isWeak
                            ? const Color(0xFF92400E)
                            : const Color(0xFFEF5350),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isWeak ? '部分功能可能响应缓慢' : '恢复网络后自动同步',
                      style: TextStyle(
                        fontSize: 11,
                        color: isWeak
                            ? const Color(0xFFB45309)
                            : const Color(0xFFE57373),
                      ),
                    ),
                  ],
                ),
              ),

              // 操作按钮
              if (onRetryPressed != null)
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  color: isWeak
                      ? const Color(0xFFD97706)
                      : const Color(0xFFEF5350),
                  onPressed: onRetryPressed,
                  tooltip: '重试连接',
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 离线状态监听组件
///
/// 自动监听网络状态变化并显示/隐藏提示条
class OfflineStatusListener extends StatefulWidget {
  final Widget child;
  final VoidCallback? onStatusChanged;
  final bool showStatusBar;

  const OfflineStatusListener({
    super.key,
    required this.child,
    this.onStatusChanged,
    this.showStatusBar = true,
  });

  @override
  State<OfflineStatusListener> createState() => _OfflineStatusListenerState();
}

class _OfflineStatusListenerState extends State<OfflineStatusListener>
    with SingleTickerProviderStateMixin {
  final OfflineCapabilityService _offlineService = OfflineCapabilityService();
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  NetworkStatusInfo _status = NetworkStatusInfo(
    status: NetworkStatus.unknown,
    timestamp: DateTime.now(),
  );

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: -1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    // 初始化状态
    _status = _offlineService.currentStatus;
    if (!_status.isOnline) {
      _animationController.forward();
    }

    // 监听状态变化
    _offlineService.statusStream.listen(_onStatusChanged);
  }

  void _onStatusChanged(NetworkStatusInfo status) {
    final wasOnline = _status.isOnline;
    setState(() {
      _status = status;
    });

    // 动画控制
    if (status.isOnline && !wasOnline) {
      // 从离线变为在线：滑出
      _animationController.reverse();
    } else if (!status.isOnline && wasOnline) {
      // 从在线变为离线：滑入
      _animationController.forward();
    }

    widget.onStatusChanged?.call();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 离线状态条（带动画）
        if (widget.showStatusBar)
          AnimatedBuilder(
            animation: _slideAnimation,
            builder: (context, child) {
              return ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: _slideAnimation.value + 1,
                  child: OfflineStatusBar(
                    status: _status,
                    onRetryPressed: () async {
                      await _offlineService.initialize();
                    },
                  ),
                ),
              );
            },
          ),

        // 主内容
        Expanded(child: widget.child),
      ],
    );
  }
}

/// 功能降级状态标识组件
///
/// 在功能处于降级状态时显示视觉标识
class FeatureDegradationBadge extends StatelessWidget {
  final String featureId;
  final Widget child;
  final bool showTooltip;

  const FeatureDegradationBadge({
    super.key,
    required this.featureId,
    required this.child,
    this.showTooltip = true,
  });

  @override
  Widget build(BuildContext context) {
    final offlineService = OfflineCapabilityService();
    final isDegraded = offlineService.isFeatureDegraded(featureId);

    if (!isDegraded) {
      return child;
    }

    final hint = offlineService.getFeatureDegradationHint(featureId);

    final badge = Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -4,
          top: -4,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.orange.shade400,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: const Icon(
              Icons.offline_bolt,
              size: 10,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );

    if (showTooltip && hint != null) {
      return Tooltip(
        message: hint,
        child: badge,
      );
    }

    return badge;
  }
}

/// L3仅在线功能禁用提示组件
///
/// 当L3功能在离线时被禁用时显示提示
class OnlineOnlyFeatureWrapper extends StatelessWidget {
  final String featureId;
  final Widget child;
  final Widget? disabledPlaceholder;
  final String? disabledMessage;

  const OnlineOnlyFeatureWrapper({
    super.key,
    required this.featureId,
    required this.child,
    this.disabledPlaceholder,
    this.disabledMessage,
  });

  @override
  Widget build(BuildContext context) {
    final offlineService = OfflineCapabilityService();
    final isAvailable = offlineService.isFeatureAvailable(featureId);
    final capability = offlineService.getFeatureCapability(featureId);

    if (isAvailable) {
      return child;
    }

    // 离线时显示禁用状态
    return disabledPlaceholder ??
        _buildDefaultDisabledPlaceholder(context, capability);
  }

  Widget _buildDefaultDisabledPlaceholder(
    BuildContext context,
    FeatureOfflineCapability? capability,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            disabledMessage ?? '${capability?.featureName ?? '此功能'}需要网络连接',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '请连接网络后再试',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

/// 离线模式完整页面组件
///
/// 参考原型设计6.11 离线模式提示页面
class OfflineModePage extends StatelessWidget {
  final VoidCallback? onManualInputPressed;
  final VoidCallback? onOfflineVoicePressed;
  final VoidCallback? onBackPressed;

  const OfflineModePage({
    super.key,
    this.onManualInputPressed,
    this.onOfflineVoicePressed,
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final offlineService = OfflineCapabilityService();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
        ),
        title: const Text('语音记账'),
      ),
      body: Column(
        children: [
          // 离线提示横幅
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFEBEE), Color(0xFFFFCDD2)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.cloud_off, color: Color(0xFFEF5350)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        '当前处于离线模式',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFFEF5350),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '使用本地识别引擎，功能受限',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFE57373),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 功能状态列表
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFeatureSection(
                  context,
                  title: '完全可用',
                  icon: Icons.check_circle,
                  iconColor: Colors.green,
                  features: offlineService.getFullOfflineFeatures(),
                ),
                const SizedBox(height: 16),
                _buildFeatureSection(
                  context,
                  title: '降级可用',
                  icon: Icons.offline_bolt,
                  iconColor: Colors.orange,
                  features: offlineService.getEnhancedOfflineFeatures(),
                ),
                const SizedBox(height: 16),
                _buildFeatureSection(
                  context,
                  title: '暂不可用',
                  icon: Icons.cancel,
                  iconColor: Colors.red,
                  features: offlineService.getOnlineOnlyFeatures(),
                ),
              ],
            ),
          ),

          // 底部操作按钮
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: onOfflineVoicePressed,
                    icon: const Icon(Icons.mic),
                    label: const Text('使用离线语音记账'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: onManualInputPressed,
                    icon: const Icon(Icons.edit),
                    label: const Text('手动输入记账'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<FeatureOfflineCapability> features,
  }) {
    if (features.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${features.length}项',
                style: TextStyle(
                  fontSize: 11,
                  color: iconColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...features.map((f) => _buildFeatureItem(context, f)),
      ],
    );
  }

  Widget _buildFeatureItem(
    BuildContext context,
    FeatureOfflineCapability feature,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.featureName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  feature.offlineCapability,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          _buildLevelBadge(feature.offlineLevel),
        ],
      ),
    );
  }

  Widget _buildLevelBadge(OfflineLevel level) {
    Color color;
    String text;

    switch (level) {
      case OfflineLevel.fullOffline:
        color = Colors.green;
        text = 'L0';
        break;
      case OfflineLevel.enhancedOffline:
        color = Colors.orange;
        text = 'L1';
        break;
      case OfflineLevel.onlinePreferred:
        color = Colors.blue;
        text = 'L2';
        break;
      case OfflineLevel.onlineOnly:
        color = Colors.red;
        text = 'L3';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

/// 网络恢复自动刷新混入
///
/// 为页面提供联网恢复后自动刷新的能力
mixin NetworkRecoveryRefreshMixin<T extends StatefulWidget> on State<T> {
  final OfflineCapabilityService _offlineService = OfflineCapabilityService();
  bool _wasOffline = false;

  @override
  void initState() {
    super.initState();
    _wasOffline = !_offlineService.isOnline;

    _offlineService.statusStream.listen((status) {
      if (status.isOnline && _wasOffline) {
        // 网络恢复，触发刷新
        onNetworkRecovered();
      }
      _wasOffline = !status.isOnline;
    });
  }

  /// 网络恢复时调用，子类重写此方法实现刷新逻辑
  void onNetworkRecovered() {
    // 子类实现
  }
}

/// 离线操作队列页面组件
///
/// 参考原型设计11.04 离线操作队列
class OfflineQueuePage extends StatefulWidget {
  const OfflineQueuePage({super.key});

  @override
  State<OfflineQueuePage> createState() => _OfflineQueuePageState();
}

class _OfflineQueuePageState extends State<OfflineQueuePage> {
  final OfflineCapabilityService _offlineService = OfflineCapabilityService();
  List<Map<String, dynamic>> _pendingItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPendingItems();
  }

  Future<void> _loadPendingItems() async {
    setState(() {
      _isLoading = true;
    });

    // 实际实现需要从OfflineQueueService获取待同步项
    // 这里使用模拟数据
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      _pendingItems = [
        {
          'id': '1',
          'type': 'transaction',
          'operation': 'create',
          'description': '午餐 - 公司食堂',
          'amount': -32.00,
          'timestamp': DateTime.now().subtract(const Duration(hours: 2)),
        },
        {
          'id': '2',
          'type': 'transaction',
          'operation': 'update',
          'description': '地铁充值',
          'amount': -100.00,
          'timestamp': DateTime.now().subtract(const Duration(hours: 1)),
        },
      ];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = _offlineService.currentStatus;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('待同步操作'),
      ),
      body: Column(
        children: [
          // 离线状态横幅
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFFFEF3C7),
            child: Row(
              children: [
                const Icon(Icons.cloud_off, color: Color(0xFFD97706), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '离线模式 · 恢复网络后自动同步',
                    style: TextStyle(
                      fontSize: 13,
                      color: const Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 待同步列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _pendingItems.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _pendingItems.length,
                        itemBuilder: (context, index) {
                          return _buildPendingItem(_pendingItems[index]);
                        },
                      ),
          ),

          // 底部信息
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                top: BorderSide(color: theme.dividerColor),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '待同步: ${_pendingItems.length} 项',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '数据已安全保存在本地',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: status.isOnline ? _syncNow : null,
                  child: const Text('立即同步'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_done,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            '没有待同步的操作',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '所有数据已同步完成',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingItem(Map<String, dynamic> item) {
    final theme = Theme.of(context);
    final amount = item['amount'] as double;
    final isExpense = amount < 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          // 操作类型图标
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getOperationColor(item['operation']).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getOperationIcon(item['operation']),
              color: _getOperationColor(item['operation']),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // 内容
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      item['description'],
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color:
                            _getOperationColor(item['operation']).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getOperationText(item['operation']),
                        style: TextStyle(
                          fontSize: 10,
                          color: _getOperationColor(item['operation']),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(item['timestamp']),
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // 金额
          Text(
            '${isExpense ? '' : '+'}${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isExpense ? Colors.red : Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getOperationIcon(String operation) {
    switch (operation) {
      case 'create':
        return Icons.add_circle_outline;
      case 'update':
        return Icons.edit_outlined;
      case 'delete':
        return Icons.delete_outline;
      default:
        return Icons.sync;
    }
  }

  Color _getOperationColor(String operation) {
    switch (operation) {
      case 'create':
        return Colors.green;
      case 'update':
        return Colors.blue;
      case 'delete':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getOperationText(String operation) {
    switch (operation) {
      case 'create':
        return '新增';
      case 'update':
        return '修改';
      case 'delete':
        return '删除';
      default:
        return '同步';
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return '刚刚';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}小时前';
    } else {
      return '${diff.inDays}天前';
    }
  }

  Future<void> _syncNow() async {
    // 实际实现需要调用同步服务
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在同步...')),
    );
  }
}
