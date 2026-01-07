# -*- coding: utf-8 -*-
"""
修复章节顺序：确保16. 自学习 在 17. 语音交互 之前
"""

import re

def main():
    filepath = 'd:/code/ai-bookkeeping/docs/design/app_v2_design.md'

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # 找到各个章节的位置
    ch15_end = content.find('### 15.12 智能语音交互系统')
    ch16_start = content.find('## 16. 自学习与协同学习系统')
    ch17_start = content.find('## 17. 智能语音交互系统')
    ch18_start = content.find('## 18. 性能设计与优化')

    if ch15_end == -1 or ch16_start == -1 or ch17_start == -1 or ch18_start == -1:
        print(f"章节位置: 15.12={ch15_end}, 16={ch16_start}, 17={ch17_start}, 18={ch18_start}")
        print("❌ 未找到所有章节位置")
        return

    # 当前顺序：15.12(引用) -> 17(语音) -> 开场风格 -> 16(自学习) -> 18(性能)
    # 目标顺序：15.12(引用) -> 16(自学习) -> 17(语音) -> 18(性能)

    # 找到"开场风格"等内容
    style_section_start = content.find('## 开场风格')
    style_section_end = content.find('## 16. 自学习与协同学习系统')

    if style_section_start == -1:
        print("❌ 未找到开场风格章节")
        return

    # 提取各部分内容
    # Part 1: 从开头到15.12引用结束（到第17章语音系统开始之前）
    part1_end = ch17_start
    part1 = content[:part1_end]

    # Part 2: 第17章语音系统内容
    # 找到语音系统结束位置（"开场风格"之前）
    voice_end = style_section_start
    part_voice = content[ch17_start:voice_end]

    # Part 3: 开场风格等内容（如果有的话）
    # 这些看起来是混进来的内容，应该检查是否属于语音反馈系统的一部分
    part_style = content[style_section_start:ch16_start]

    # Part 4: 第16章自学习系统
    part_16 = content[ch16_start:ch18_start]

    # Part 5: 第18章及之后
    part_rest = content[ch18_start:]

    print(f"Part 1 (到15.12引用): {len(part1)} 字符")
    print(f"Part Voice (17章): {len(part_voice)} 字符")
    print(f"Part Style (开场风格等): {len(part_style)} 字符")
    print(f"Part 16 (自学习): {len(part_16)} 字符")
    print(f"Part Rest (18章及之后): {len(part_rest)} 字符")

    # 检查开场风格内容是否属于语音反馈系统
    # 如果是，则应该保留在语音章节中
    # 从内容来看，这是17.10.7的一部分

    # 重新组装：Part1 + 16章 + 语音章节(包含开场风格) + 18章及之后
    # 但需要调整章节编号

    # 方案：16章保持不变，17章(语音)需要移到16章之后
    # 首先把16章的内容移到15.12引用之后

    # 重新分析：
    # 1. 找到15.12引用内容的结束位置
    ref_end_marker = '''本节内容包括：
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

    ref_end = content.find(ref_end_marker)
    if ref_end == -1:
        print("❌ 未找到引用结束标记")
        return

    ref_end = ref_end + len(ref_end_marker)

    # 新的组装顺序：
    # 1. 开头到15.12引用结束
    # 2. 16章自学习
    # 3. 17章语音（包含开场风格等内容）
    # 4. 18章及之后

    new_content = content[:ref_end] + part_16 + part_voice + part_style + part_rest

    # 保存
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(new_content)

    print("✅ 章节顺序已修复")

if __name__ == '__main__':
    main()
