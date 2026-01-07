# -*- coding: utf-8 -*-
"""
在15.12.0系统架构全景图之后插入语音配置和操作适配性分析表格
"""

def main():
    # 读取主文档
    with open('d:/code/ai-bookkeeping/docs/design/app_v2_design.md', 'r', encoding='utf-8') as f:
        content = f.read()

    # 读取分析表格内容
    with open('d:/code/ai-bookkeeping/temp/voice_analysis_tables.md', 'r', encoding='utf-8') as f:
        analysis_content = f.read()

    # 查找插入点：在 "#### 15.12.1 意图识别引擎" 之前
    insert_marker = '#### 15.12.1 意图识别引擎'

    insert_idx = content.find(insert_marker)
    if insert_idx == -1:
        print(f"Error: Cannot find marker '{insert_marker}'")
        return

    print(f"Found insert marker at position: {insert_idx}")

    # 构建新内容
    before = content[:insert_idx].rstrip()
    after = content[insert_idx:]

    new_content = before + '\n\n' + analysis_content.strip() + '\n\n' + after

    # 写入文件
    with open('d:/code/ai-bookkeeping/docs/design/app_v2_design.md', 'w', encoding='utf-8') as f:
        f.write(new_content)

    print('Successfully inserted voice analysis tables!')
    print(f'Old document size: {len(content)} characters')
    print(f'New document size: {len(new_content)} characters')
    print(f'Size change: {len(new_content) - len(content):+d} characters')

if __name__ == '__main__':
    main()
