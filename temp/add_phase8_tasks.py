# -*- coding: utf-8 -*-
"""
在第27章实施路线图中添加阶段八：用户增长体系
"""

def main():
    filepath = 'd:/code/ai-bookkeeping/docs/design/app_v2_design.md'

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # 在阶段七最后一个任务后、测试策略注释前插入阶段八
    old_text = '''- [ ] 正式发布与版本监控

> **注**：测试策略已独立为单独文档，详见 [AI智能记账 2.0 测试策略](./app_v2_test_strategy.md)'''

    new_text = '''- [ ] 正式发布与版本监控

#### 阶段八：用户增长体系 (Post-Launch)

**NPS监测与口碑优化（第28章）**
- [ ] 实现应用内NPS调查组件（智能触发时机）
- [ ] 实现NPS数据采集与分析服务
- [ ] 实现用户分群策略（推荐者/被动者/贬损者）
- [ ] 实现针对性反馈收集与响应机制
- [ ] 实现口碑分享素材自动生成
- [ ] 实现成就徽章与里程碑分享功能
- [ ] 实现应用商店好评引导流程

**社交裂变与低成本获客（第29章）**
- [ ] 实现家庭/情侣记账邀请码机制
- [ ] 实现邀请奖励系统（双向激励）
- [ ] 实现社交分享组件（微信/朋友圈/微博）
- [ ] 实现账单分享卡片设计与生成
- [ ] 实现邀请漏斗数据埋点与分析
- [ ] 实现 A/B 测试框架（邀请文案/奖励策略）

**ASO与内容营销准备**
- [ ] 完善应用商店关键词优化
- [ ] 准备理财知识小贴士内容库
- [ ] 实现记账技巧卡片分享功能
- [ ] 实现用户故事收集与展示模块

> **注**：阶段八为发布后持续迭代内容，与阶段七可并行推进部分任务

> **注**：测试策略已独立为单独文档，详见 [AI智能记账 2.0 测试策略](./app_v2_test_strategy.md)'''

    if old_text in content:
        if '#### 阶段八：用户增长体系' not in content:
            content = content.replace(old_text, new_text)
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            print("已添加阶段八：用户增长体系实施任务")
        else:
            print("阶段八已存在，无需重复添加")
    else:
        print("未找到目标位置")

if __name__ == '__main__':
    main()
