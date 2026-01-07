# -*- coding: utf-8 -*-
"""
修复战略分析报告中剩余的乱码字符
"""

def main():
    filepath = 'd:/code/ai-bookkeeping/docs/AI智能记账2.0战略分析报告（五看三定）.md'

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # 直接替换所有乱码字符为空或合适的字符
    # 先尝试通用替换
    old_count = content.count('�')
    print(f"修复前乱码数量: {old_count}")

    # 替换边框末尾的乱码
    content = content.replace('│   ��\n│  │', '│   │\n│  │')
    content = content.replace('│   ��', '│   │')

    # 替换其他可能的乱码
    content = content.replace('��', '')

    new_count = content.count('�')
    print(f"修复后乱码数量: {new_count}")

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

    if old_count > new_count:
        print(f"已修复 {old_count - new_count} 处乱码")

    # 验证
    with open(filepath, 'r', encoding='utf-8') as f:
        final_content = f.read()

    final_count = final_content.count('�')
    if final_count > 0:
        print(f"\n仍有 {final_count} 处乱码:")
        lines = final_content.split('\n')
        for i, line in enumerate(lines, 1):
            if '�' in line:
                print(f"  行 {i}: {repr(line[:80])}")
    else:
        print("\n所有乱码已修复!")

if __name__ == '__main__':
    main()
