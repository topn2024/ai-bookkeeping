# -*- coding: utf-8 -*-
"""
清理 __TEMP__ 标记
"""

def main():
    filepath = 'd:/code/ai-bookkeeping/docs/design/app_v2_design.md'

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    changes = 0

    # 清理所有 __TEMP__ 标记
    old_text = '__TEMP__'
    if old_text in content:
        count = content.count(old_text)
        content = content.replace(old_text, '')
        print(f"✓ 清理 {count} 处 __TEMP__ 标记")
        changes = count

    if changes > 0:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"\n===== 标记清理完成 =====")
    else:
        print("\n未找到需要清理的标记")

    return changes

if __name__ == '__main__':
    main()
