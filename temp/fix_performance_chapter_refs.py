# -*- coding: utf-8 -*-
"""
修复第19章性能设计中的章节引用错误
以及第21章安全隐私中的错误
"""

def main():
    filepath = 'd:/code/ai-bookkeeping/docs/design/app_v2_design.md'

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    changes = 0

    # 修复列表
    replacements = [
        # 第19章图中的引用错误
        ('│  第15章     │  │  第15章     │', '│  第16章     │  │  第15章     │'),
        ('│  │  第15章     │  │  第15章     │    │', '│  │  第16章     │  │  第15章     │    │'),
        ('│  智能化     │  │  技术架构   │', '│  智能化     │  │  技术架构   │'),

        # 性能设计标题
        ('│   第17章        │', '│   第19章        │'),

        # 第21章标题错误
        ('│ 第21章   │  │ 第5章   │', '│ 第23章   │  │ 第25章  │'),
        ('│ 异常处理 │  │ 可观测性 │', '│ 异常处理 │  │ 可观测性 │'),

        # 可观测性是第25章
        ('第5章 可观测性', '第25章 可观测性'),
    ]

    for old, new in replacements:
        if old in content and old != new:
            count = content.count(old)
            content = content.replace(old, new)
            print(f"✓ 替换 {count} 处: '{old[:40]}...'")
            changes += count

    if changes > 0:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"\n===== 章节编号修复完成，共 {changes} 处 =====")
    else:
        print("\n未找到需要修复的内容（可能已经正确）")

    return changes

if __name__ == '__main__':
    main()
