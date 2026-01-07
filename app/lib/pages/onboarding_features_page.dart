import 'package:flutter/material.dart';

/// 功能介绍引导页
///
/// 对应原型设计 10.15 功能介绍引导
/// 向新用户介绍应用的主要功能
class OnboardingFeaturesPage extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const OnboardingFeaturesPage({
    super.key,
    required this.onNext,
    required this.onSkip,
  });

  @override
  State<OnboardingFeaturesPage> createState() => _OnboardingFeaturesPageState();
}

class _OnboardingFeaturesPageState extends State<OnboardingFeaturesPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_FeatureData> _features = [
    _FeatureData(
      icon: Icons.camera_alt,
      emoji: '📸',
      title: '拍照记账',
      description: 'AI自动识别小票、发票\n一拍即记，省时省力',
      color: Colors.blue,
    ),
    _FeatureData(
      icon: Icons.mic,
      emoji: '🎤',
      title: '语音记账',
      description: '说一句话完成记账\n解放你的双手',
      color: Colors.purple,
    ),
    _FeatureData(
      icon: Icons.pie_chart,
      emoji: '📊',
      title: '消费分析',
      description: '智能分类，自动生成报表\n了解你的消费习惯',
      color: Colors.orange,
    ),
    _FeatureData(
      icon: Icons.savings,
      emoji: '🎯',
      title: '储蓄目标',
      description: '设定目标，追踪进度\n让存钱变得有动力',
      color: Colors.green,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 跳过按钮
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: widget.onSkip,
                child: const Text('跳过'),
              ),
            ),

            // 功能展示
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _features.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  return _FeaturePage(feature: _features[index]);
                },
              ),
            ),

            // 页面指示器
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _features.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? _features[index].color
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // 下一步/开始按钮
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ElevatedButton(
                onPressed: () {
                  if (_currentPage < _features.length - 1) {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  } else {
                    widget.onNext();
                  }
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  backgroundColor: _features[_currentPage].color,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: Text(
                  _currentPage < _features.length - 1 ? '下一步' : '开始使用',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _FeaturePage extends StatelessWidget {
  final _FeatureData feature;

  const _FeaturePage({required this.feature});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 功能图标
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: feature.color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                feature.emoji,
                style: const TextStyle(fontSize: 70),
              ),
            ),
          ),

          const SizedBox(height: 48),

          // 标题
          Text(
            feature.title,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: feature.color,
            ),
          ),

          const SizedBox(height: 16),

          // 描述
          Text(
            feature.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureData {
  final IconData icon;
  final String emoji;
  final String title;
  final String description;
  final Color color;

  _FeatureData({
    required this.icon,
    required this.emoji,
    required this.title,
    required this.description,
    required this.color,
  });
}
