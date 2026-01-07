# -*- coding: utf-8 -*-
"""
将智能语音交互系统（15.12节）抽取为独立的第17章
"""

import re

def main():
    filepath = 'd:/code/ai-bookkeeping/docs/design/app_v2_design.md'

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. 找到15.12节的开始和结束位置
    voice_start_marker = '### 15.12 智能语音交互系统'
    voice_end_marker = '## 16. 自学习与协同学习系统'

    start_idx = content.find(voice_start_marker)
    end_idx = content.find(voice_end_marker)

    if start_idx == -1 or end_idx == -1:
        print("❌ 未找到语音交互系统章节")
        return

    # 2. 提取15.12节内容
    voice_content = content[start_idx:end_idx]
    print(f"✅ 提取语音交互系统内容: {len(voice_content)} 字符")

    # 3. 转换章节编号
    # 15.12.X -> 17.X
    # 15.12.X.Y -> 17.X.Y
    voice_content = voice_content.replace('### 15.12 智能语音交互系统', '## 17. 智能语音交互系统')
    voice_content = voice_content.replace('#### 15.12.0 ', '### 17.0 ')
    voice_content = voice_content.replace('#### 15.12.0.1 ', '### 17.0.1 ')
    voice_content = voice_content.replace('#### 15.12.0.2 ', '### 17.0.2 ')
    voice_content = voice_content.replace('#### 15.12.0.3 ', '### 17.0.3 ')
    voice_content = voice_content.replace('#### 15.12.0.4 ', '### 17.0.4 ')
    voice_content = voice_content.replace('#### 15.12.1 ', '### 17.1 ')
    voice_content = voice_content.replace('#### 15.12.1.1 ', '### 17.1.1 ')
    voice_content = voice_content.replace('##### 15.12.1.1.1 ', '#### 17.1.1.1 ')
    voice_content = voice_content.replace('##### 15.12.1.1.2 ', '#### 17.1.1.2 ')
    voice_content = voice_content.replace('##### 15.12.1.1.3 ', '#### 17.1.1.3 ')
    voice_content = voice_content.replace('##### 15.12.1.1.4 ', '#### 17.1.1.4 ')
    voice_content = voice_content.replace('##### 15.12.1.1.5 ', '#### 17.1.1.5 ')
    voice_content = voice_content.replace('##### 15.12.1.1.6 ', '#### 17.1.1.6 ')
    voice_content = voice_content.replace('##### 15.12.1.1.7 ', '#### 17.1.1.7 ')
    voice_content = voice_content.replace('###### 15.12.1.1.7.1 ', '##### 17.1.1.7.1 ')
    voice_content = voice_content.replace('###### 15.12.1.1.7.2 ', '##### 17.1.1.7.2 ')
    voice_content = voice_content.replace('###### 15.12.1.1.7.3 ', '##### 17.1.1.7.3 ')
    voice_content = voice_content.replace('###### 15.12.1.1.7.4 ', '##### 17.1.1.7.4 ')
    voice_content = voice_content.replace('###### 15.12.1.1.7.5 ', '##### 17.1.1.7.5 ')
    voice_content = voice_content.replace('###### 15.12.1.1.7.6 ', '##### 17.1.1.7.6 ')
    voice_content = voice_content.replace('##### 15.12.1.1.8 ', '#### 17.1.1.8 ')
    voice_content = voice_content.replace('###### 15.12.1.1.8.1 ', '##### 17.1.1.8.1 ')
    voice_content = voice_content.replace('###### 15.12.1.1.8.2 ', '##### 17.1.1.8.2 ')
    voice_content = voice_content.replace('###### 15.12.1.1.8.3 ', '##### 17.1.1.8.3 ')
    voice_content = voice_content.replace('###### 15.12.1.1.8.4 ', '##### 17.1.1.8.4 ')
    voice_content = voice_content.replace('###### 15.12.1.1.8.5 ', '##### 17.1.1.8.5 ')
    voice_content = voice_content.replace('###### 15.12.1.1.8.6 ', '##### 17.1.1.8.6 ')
    voice_content = voice_content.replace('###### 15.12.1.1.8.7 ', '##### 17.1.1.8.7 ')
    voice_content = voice_content.replace('#### 15.12.1.2 ', '### 17.1.2 ')
    voice_content = voice_content.replace('##### 15.12.1.2.1 ', '#### 17.1.2.1 ')
    voice_content = voice_content.replace('##### 15.12.1.2.2 ', '#### 17.1.2.2 ')
    voice_content = voice_content.replace('##### 15.12.1.2.3 ', '#### 17.1.2.3 ')
    voice_content = voice_content.replace('##### 15.12.1.2.4 ', '#### 17.1.2.4 ')
    voice_content = voice_content.replace('##### 15.12.1.2.5 ', '#### 17.1.2.5 ')
    voice_content = voice_content.replace('##### 15.12.1.2.6 ', '#### 17.1.2.6 ')
    voice_content = voice_content.replace('##### 15.12.1.2.7 ', '#### 17.1.2.7 ')
    voice_content = voice_content.replace('#### 15.12.2 ', '### 17.2 ')
    voice_content = voice_content.replace('#### 15.12.3 ', '### 17.3 ')
    voice_content = voice_content.replace('##### 15.12.3.1 ', '#### 17.3.1 ')
    voice_content = voice_content.replace('##### 15.12.3.2 ', '#### 17.3.2 ')
    voice_content = voice_content.replace('##### 15.12.3.3 ', '#### 17.3.3 ')
    voice_content = voice_content.replace('#### 15.12.4 ', '### 17.4 ')
    voice_content = voice_content.replace('##### 15.12.4.1 ', '#### 17.4.1 ')
    voice_content = voice_content.replace('##### 15.12.4.2 ', '#### 17.4.2 ')
    voice_content = voice_content.replace('##### 15.12.4.3 ', '#### 17.4.3 ')
    voice_content = voice_content.replace('#### 15.12.5 ', '### 17.5 ')
    voice_content = voice_content.replace('#### 15.12.6 ', '### 17.6 ')
    voice_content = voice_content.replace('#### 15.12.7 ', '### 17.7 ')
    voice_content = voice_content.replace('#### 15.12.8 ', '### 17.8 ')
    voice_content = voice_content.replace('#### 15.12.9 ', '### 17.9 ')
    voice_content = voice_content.replace('#### 15.12.10 ', '### 17.10 ')
    voice_content = voice_content.replace('##### 15.12.10.0 ', '#### 17.10.0 ')
    voice_content = voice_content.replace('##### 15.12.10.1 ', '#### 17.10.1 ')
    voice_content = voice_content.replace('##### 15.12.10.2 ', '#### 17.10.2 ')
    voice_content = voice_content.replace('##### 15.12.10.3 ', '#### 17.10.3 ')
    voice_content = voice_content.replace('##### 15.12.10.4 ', '#### 17.10.4 ')
    voice_content = voice_content.replace('##### 15.12.10.5 ', '#### 17.10.5 ')
    voice_content = voice_content.replace('##### 15.12.10.6 ', '#### 17.10.6 ')
    voice_content = voice_content.replace('##### 15.12.10.7 ', '#### 17.10.7 ')

    # 4. 在语音章节开头添加设计原则说明
    voice_header = '''## 17. 智能语音交互系统

### 17.0 设计原则回顾

本章定义AI记账应用的智能语音交互系统架构。该系统作为**独立模块**设计，提供全面的语音交互能力。

#### 17.0.0 智能语音系统设计原则矩阵

| 设计原则 | 在语音系统中的体现 | 实现方式 |
|----------|-------------------|----------|
| **懒人设计** | 语音优先，一句话完成操作 | 支持复杂语音指令一次性解析执行 |
| **伙伴化** | 拟人化语音反馈 | 采用友好、幽默的语音回复风格 |
| **渐进式** | 语音能力逐步解锁 | 从基础记账到高级查询逐步引导 |
| **容错性** | 模糊匹配与确认 | 智能理解模糊表述，关键操作二次确认 |
| **开放集成** | 统一语音接口 | 所有功能模块通过统一语音接口接入 |

#### 17.0.0.1 与其他系统的关系

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                        智能语音交互系统与其他模块的关系                          │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│                        ┌─────────────────────────┐                           │
│                        │   17. 智能语音交互系统   │                           │
│                        │      （本章）            │                           │
│                        └───────────┬─────────────┘                           │
│                                    │                                         │
│              ┌─────────────────────┼─────────────────────┐                   │
│              │                     │                     │                   │
│              ▼                     ▼                     ▼                   │
│   ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐          │
│   │  调用自学习接口   │  │  调用智能分类     │  │  调用数据查询     │          │
│   └──────────────────┘  └──────────────────┘  └──────────────────┘          │
│              │                     │                     │                   │
│              ▼                     ▼                     ▼                   │
│   ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐          │
│   │ 16. 自学习系统   │  │ 15. 智能化方案   │  │  12. 数据可视化  │          │
│   │   - 意图学习      │  │   - 智能分类      │  │   - 图表数据      │          │
│   │   - 语音习惯      │  │   - 预算建议      │  │   - 报表生成      │          │
│   └──────────────────┘  └──────────────────┘  └──────────────────┘          │
│                                                                              │
│   接入方式：各功能通过 VoiceCommandHandler 统一接入语音能力                     │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

> **📚 模块化设计说明**
>
> 本章语音系统的自学习能力基于**第16章 自学习与协同学习系统**提供的统一框架。
> 意图识别学习详见16.3.4节（意图识别学习适配器）。

'''

    # 替换开头
    voice_content = voice_content.replace('## 17. 智能语音交互系统\n', voice_header, 1)

    print("✅ 转换章节编号完成")

    # 5. 从原位置删除15.12节，替换为引用
    replacement_text = '''### 15.12 智能语音交互系统

> **📚 重要说明**
>
> 智能语音交互系统已抽取为独立的**第17章**，作为独立模块设计。
> 请参阅第17章获取完整的语音交互系统设计方案。

本节内容包括：
- 17.0 系统架构全景图
- 17.1 意图识别引擎（含自学习模型）
- 17.2 语音记账模块
- 17.3 智能语音配置模块
- 17.4 智能语音导航模块
- 17.5 智能语音查询模块
- 17.6 语音交互会话管理
- 17.7 语音交互界面设计
- 17.8 与其他系统的集成
- 17.9 目标达成检测
- 17.10 智能语音反馈与客服系统

'''

    # 6. 重建文档
    new_content = content[:start_idx] + replacement_text + voice_content + content[end_idx:]

    # 7. 更新后续章节编号（16->16不变，但17及之后需要调整）
    # 由于我们把语音系统放在了第17章，需要调整原来的17-25变成18-26
    chapter_updates = [
        ('## 17. 性能设计与优化', '## 18. 性能设计与优化'),
        ('## 18. 用户体验设计', '## 19. 用户体验设计'),
        ('## 19. 国际化与本地化', '## 20. 国际化与本地化'),
        ('## 20. 安全与隐私', '## 21. 安全与隐私'),
        ('## 21. 异常处理与容错设计', '## 22. 异常处理与容错设计'),
        ('## 22. 可扩展性与演进架构', '## 23. 可扩展性与演进架构'),
        ('## 23. 可观测性与监控', '## 24. 可观测性与监控'),
        ('## 24. 版本迁移策略', '## 25. 版本迁移策略'),
        ('## 25. 实施路线图', '## 26. 实施路线图'),
    ]

    for old, new in chapter_updates:
        new_content = new_content.replace(old, new)
        print(f"✅ 章节更新: {old} -> {new}")

    # 8. 更新目录
    # 添加第17章到目录
    toc_17 = '''- [17. 智能语音交互系统](#17-智能语音交互系统)
  - [17.0 设计原则回顾](#170-设计原则回顾)
  - [17.1 意图识别引擎](#171-意图识别引擎)
  - [17.2 语音记账模块](#172-语音记账模块)
  - [17.3 智能语音配置模块](#173-智能语音配置模块)
  - [17.4 智能语音导航模块](#174-智能语音导航模块)
  - [17.5 智能语音查询模块](#175-智能语音查询模块)
  - [17.6 语音交互会话管理](#176-语音交互会话管理)
  - [17.7 语音交互界面设计](#177-语音交互界面设计)
  - [17.8 与其他系统的集成](#178-与其他系统的集成)
  - [17.9 目标达成检测](#179-目标达成检测)
  - [17.10 智能语音反馈与客服系统](#1710-智能语音反馈与客服系统)
'''

    # 在第17章目录位置插入
    old_toc_17 = '- [17. 性能设计与优化'
    new_toc_17 = toc_17 + '- [18. 性能设计与优化'
    new_content = new_content.replace(old_toc_17, new_toc_17)

    # 更新目录中的章节编号
    toc_updates = [
        ('- [18. 用户体验设计](#18-用户体验设计)', '- [19. 用户体验设计](#19-用户体验设计)'),
        ('- [19. 国际化与本地化](#19-国际化与本地化)', '- [20. 国际化与本地化](#20-国际化与本地化)'),
        ('- [20. 安全与隐私](#20-安全与隐私)', '- [21. 安全与隐私](#21-安全与隐私)'),
        ('- [21. 异常处理与容错设计](#21-异常处理与容错设计)', '- [22. 异常处理与容错设计](#22-异常处理与容错设计)'),
        ('- [22. 可扩展性与演进架构](#22-可扩展性与演进架构)', '- [23. 可扩展性与演进架构](#23-可扩展性与演进架构)'),
        ('- [23. 可观测性与监控](#23-可观测性与监控)', '- [24. 可观测性与监控](#24-可观测性与监控)'),
        ('- [24. 版本迁移策略](#24-版本迁移策略)', '- [25. 版本迁移策略](#25-版本迁移策略)'),
        ('- [25. 实施路线图](#25-实施路线图)', '- [26. 实施路线图](#26-实施路线图)'),
    ]

    for old, new in toc_updates:
        new_content = new_content.replace(old, new)

    # 9. 保存文件
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(new_content)

    print("\n✅ 第17章抽取完成！")
    print("   - 新增独立章节：17. 智能语音交互系统")
    print("   - 原15.12节替换为引用说明")
    print("   - 原17-25章编号顺延为18-26章")

if __name__ == '__main__':
    main()
