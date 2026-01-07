# -*- coding: utf-8 -*-
"""
处理第2章2.6和2.7内容：
1. 删除2.6（与1.5、1.6重复）
2. 将2.7目标检测移动到第1章作为1.7
"""

def main():
    filepath = 'd:/code/ai-bookkeeping/docs/design/app_v2_design.md'

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    changes = 0

    # ========== Step 1: 提取2.7目标达成检测内容 ==========
    lines = content.split('\n')

    # 找到2.7的位置
    start_27 = -1
    end_27 = -1
    for i, line in enumerate(lines):
        if '### 2.7 目标达成检测' in line:
            start_27 = i
        if start_27 > 0 and line.strip() == '---' and i > start_27:
            end_27 = i
            break

    if start_27 > 0 and end_27 > start_27:
        # 提取2.7内容，改为1.7
        section_27_lines = lines[start_27:end_27]
        section_17 = '\n'.join(section_27_lines).replace('### 2.7 目标达成检测', '### 1.7 目标达成检测')
        print(f"OK: Extracted 2.7 content (lines {start_27}-{end_27})")
    else:
        print("WARNING: Could not find 2.7 section")
        return 0

    # ========== Step 2: 删除2.6和2.7（从---到下一个---） ==========
    # 找到2.6前面的---
    start_26_marker = -1
    for i, line in enumerate(lines):
        if '### 2.6 2.0版本新模块概览' in line:
            # 往前找---
            for j in range(i-1, max(0, i-5), -1):
                if lines[j].strip() == '---':
                    start_26_marker = j
                    break
            break

    if start_26_marker > 0 and end_27 > start_26_marker:
        # 删除从---到2.7结尾的---（但保留最后的---）
        new_lines = lines[:start_26_marker] + lines[end_27:]
        content = '\n'.join(new_lines)
        print(f"OK: Removed 2.6 and 2.7 sections (lines {start_26_marker}-{end_27})")
        changes += 1
    else:
        print(f"WARNING: Could not locate sections to remove (start={start_26_marker}, end={end_27})")
        return 0

    # ========== Step 3: 在1.6之后插入1.7 ==========
    # 找到1.6章节结尾（2.0开头之前或第二部分之前）
    lines = content.split('\n')
    insert_pos = -1

    for i, line in enumerate(lines):
        if '### 1.6 文档结构导航' in line:
            # 从这里往后找，找到下一个### 2.或# 第二部分
            for j in range(i+1, len(lines)):
                if lines[j].startswith('## ') or lines[j].startswith('# 第'):
                    insert_pos = j
                    break
            break

    if insert_pos > 0:
        # 在insert_pos之前插入1.7
        new_lines = lines[:insert_pos] + ['', section_17, ''] + lines[insert_pos:]
        content = '\n'.join(new_lines)
        print(f"OK: Inserted 1.7 at line {insert_pos}")
        changes += 1
    else:
        print("WARNING: Could not find position to insert 1.7")

    # 写入文件
    if changes > 0:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"\n===== Relocation done, {changes} changes =====")
    else:
        print("\nNo changes made")

    return changes

if __name__ == '__main__':
    main()
