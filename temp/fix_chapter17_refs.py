# -*- coding: utf-8 -*-
"""
修复第17章关系图中的章节编号错误
"""

def main():
    filepath = 'd:/code/ai-bookkeeping/docs/design/app_v2_design.md'

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    changes = 0

    # 修复1: 17章关系图中的"16. 自学习"改为"17. 自学习"
    old_text1 = '│   16. 自学习与协同学习   │'
    new_text1 = '│   17. 自学习与协同学习   │'

    if old_text1 in content:
        content = content.replace(old_text1, new_text1)
        print("✓ 修复1: 自学习章节号16→17")
        changes += 1

    # 修复2: "15. 智能分类系统"改为"16. 智能分类系统"
    old_text2 = '│ 15. 智能分类系统 │'
    new_text2 = '│ 16. 智能分类系统 │'

    if old_text2 in content:
        content = content.replace(old_text2, new_text2)
        print("✓ 修复2: 智能分类章节号15→16")
        changes += 1

    # 修复3: "17. 语音交互系统"改为"18. 语音交互系统"
    old_text3 = '│ 17. 语音交互系统 │'
    new_text3 = '│ 18. 语音交互系统 │'

    if old_text3 in content:
        content = content.replace(old_text3, new_text3)
        print("✓ 修复3: 语音交互章节号17→18")
        changes += 1

    if changes > 0:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"\n===== 章节编号修复完成，共 {changes} 处 =====")
    else:
        print("\n未找到目标位置或已修复")

    return changes

if __name__ == '__main__':
    main()
