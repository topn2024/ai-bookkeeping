# -*- coding: utf-8 -*-
"""
修复第28章剩余的章节编号问题
"""

def main():
    filepath = 'd:/code/ai-bookkeeping/docs/design/app_v2_design.md'

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    changes = 0

    # 按顺序重新编号
    # 28.7 贬损者挽回策略 保持
    # 28.7 无障碍设计集成 -> 28.7.4 无障碍设计集成 (作为28.7的子节)
    # 或者把"无障碍设计集成"作为独立章节放到合适位置

    # 方案：把"### 28.7 无障碍设计集成"改为"#### 28.7.4 无障碍设计集成"（作为贬损者挽回策略的子节）
    old_section = '### 28.7 无障碍设计集成'
    new_section = '#### 28.7.4 无障碍设计集成'
    if old_section in content:
        content = content.replace(old_section, new_section)
        print(f"Fix: {old_section} -> {new_section}")
        changes += 1

    # 写入文件
    if changes > 0:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"\n===== Fix done, {changes} changes =====")
    else:
        print("\nNo changes needed")

    return changes

if __name__ == '__main__':
    main()
