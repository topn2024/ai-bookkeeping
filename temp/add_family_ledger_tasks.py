# -*- coding: utf-8 -*-
"""
在第27章实施路线图中添加第13章（家庭账本与多成员管理系统）的实施任务
插入位置：阶段五（体验设计优化）之后，作为新的阶段5.5或合并到适当位置
"""

def main():
    filepath = 'd:/code/ai-bookkeeping/docs/design/app_v2_design.md'

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # 在阶段五末尾（"#### 阶段六"之前）添加家庭账本相关任务
    # 家庭账本是社交协作功能，放在体验设计之后、伙伴化设计之前比较合适
    old_text = '''- [ ] 实现渐进式复杂度功能展示

#### 阶段六：伙伴化与情感设计 (RC-2)'''

    new_text = '''- [ ] 实现渐进式复杂度功能展示

**家庭账本与多成员管理（第13章）**
- [ ] 实现 Ledger 账本数据模型（个人/家庭/情侣/群组/专项）
- [ ] 实现 LedgerService 账本管理服务
- [ ] 实现 MemberService 成员管理服务
- [ ] 实现邀请码生成与验证机制
- [ ] 实现二维码邀请功能
- [ ] 实现成员角色权限系统（所有者/管理员/成员/只读）
- [ ] 实现家庭预算分配与配额管理
- [ ] 实现 SplitService AA分摊服务
- [ ] 实现多种分摊策略（均摊/按比例/自定义）
- [ ] 实现分摊结算与提醒功能
- [ ] 实现家庭账本同步服务 (FamilyLedgerSyncService)
- [ ] 实现账本切换与数据隔离
- [ ] 实现家庭成员贡献分析
- [ ] 实现家庭报表与趋势分析
- [ ] 实现隐私可见性控制（账目对成员的可见性）

#### 阶段六：伙伴化与情感设计 (RC-2)'''

    if old_text in content:
        if '家庭账本与多成员管理（第13章）' not in content:
            content = content.replace(old_text, new_text)
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            print("已在阶段五末尾添加第13章（家庭账本与多成员管理系统）实施任务")
        else:
            print("第13章实施任务已存在，无需重复添加")
    else:
        print("未找到目标位置")

if __name__ == '__main__':
    main()
