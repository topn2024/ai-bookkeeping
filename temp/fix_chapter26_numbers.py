# -*- coding: utf-8 -*-
"""
修正第26章版本迁移策略中的章节编号错误
5.0.2 -> 26.0.2
5.0.3 -> 26.0.3
"""

def main():
    filepath = 'd:/code/ai-bookkeeping/docs/design/app_v2_design.md'

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    changes = 0

    # 需要在第26章上下文中修复的编号
    # 定位第26章的内容区域
    chapter26_start = content.find('## 26. 版本迁移策略')
    chapter27_start = content.find('## 27.')

    if chapter26_start == -1:
        print("Chapter 26 not found")
        return 0

    if chapter27_start == -1:
        chapter27_start = len(content)

    # 提取第26章内容
    before_26 = content[:chapter26_start]
    chapter26 = content[chapter26_start:chapter27_start]
    after_26 = content[chapter27_start:]

    # 在第26章中修复编号
    fixes = [
        ('#### 5.0.2 设计理念', '#### 26.0.2 设计理念'),
        ('#### 5.0.3 与2.0其他系统的协同关系图', '#### 26.0.3 与2.0其他系统的协同关系图'),
    ]

    for old, new in fixes:
        if old in chapter26:
            chapter26 = chapter26.replace(old, new)
            print(f"Fix: {old} -> {new}")
            changes += 1

    if changes > 0:
        content = before_26 + chapter26 + after_26
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"\n===== Chapter 26 number fixes done, {changes} changes =====")
    else:
        print("\nNo changes needed")

    return changes

if __name__ == '__main__':
    main()
