# 发明专利申请

**发明名称**:基于债务收入比的智能债务管理和还款优化方法

**技术领域**:人工智能与财务管理技术领域

**申请人**:李北华

**发明人**:李北华

**申请日**:2026-1-18

---

## 说明书

### 发明名称

基于债务收入比的智能债务管理和还款优化方法

### 技术领域

[0001] 本发明涉及人工智能与财务管理技术领域,具体涉及一种基于债务收入比的智能债务管理和还款优化方法及系统,可应用于个人债务管理、信用卡还款、贷款优化等场景。

### 背景技术

[0002] 根据中国人民银行数据,截至2024年,中国信用卡用户超过7亿,人均持卡量2.1张,信用卡逾期半年未偿信贷总额超过900亿元。债务管理不当导致大量用户陷入债务困境,影响个人信用和生活质量。

[0003] **现有技术一(信用卡账单提醒)**:银行和第三方应用提供还款日期提醒。技术缺陷:(1)仅提醒还款日期,不提供还款策略;(2)无债务健康评估;(3)无还款优化建议;(4)无利息成本计算。

[0004] **现有技术二(债务计算器)**:部分网站提供债务计算工具。技术缺陷:(1)需要手动输入数据;(2)仅计算单笔债务;(3)无多债务优化策略;(4)无动态调整;(5)不考虑用户收入情况。

[0005] **现有技术三(财务规划软件)**:专业财务规划软件提供债务管理功能。技术缺陷:(1)操作复杂,学习成本高;(2)面向高净值人群;(3)缺乏智能还款策略;(4)无实时债务健康监控。

[0006] **现有技术四(学术研究)**:金融学领域提出"雪球还款法"(Debt Snowball)和"雪崩还款法"(Debt Avalanche)。技术缺陷:(1)仅停留在理论层面;(2)缺乏技术实现;(3)未考虑用户实际收入;(4)无动态优化。

[0007] 综上所述,现有技术存在以下共性技术问题:(1)缺乏债务健康量化评估;(2)无智能还款策略;(3)无多债务优化算法;(4)缺乏利息成本追踪;(5)不考虑用户收入能力。

### 发明内容

#### 发明目的

[0008] 本发明的目的在于提供一种基于债务收入比的智能债务管理和还款优化方法及系统,解决现有技术中缺乏健康评估、无智能策略、无优化算法等技术问题。

#### 技术方案

[0009] 本发明提出一种**健康评估 + 雪球雪崩 + 智能优化 + 利息追踪 + 动态调整**的五维债务管理系统,包括:

##### 核心技术方案一:债务健康评估

[0010] **债务数据结构**:
```
DebtRecord {
  id: UUID,
  user_id: String,
  debt_type: Enum,              // 类型:信用卡/消费贷/房贷/车贷
  creditor: String,             // 债权人
  principal: Decimal(18,2),     // 本金
  balance: Decimal(18,2),       // 当前余额
  interest_rate: Decimal(5,4),  // 年利率
  min_payment: Decimal(18,2),   // 最低还款额
  due_date: Date,               // 还款日期
  start_date: Date,             // 开始日期
  term_months: Int,             // 期限(月)
  monthly_payment: Decimal(18,2), // 月供
  total_interest: Decimal(18,2)   // 累计利息
}
```

[0011] **债务健康评估算法**:
```
算法1:债务健康等级评估
输入:债务列表 Debts, 月收入 MonthlyIncome
输出:健康等级 HealthLevel, 健康评分 HealthScore

评估维度:
1. 债务收入比(DTI)计算:
   - total_debt = Σ(debt.balance)
   - monthly_payment = Σ(debt.monthly_payment)
   - DTI = total_debt / MonthlyIncome
   - payment_ratio = monthly_payment / MonthlyIncome

2. 健康等级划分:
   - 健康(绿色):DTI ≤ 20%, payment_ratio ≤ 30%
   - 轻度负债(黄色):20% < DTI ≤ 30%, 30% < payment_ratio ≤ 40%
   - 中度负债(橙色):30% < DTI ≤ 40%, 40% < payment_ratio ≤ 50%
   - 重度负债(红色):40% < DTI ≤ 50%, 50% < payment_ratio ≤ 60%
   - 危险(深红):DTI > 50%, payment_ratio > 60%

3. 健康评分计算:
   - dti_score = max(0, 100 - DTI × 200)
   - payment_score = max(0, 100 - payment_ratio × 150)
   - interest_score = max(0, 100 - avg_interest_rate × 500)
   - HealthScore = 0.4 × dti_score +
                   0.4 × payment_score +
                   0.2 × interest_score

4. 风险预警:
   - if DTI > 40%: trigger_alert("债务负担过重")
   - if payment_ratio > 50%: trigger_alert("还款压力过大")
   - if 逾期记录 > 0: trigger_alert("信用风险")
```

