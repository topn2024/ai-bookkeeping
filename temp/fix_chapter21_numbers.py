# -*- coding: utf-8 -*-
"""
修复第21章章节编号错误
"""

def main():
    filepath = 'd:/code/ai-bookkeeping/docs/design/app_v2_design.md'

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    changes = 0

    # 修复 24.0.1 -> 21.0.1
    if '#### 24.0.1 国际化设计原则' in content:
        content = content.replace('#### 24.0.1 国际化设计原则', '#### 21.0.1 国际化设计原则')
        print("Fix 1: 24.0.1 -> 21.0.1")
        changes += 1

    # 修复 24.0.2 -> 21.0.2
    if '#### 24.0.2 2.0版本国际化目标' in content:
        content = content.replace('#### 24.0.2 2.0版本国际化目标', '#### 21.0.2 2.0版本国际化目标')
        print("Fix 2: 24.0.2 -> 21.0.2")
        changes += 1

    if changes > 0:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Done: {changes} fixes")

    return changes

if __name__ == '__main__':
    main()
