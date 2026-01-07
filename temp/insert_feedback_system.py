# -*- coding: utf-8 -*-
"""
在15.12.9目标达成检测之后插入15.12.10智能语音反馈与客服系统
"""

def main():
    # 读取主文档
    with open('d:/code/ai-bookkeeping/docs/design/app_v2_design.md', 'r', encoding='utf-8') as f:
        content = f.read()

    # 读取新章节内容
    with open('d:/code/ai-bookkeeping/temp/voice_feedback_system.md', 'r', encoding='utf-8') as f:
        new_section = f.read()

    # 查找插入点：在 "## 16. 性能设计与优化" 之前
    insert_marker = '## 16. 性能设计与优化'

    insert_idx = content.find(insert_marker)
    if insert_idx == -1:
        print(f"Error: Cannot find marker '{insert_marker}'")
        return

    # 找到前面的 --- 分隔线
    # 从insert_idx往前找最近的---
    before_content = content[:insert_idx]
    last_separator_idx = before_content.rfind('---')

    if last_separator_idx == -1:
        print("Error: Cannot find separator '---' before chapter 16")
        return

    print(f"Found chapter 16 at position: {insert_idx}")
    print(f"Found separator at position: {last_separator_idx}")

    # 构建新内容
    # 在 --- 之前插入新章节
    before = content[:last_separator_idx].rstrip()
    after = content[last_separator_idx:]  # 包含 --- 和之后的内容

    new_content = before + '\n\n' + new_section.strip() + '\n\n' + after

    # 写入文件
    with open('d:/code/ai-bookkeeping/docs/design/app_v2_design.md', 'w', encoding='utf-8') as f:
        f.write(new_content)

    print('Successfully inserted voice feedback system section!')
    print(f'Old document size: {len(content)} characters')
    print(f'New document size: {len(new_content)} characters')
    print(f'Size change: {len(new_content) - len(content):+d} characters')

if __name__ == '__main__':
    main()
