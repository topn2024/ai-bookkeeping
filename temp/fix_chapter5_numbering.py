# -*- coding: utf-8 -*-
"""
修复第5章无障碍设计中的编号错误
26.0.x -> 5.0.x
"""

def fix_chapter5_numbering():
    with open('D:/code/ai-bookkeeping/docs/design/app_v2_design.md', 'r', encoding='utf-8') as f:
        content = f.read()

    # 修复第5章中的错误编号
    # 这些错误出现在第5章无障碍设计中
    fixes = [
        ('#### 26.0.2 设计理念\n\n| 设计维度 | 在无障碍设计的体现',
         '#### 5.0.2 设计理念\n\n| 设计维度 | 在无障碍设计的体现'),
        ('#### 26.0.3 与2.0其他系统的协同关系图\n\n```\n┌─────────────────────────────────────────────────────────────────────────────────┐\n│                        无障碍设计 - 系统协同全景图',
         '#### 5.0.3 与2.0其他系统的协同关系图\n\n```\n┌─────────────────────────────────────────────────────────────────────────────────┐\n│                        无障碍设计 - 系统协同全景图'),
    ]

    for old, new in fixes:
        if old in content:
            content = content.replace(old, new)
            print(f"Fixed: {old[:50]}...")

    with open('D:/code/ai-bookkeeping/docs/design/app_v2_design.md', 'w', encoding='utf-8') as f:
        f.write(content)

    print("\nChapter 5 numbering fixed!")

if __name__ == '__main__':
    fix_chapter5_numbering()
