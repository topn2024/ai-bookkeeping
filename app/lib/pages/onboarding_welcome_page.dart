import 'package:flutter/material.dart';

/// 新用户欢迎页
///
/// 对应原型设计 10.14 新用户欢迎页
/// 新用户首次打开应用的欢迎引导
class OnboardingWelcomePage extends StatelessWidget {
  final VoidCallback onNext;

  const OnboardingWelcomePage({
    super.key,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // 欢迎图标
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.blue[400]!, Colors.purple[400]!],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.3),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    '💰',
                    style: TextStyle(fontSize: 80),
                  ),
                ),
              ),

              const Spacer(),

              // 欢迎文字
              const Text(
                '欢迎使用',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'AI 智能记账',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '让记账变得简单有趣\n助你养成良好的理财习惯',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),

              const Spacer(flex: 2),

              // 特性亮点
              _FeatureHighlights(),

              const Spacer(),

              // 开始按钮
              ElevatedButton(
                onPressed: onNext,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: const Text(
                  '开始体验',
                  style: TextStyle(fontSize: 16),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureHighlights extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _FeatureItem(
          icon: Icons.auto_awesome,
          label: 'AI智能识别',
          color: Colors.orange,
        ),
        _FeatureItem(
          icon: Icons.insights,
          label: '消费洞察',
          color: Colors.blue,
        ),
        _FeatureItem(
          icon: Icons.savings,
          label: '储蓄目标',
          color: Colors.green,
        ),
      ],
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _FeatureItem({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
