# -*- coding: utf-8 -*-
"""
修正第2章2.3核心价值主张的说明
"""

def main():
    filepath = 'd:/code/ai-bookkeeping/docs/design/app_v2_design.md'

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    changes = 0

    old_text = '''**核心差异化**：钱龄分析 + 零基预算 是我们区别于其他记账应用的核心竞争力，也是产品价值的根基。

**支撑能力**：习惯培养、智能伙伴、极致体验共同支撑核心功能的用户价值实现。

**扩展服务**：家庭账本、位置智能等是为不同场景用户提供的增值服务。'''

    new_text = '''**层次说明：**

| 层次 | 内容 | 说明 |
|------|------|------|
| **核心目标** | 培养良好金融习惯 | 产品存在的根本意义 |
| **理论基础** | 钱龄分析 + 零基预算 | 用户按此管钱，财务会变健康 |
| **实现手段** | 全智能化 + 极致体验 | 降低门槛，让用户更易接受 |
| **扩展服务** | 家庭账本、位置智能等 | 为不同场景提供增值服务 |'''

    if old_text in content:
        content = content.replace(old_text, new_text)
        print("OK: Updated 2.3 层次说明")
        changes += 1

    if changes > 0:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"\n===== Chapter 2.3 fix done, {changes} changes =====")
    else:
        print("\nNo changes needed")

    return changes

if __name__ == '__main__':
    main()
