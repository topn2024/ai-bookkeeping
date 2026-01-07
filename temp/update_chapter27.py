# -*- coding: utf-8 -*-
"""
更新第27章实施路线图内容
添加27.0设计原则回顾、27.3里程碑与验收标准、27.4目标达成检测
"""
import re

def update_chapter27():
    with open('D:/code/ai-bookkeeping/docs/design/app_v2_design.md', 'r', encoding='utf-8') as f:
        content = f.read()

    with open('D:/code/ai-bookkeeping/temp/chapter27_new_content.md', 'r', encoding='utf-8') as f:
        new_content = f.read()

    # 1. 找到第27章开始位置，替换整个27章开头部分（添加27.0节）
    old_chapter_start = '## 27. 实施路线图\n\n### 27.1 开发阶段'

    # 从新内容中提取27.0节（从开始到27.1之前）
    new_27_0_section = new_content.split('### 27.3 里程碑与验收标准')[0]

    # 构建新的章节开头
    new_chapter_start = new_27_0_section.rstrip() + '\n\n### 27.1 开发阶段'

    if old_chapter_start in content:
        content = content.replace(old_chapter_start, new_chapter_start)
        print("✓ 添加27.0设计原则回顾章节（27.0.1-27.0.4）")
    else:
        print("✗ 未找到第27章开始位置")
        return

    # 2. 在27.2任务清单之后添加27.3和27.4
    # 找到27.2结束后、第28章开始前的位置

    # 提取27.3和27.4内容
    new_27_3_4 = '### 27.3 里程碑与验收标准' + new_content.split('### 27.3 里程碑与验收标准')[1]
    new_27_3_4 = new_27_3_4.rstrip()

    # 找到插入点 - 在"## 28. 用户口碑与NPS提升设计"之前
    insert_marker = '---\n\n---\n\n## 28. 用户口碑与NPS提升设计'

    if insert_marker in content:
        # 检查是否已经添加过
        if '### 27.3 里程碑与验收标准' not in content:
            content = content.replace(
                insert_marker,
                new_27_3_4 + '\n\n---\n\n---\n\n## 28. 用户口碑与NPS提升设计'
            )
            print("✓ 添加27.3里程碑与验收标准")
            print("✓ 添加27.4目标达成检测")
        else:
            print("- 27.3/27.4已存在，跳过")
    else:
        # 尝试其他格式
        alt_marker = '---\n\n\n---\n\n## 28. 用户口碑与NPS提升设计'
        if alt_marker in content:
            if '### 27.3 里程碑与验收标准' not in content:
                content = content.replace(
                    alt_marker,
                    new_27_3_4 + '\n\n---\n\n\n---\n\n## 28. 用户口碑与NPS提升设计'
                )
                print("✓ 添加27.3里程碑与验收标准")
                print("✓ 添加27.4目标达成检测")
            else:
                print("- 27.3/27.4已存在，跳过")
        else:
            print("✗ 未找到插入点（第28章前）")

    with open('D:/code/ai-bookkeeping/docs/design/app_v2_design.md', 'w', encoding='utf-8') as f:
        f.write(content)

    print("\n第27章更新完成！")

if __name__ == '__main__':
    update_chapter27()
