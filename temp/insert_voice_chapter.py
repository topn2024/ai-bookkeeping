# -*- coding: utf-8 -*-
"""
将智能语音交互系统章节插入到设计文档中
"""

def main():
    # 读取主文档
    with open('d:/code/ai-bookkeeping/docs/design/app_v2_design.md', 'r', encoding='utf-8') as f:
        content = f.read()

    # 读取新章节内容
    with open('d:/code/ai-bookkeeping/temp/voice_chapter_content.md', 'r', encoding='utf-8') as f:
        new_chapter = f.read()

    # 查找插入点：在 "## 16. 性能设计与优化" 之前
    insert_marker = '## 16. 性能设计与优化'

    if insert_marker not in content:
        print(f"Error: Cannot find marker '{insert_marker}'")
        return

    # 在标记前插入新章节
    # 需要在 --- 分隔线后插入
    parts = content.split(insert_marker)

    if len(parts) != 2:
        print(f"Error: Expected 2 parts, got {len(parts)}")
        return

    # 构建新内容
    # parts[0] 包含到第15章结束的内容（包括 --- 分隔线）
    # 我们在分隔线后添加新章节

    # 清理parts[0]末尾的空行和分隔线，重新添加
    before = parts[0].rstrip()

    # 确保章节内容不以空行开头
    new_chapter_clean = new_chapter.strip()

    # 构建最终内容
    new_content = before + '\n\n---\n\n' + new_chapter_clean + '\n\n---\n\n' + insert_marker + parts[1]

    # 写入文件
    with open('d:/code/ai-bookkeeping/docs/design/app_v2_design.md', 'w', encoding='utf-8') as f:
        f.write(new_content)

    print('Successfully inserted voice interaction chapter!')
    print(f'New document size: {len(new_content)} characters')

if __name__ == '__main__':
    main()
