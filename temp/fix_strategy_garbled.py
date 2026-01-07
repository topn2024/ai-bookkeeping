# -*- coding: utf-8 -*-
"""
修复战略分析报告中的乱码字符
"""

def main():
    filepath = 'd:/code/ai-bookkeeping/docs/AI智能记账2.0战略分析报告（五看三定）.md'

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # 乱码修复映射
    fixes = [
        # 行15: 看机会
        ('看机���', '看机会'),
        # 行81: 数据来源
        ('数���来源', '数据来源'),
        # 行133: 发展阶段
        ('发���阶段', '发展阶段'),
        # 行135: LLM
        ('模型��LLM', '模型（LLM'),
        # 行186: 执行
        ('执���环节', '执行环节'),
        # 行332: 锦上添花
        ('锦���添花', '锦上添花'),
        # 行393: 规划
        ('规���）', '规划）'),
        # 行496: 记账
        ('记账 ���', '记账 |'),
        # 行512: 增值服务
        ('��值服务', '增值服务'),
        # 行583: 多模态
        ('多模��识别', '多模态识别'),
        # 行649: 三星
        ('★��★', '★★★'),
        # 行650: 技术
        ('技��壁垒', '技术壁垒'),
        # 行885: 大众
        ('大众��', '大众 |'),
        # 行887: 左边界
        ('��─────────┘', '└─────────┘'),
        # 行1030: 接入
        ('接���10', '接入10'),
        # 行1091: 资源
        ('资��调配', '资源调配'),
        # 行1102: 以...为
        ('技术���核心', '技术为核心'),
        # ASCII art 边框修复
        ('──────��──────', '────────────'),
        ('───────��─────', '────────────'),
        ('────────��────', '────────────'),
        ('─────────��───', '────────────'),
        ('──────────��──', '────────────'),
        ('───────────��─', '────────────'),
        ('────────────��', '─────────────'),
        ('��───────────', '─────────────'),
    ]

    changes = 0
    for old, new in fixes:
        if old in content:
            content = content.replace(old, new)
            print(f"已修复: '{old}' -> '{new}'")
            changes += 1

    # 通用修复：替换所有单独的乱码字符（被其他字符包围的�）
    import re
    # 修复边框中的乱码
    content = re.sub(r'─+�+─+', lambda m: '─' * len(m.group(0).replace('�', '')), content)

    if changes > 0:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"\n已完成 {changes} 处乱码修复")
    else:
        print("\n未发现可修复的乱码")

    # 再次检查
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    remaining = content.count('�')
    if remaining > 0:
        print(f"\n警告：仍有 {remaining} 个乱码字符未修复")
        lines = content.split('\n')
        for i, line in enumerate(lines, 1):
            if '�' in line:
                print(f"  行 {i}: {line[:80]}...")

if __name__ == '__main__':
    main()
