# -*- coding: utf-8 -*-
"""
修复所有章节编号引用错误

正确的章节映射：
- 第15章: 技术架构设计
- 第16章: 智能化技术方案
- 第17章: 自学习与协同学习系统
- 第18章: 智能语音交互系统
"""

def main():
    filepath = 'd:/code/ai-bookkeeping/docs/design/app_v2_design.md'

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    changes = 0

    # 修复列表
    replacements = [
        # 第10章中的引用错误
        ('第15章"智能化技术方案"', '第16章"智能化技术方案"'),
        ('第15章: 智能化技术方案', '第16章: 智能化技术方案'),

        # 第14章标题错误
        ('第15章 地理位置智能化应用', '第14章 地理位置智能化应用'),

        # 自学习章节引用错误（第17章而非16章）
        ('**第16章 自学习与协同学习系统**', '**第17章 自学习与协同学习系统**'),
        ('第16章 自学习与协同学习系统', '第17章 自学习与协同学习系统'),
        ('第16章自学习', '第17章自学习'),

        # 18章架构图中的引用
        ('│ 16. 自学习系统   │', '│ 17. 自学习系统   │'),
        ('│ 15. 智能化方案   │', '│ 16. 智能化方案   │'),

        # 其他可能的错误格式
        ('第15章 智能化方案', '第16章 智能化方案'),
        ('第15章智能化', '第16章智能化'),
    ]

    for old, new in replacements:
        if old in content:
            count = content.count(old)
            content = content.replace(old, new)
            print(f"✓ 替换 {count} 处: '{old}' → '{new}'")
            changes += count

    if changes > 0:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"\n===== 章节编号修复完成，共 {changes} 处 =====")
    else:
        print("\n未找到需要修复的内容")

    return changes

if __name__ == '__main__':
    main()