##### 核心技术方案二:雪球还款法

[0012] **雪球还款算法**:
```
算法2:雪球还款法(Debt Snowball)
输入:债务列表 Debts, 可用还款金额 AvailableAmount
输出:还款计划 PaymentPlan

策略原理:
- 优先偿还余额最小的债务
- 获得心理激励,增强还款信心
- 适合债务较多、需要激励的用户

算法步骤:
1. 按余额升序排序:
   sorted_debts = sort(Debts, key=balance, ascending=True)

2. 支付所有最低还款额:
   for debt in Debts:
     pay(debt, debt.min_payment)
     remaining = AvailableAmount - Σ(min_payments)

3. 额外还款分配:
   target_debt = sorted_debts[0]  // 余额最小
   extra_payment = min(remaining, target_debt.balance)
   pay(target_debt, extra_payment)

4. 滚雪球效应:
   if target_debt.balance == 0:
     freed_amount = target_debt.min_payment
     AvailableAmount += freed_amount
     move_to_next_debt()

5. 激励反馈:
   - 每还清一笔债务,显示庆祝动画
   - 展示剩余债务数量减少
   - 计算节省的利息
```

##### 核心技术方案三:雪崩还款法

[0013] **雪崩还款算法**:
```
算法3:雪崩还款法(Debt Avalanche)
输入:债务列表 Debts, 可用还款金额 AvailableAmount
输出:还款计划 PaymentPlan

策略原理:
- 优先偿还利率最高的债务
- 节省最多利息成本
- 适合理性、追求最优解的用户

算法步骤:
1. 按利率降序排序:
   sorted_debts = sort(Debts, key=interest_rate, descending=True)

2. 支付所有最低还款额:
   for debt in Debts:
     pay(debt, debt.min_payment)
     remaining = AvailableAmount - Σ(min_payments)

3. 额外还款分配:
   target_debt = sorted_debts[0]  // 利率最高
   extra_payment = min(remaining, target_debt.balance)
   pay(target_debt, extra_payment)

4. 利息节省计算:
   saved_interest = target_debt.balance ×
                    target_debt.interest_rate / 12 ×
                    months_saved

5. 优化反馈:
   - 展示节省的利息金额
   - 计算提前还清的时间
   - 对比雪球法的差异
```

##### 核心技术方案四:智能还款计划

[0014] **智能还款优化算法**:
```
算法4:智能还款计划生成
输入:债务列表 Debts, 月收入 Income, 用户偏好 Preference
输出:最优还款计划 OptimalPlan

优化策略:
1. 用户偏好识别:
   - 心理型:偏好雪球法(快速减少债务数量)
   - 理性型:偏好雪崩法(最小化利息成本)
   - 平衡型:混合策略

2. 混合策略算法:
   - 先还清1-2笔小额债务(雪球法,获得激励)
   - 再转向高息债务(雪崩法,节省利息)
   - balance_factor = 0.3  // 30%雪球,70%雪崩

3. 动态调整:
   - 收入增加:增加还款金额
   - 收入减少:调整为最低还款
   - 新增债务:重新优化计划

4. 还款优先级:
   - P1(最高):逾期债务
   - P2(高):高息债务(利率>15%)
   - P3(中):中息债务(利率10-15%)
   - P4(低):低息债务(利率<10%)

5. 还款计划生成:
   for month in range(1, max_months):
     // 1. 支付所有最低还款
     pay_minimum_payments()

     // 2. 分配额外还款
     extra = Income × 0.2 - Σ(min_payments)
     if extra > 0:
       allocate_extra_payment(extra, strategy)

     // 3. 更新债务余额
     update_balances()

     // 4. 检查是否还清
     if all_debts_paid():
       break
```
