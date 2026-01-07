# -*- coding: utf-8 -*-
"""
更新第26章版本迁移策略 - 第三部分
添加26.5.7~26.5.9新系统集成代码和26.6目标达成检测
"""
import re

def update_chapter26_part3():
    with open('D:/code/ai-bookkeeping/docs/design/app_v2_design.md', 'r', encoding='utf-8') as f:
        content = f.read()

    # 读取新内容文件
    with open('D:/code/ai-bookkeeping/temp/chapter26_new_content.md', 'r', encoding='utf-8') as f:
        new_integrations = f.read()

    # 找到插入位置：在26.5.6同步系统集成代码后面，章节结束之前
    # 查找 "---\n\n\n---\n\n## 27" 的位置（中间有3个换行符）
    insert_marker = '---\n\n\n---\n\n## 27. 实施路线图'

    if insert_marker in content:
        content = content.replace(insert_marker, new_integrations + '\n\n## 27. 实施路线图')
        print("Phase 3: Added 26.5.7-26.5.9 new system integrations and 26.6 goal validation")
    else:
        print("ERROR: Could not find insertion point")
        return

    with open('D:/code/ai-bookkeeping/docs/design/app_v2_design.md', 'w', encoding='utf-8') as f:
        f.write(content)

    print("\nPart 3 updates completed!")

if __name__ == '__main__':
    update_chapter26_part3()
