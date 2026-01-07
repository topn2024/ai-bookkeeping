# -*- coding: utf-8 -*-
"""
替换语音配置和语音导航模块为扩展版本
"""

def main():
    # 读取主文档
    with open('d:/code/ai-bookkeeping/docs/design/app_v2_design.md', 'r', encoding='utf-8') as f:
        content = f.read()

    # 读取扩展内容
    with open('d:/code/ai-bookkeeping/temp/expanded_voice_modules.md', 'r', encoding='utf-8') as f:
        new_modules = f.read()

    # 查找替换范围
    # 开始标记：#### 15.12.3 智能语音配置模块
    # 结束标记：#### 15.12.5 智能语音查询模块

    start_marker = '#### 15.12.3 智能语音配置模块'
    end_marker = '#### 15.12.5 智能语音查询模块'

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

    # 构建新内容
    before = content[:start_idx]
    after = content[end_idx:]  # 包含 end_marker 及之后的内容

    new_content = before + new_modules.strip() + '\n\n' + after

    # 写入文件
    with open('d:/code/ai-bookkeeping/docs/design/app_v2_design.md', 'w', encoding='utf-8') as f:
        f.write(new_content)

    print('Successfully replaced voice configuration and navigation modules!')
    print(f'Old document size: {len(content)} characters')
    print(f'New document size: {len(new_content)} characters')
    print(f'Size change: {len(new_content) - len(content):+d} characters')

if __name__ == '__main__':
    main()
