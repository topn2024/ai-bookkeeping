# -*- coding: utf-8 -*-
"""
修正第16章系统集成图中的章节引用
"""

def main():
    filepath = 'd:/code/ai-bookkeeping/docs/design/app_v2_design.md'

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    changes = 0

    # 修正习惯培养章节号 (9章→11章)
    old1 = '│ │习惯培养│  │数据导入   │  │'
    new1 = '│ │习惯培养│  │账单导入   │  │'
    if old1 in content:
        content = content.replace(old1, new1)
        print(f"Fix: 数据导入->账单导入")
        changes += 1

    old2 = '│ │ (9章) │  │  (11章)  │  │'
    new2 = '│ │(11章) │  │  (12章)  │  │'
    if old2 in content:
        content = content.replace(old2, new2)
        print(f"Fix: (9章)->(11章), (11章)->(12章)")
        changes += 1

    # 修正伙伴化章节号 (4章→6章)
    old3 = '│  (4章)   │     │'
    new3 = '│  (6章)   │     │'
    if old3 in content:
        content = content.replace(old3, new3)
        print(f"Fix: (4章)->(6章)")
        changes += 1

    # 写入文件
    if changes > 0:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"\n===== Chapter 16 refs fixed, {changes} changes =====")
    else:
        print("\nNo changes needed")

    return changes

if __name__ == '__main__':
    main()
