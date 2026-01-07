# -*- coding: utf-8 -*-
"""
更新目录，添加第28章条目
"""

def main():
    filepath = 'd:/code/ai-bookkeeping/docs/design/app_v2_design.md'

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # 找到第27章目录项并在其后添加第28章
    old_toc = '''27. [实施路线图](#27-实施路线图)

> **相关文档**'''

    new_toc = '''27. [实施路线图](#27-实施路线图)

**第八部分：用户增长**

28. [用户口碑与NPS提升设计](#28-用户口碑与nps提升设计)

> **相关文档**'''

    if old_toc in content:
        content = content.replace(old_toc, new_toc)
        print("已在目录中添加第28章条目")
    else:
        print("未找到目标位置，尝试其他方式...")
        # 尝试另一种方式
        old_toc2 = '27. [实施路线图](#27-实施路线图)\n\n>'
        new_toc2 = '27. [实施路线图](#27-实施路线图)\n\n**第八部分：用户增长**\n\n28. [用户口碑与NPS提升设计](#28-用户口碑与nps提升设计)\n\n>'
        if old_toc2 in content:
            content = content.replace(old_toc2, new_toc2)
            print("已在目录中添加第28章条目（方式2）")
        else:
            print("未能找到合适的插入位置")

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

    print("目录更新完成")

if __name__ == '__main__':
    main()
