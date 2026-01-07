# -*- coding: utf-8 -*-
"""
修复文档中的乱码字符
"""

def main():
    filepath = 'd:/code/ai-bookkeeping/docs/design/app_v2_design.md'

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # 修复乱码
    fixes = [
        ('相关章���', '相关章节'),
        ('与���他系统', '与其他系统'),
    ]

    changes = 0
    for old, new in fixes:
        if old in content:
            content = content.replace(old, new)
            print(f"已修复: '{old}' -> '{new}'")
            changes += 1

    if changes > 0:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"\n已完成 {changes} 处乱码修复")
    else:
        print("未发现需要修复的乱码")

if __name__ == '__main__':
    main()
