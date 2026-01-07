# -*- coding: utf-8 -*-
"""
更新目录，添加第29章条目
"""

def main():
    filepath = 'd:/code/ai-bookkeeping/docs/design/app_v2_design.md'

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # 找到第28章目录项并在其后添加第29章
    old_toc = '28. [用户口碑与NPS提升设计](#28-用户口碑与nps提升设计)\n\n>'
    new_toc = '28. [用户口碑与NPS提升设计](#28-用户口碑与nps提升设计)\n29. [低成本获客与自然增长设计](#29-低成本获客与自然增长设计)\n\n>'

    if old_toc in content:
        content = content.replace(old_toc, new_toc)
        print("已在目录中添加第29章条目")
    else:
        print("未找到目标位置")

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

    print("目录更新完成")

if __name__ == '__main__':
    main()
