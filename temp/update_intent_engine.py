# -*- coding: utf-8 -*-
"""
更新15.12.1意图识别引擎章节，扩展意图类型和匹配规则
"""

def main():
    # 读取主文档
    with open('d:/code/ai-bookkeeping/docs/design/app_v2_design.md', 'r', encoding='utf-8') as f:
        content = f.read()

    # 读取更新后的内容
    with open('d:/code/ai-bookkeeping/temp/updated_intent_engine.md', 'r', encoding='utf-8') as f:
        new_content = f.read()

    # 查找替换范围
    # 开始标记：#### 15.12.1 意图识别引擎
    # 结束标记：#### 15.12.2 语音记账模块

    start_marker = '#### 15.12.1 意图识别引擎'
    end_marker = '#### 15.12.2 语音记账模块'

    start_idx = content.find(start_marker)
    end_idx = content.find(end_marker)

    if start_idx == -1:
        print(f"Error: Cannot find start marker '{start_marker}'")
        return

    if end_idx == -1:
        print(f"Error: Cannot find end marker '{end_marker}'")
        return

    print(f"Found start marker at position: {start_idx}")
    print(f"Found end marker at position: {end_idx}")
    print(f"Content to replace: {end_idx - start_idx} characters")

    # 构建新内容
    before = content[:start_idx]
    after = content[end_idx:]  # 包含 end_marker 及之后的内容

    new_doc = before + new_content.strip() + '\n\n' + after

    # 写入文件
    with open('d:/code/ai-bookkeeping/docs/design/app_v2_design.md', 'w', encoding='utf-8') as f:
        f.write(new_doc)

    print('Successfully updated intent recognition engine chapter!')
    print(f'Old document size: {len(content)} characters')
    print(f'New document size: {len(new_doc)} characters')
    print(f'Size change: {len(new_doc) - len(content):+d} characters')

if __name__ == '__main__':
    main()
