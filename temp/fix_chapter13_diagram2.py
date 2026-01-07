# -*- coding: utf-8 -*-
"""
修复第13章13.0.3与其他系统的关系图 - 使用行号定位
"""

def main():
    filepath = 'd:/code/ai-bookkeeping/docs/design/app_v2_design.md'

    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    # 找到 "### 13.1 账本体系��构" 的位置
    insert_line = None
    for i, line in enumerate(lines):
        if '### 13.1 账本体系架构' in line:
            insert_line = i
            break

    if insert_line is None:
        print("未找到目标位置")
        return 0

    # 向前查找 ``` 结束标记
    code_end_line = None
    for i in range(insert_line - 1, max(0, insert_line - 10), -1):
        if lines[i].strip() == '```':
            code_end_line = i
            break

    if code_end_line is None:
        print("未找到代码块结束标记")
        return 0

    # 向前查找最后一个图表边框行
    border_line = None
    for i in range(code_end_line - 1, max(0, code_end_line - 5), -1):
        if '└' in lines[i] and '┘' in lines[i]:
            border_line = i
            break

    if border_line is None:
        print("未找��图表边框")
        return 0

    # 在边框行之前插入新内容
    new_content = '''│                                                                              │
│  ════════════════════════════════════════════════════════════════════════   │
│                           2.0新增协作模块                                     │
│  ════════════════════════════════════════════════════════════════════════   │
│                                                                              │
│   ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐     │
│   │18.语音   │  │17.自学习 │  │14.位置   │  │10.AI识别 │  │28-29.增长│     │
│   │  交互    │  │  系统    │  │  智能    │  │  系统    │  │  体系    │     │
│   │ ──────── │  │ ──────── │  │ ──────── │  │ ──────── │  │ ──────── │     │
│   │"家庭支出│  │家庭消费  │  │家庭成员  │  │票据分摊  │  │家庭裂变  │     │
│   │ 多少"   │  │模式学习  │  │位置共享  │  │智能识别  │  │邀请激励  │     │
│   └──────────┘  └──────────┘  └──────────┘  └──────────┘  └──────────┘     │
'''

    # 检查是否已经添加过
    if '2.0新增协作模块' in lines[border_line - 5]:
        print("内容已存在，无需修改")
        return 0

    # 插入新内容（在倒数第二行之前，即边框行之前）
    lines.insert(border_line, new_content)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.writelines(lines)

    print("✓ 成功在13.0.3图表中添加2.0新增协作模块")
    return 1

if __name__ == '__main__':
    main()
