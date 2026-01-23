# 发明专利申请

**发明名称**:基于多算法融合的消费趋势预测和洞察生成方法

**技术领域**:人工智能与数据分析技术领域

**申请人**:李北华

**发明人**:李北华

**申请日**:2026-1-18

---

## 说明书

### 发明名称

基于多算法融合的消费趋势预测和洞察生成方法

### 技术领域

[0001] 本发明涉及人工智能与数据分析技术领域,具体涉及一种基于多算法融合的消费趋势预测和洞察生成方法及系统,可应用于个人财务管理、消费行为分析、预算规划等场景。

### 背景技术

[0002] 消费趋势预测是个人财务管理的重要功能,帮助用户提前规划支出、避免预算超支。然而,现有技术在预测准确性、洞察深度、实用性方面存在不足。

[0003] **现有技术一(简单平均法)**:部分记账应用使用简单平均法预测未来支出。技术缺陷:(1)未考虑趋势变化;(2)未考虑季节性因素;(3)预测准确率低(<60%);(4)无置信区间。

[0004] **现有技术二(线性回归)**:部分应用使用线性回归预测趋势。技术缺陷:(1)假设线性关系,不适用于非线性数据;(2)未考虑季节性;(3)对异常值敏感;(4)无消费洞察生成。

[0005] **现有技术三(时间序列分析)**:学术领域提出ARIMA、指数平滑等方法。技术缺陷:(1)模型复杂,计算成本高;(2)需要大量历史数据;(3)参数调优困难;(4)不适合移动端实时计算;(5)无业务洞察。

[0006] **现有技术四(机器学习)**:部分研究使用LSTM、Prophet等深度学习模型。技术缺陷:(1)需要大量训练数据;(2)模型体积大,不适合移动端;(3)可解释性差;(4)计算资源消耗大;(5)无法提供可操作的建议。

[0007] 综上所述,现有技术存在以下共性技术问题:(1)预测准确率低;(2)未考虑季节性因素;(3)无置信区间;(4)缺乏消费洞察;(5)不适合移动端实时计算。

### 发明内容

#### 发明目的

[0008] 本发明的目的在于提供一种基于多算法融合的消费趋势预测和洞察生成方法及系统,解决现有技术中准确率低、无季节性、无洞察、不适合移动端等技术问题。

#### 技术方案

[0009] 本发明提出一种**多算法融合 + 季节性调整 + 置信区间 + 洞察生成 + 预警机制**的五维消费趋势预测系统,包括:

##### 核心技术方案一:多算法融合预测

[0010] **预测数据结构**:
```
PredictionResult {
  target_month: Date,           // 目标月份
  predicted_amount: Decimal(18,2), // 预测金额
  confidence_level: Float,      // 置信度
  lower_bound: Decimal(18,2),   // 下界(95%置信区间)
  upper_bound: Decimal(18,2),   // 上界(95%置信区间)
  trend: Enum,                  // 趋势:上升/下降/稳定
  seasonality_factor: Float,    // 季节性因子
  algorithm_weights: Map        // 各算法权重
}
```

[0011] **多算法融合预测算法**:
```
算法1:多算法融合预测
输入:历史消费数据 History (至少6个月)
输出:未来3个月预测 Predictions

融合策略:
1. 简单移动平均(SMA):
   - 计算近N个月平均值
   - SMA_3 = mean(last_3_months)
   - SMA_6 = mean(last_6_months)
   - 权重:0.2

2. 加权移动平均(WMA):
   - 最近月份权重更高
   - weights = [0.5, 0.33, 0.17]  // 近3个月
   - WMA = Σ(amount[i] × weight[i])
   - 权重:0.3

3. 指数移动平均(EMA):
   - 平滑系数α = 0.3
   - EMA[t] = α × amount[t] + (1-α) × EMA[t-1]
   - 权重:0.2

4. 线性回归趋势:
   - 拟合线性模型:y = a × t + b
   - 计算趋势斜率a
   - trend_prediction = a × target_month + b
   - 权重:0.3

5. 融合预测:
   base_prediction = 0.2 × SMA_6 +
                     0.3 × WMA +
                     0.2 × EMA +
                     0.3 × trend_prediction

6. 季节性调整:
   seasonal_factor = get_seasonal_factor(target_month)
   final_prediction = base_prediction × seasonal_factor
```

##### 核心技术方案二:季节性因子计算

[0012] **季节性分析算法**:
```
算法2:季节性因子计算
输入:历史消费数据 History (至少12个月)
输出:12个月季节性因子 SeasonalFactors

计算方法:
1. 月度平均消费:
   monthly_avg = {}
   for month in [1..12]:
     monthly_avg[month] = mean(amounts_in_month)

2. 全年平均消费:
   yearly_avg = mean(all_amounts)

3. 季节性因子:
   for month in [1..12]:
     seasonal_factor[month] = monthly_avg[month] / yearly_avg

4. 中国市场特殊因子:
   - 1月(元旦):1.1
   - 2月(春节):1.3 (最高)
   - 3月:0.9 (春节后回落)
   - 6月(618):1.2
   - 11月(双11):1.4 (次高)
   - 12月(双12+年终):1.2

5. 平滑处理:
   // 避免极端值
   seasonal_factor = clip(seasonal_factor, 0.7, 1.5)

6. 动态更新:
   // 每月根据实际数据更新因子
   new_factor = 0.7 × old_factor + 0.3 × actual_factor
```

##### 核心技术方案三:置信区间计算

[0013] **置信区间算法**:
```
算法3:预测置信区间计算
输入:历史数据 History, 预测值 Prediction
输出:置信区间 [LowerBound, UpperBound]

计算方法:
1. 历史误差计算:
   errors = []
   for i in range(len(History) - 3):
     predicted = predict(History[:i])
     actual = History[i]
     error = actual - predicted
     errors.append(error)

2. 标准差:
   std_error = std(errors)

3. 95%置信区间:
   // 使用正态分布
   z_score = 1.96  // 95%置信度
   margin = z_score × std_error

   lower_bound = Prediction - margin
   upper_bound = Prediction + margin

4. 置信度评估:
   // 基于数据质量
   data_quality = min(len(History) / 12, 1.0)
   cv = std(History) / mean(History)  // 变异系数
   stability = 1 - min(cv, 1.0)

   confidence = 0.5 × data_quality + 0.5 × stability

5. 置信度等级:
   - 高置信度:confidence > 0.8
   - 中置信度:0.6 ≤ confidence ≤ 0.8
   - 低置信度:confidence < 0.6
```

##### 核心技术方案四:消费洞察生成

[0014] **洞察生成算法**:
```
算法4:消费洞察智能生成
输入:历史数据 History, 预测结果 Prediction
输出:洞察列表 Insights

洞察类型:
1. 拿铁因子检测:
   // 小额高频消费
   small_transactions = filter(History, amount < 50)
   small_ratio = sum(small_transactions) / sum(History)

   if small_ratio > 0.3:
     insight = "您的小额消费占比{small_ratio}%,
                建议关注'拿铁因子',
                每月可节省{saved_amount}元"

2. 周末消费模式:
   weekend_amount = sum(weekend_transactions)
   weekday_amount = sum(weekday_transactions)
   weekend_ratio = weekend_amount / (weekend_amount + weekday_amount)

   if weekend_ratio > 0.5:
     insight = "您的周末消费占比{weekend_ratio}%,
                建议周末前规划预算"

3. 异常大额消费:
   large_transactions = filter(History, amount > 1000)

   if len(large_transactions) > 0:
     insight = "检测到{count}笔大额消费,
                总计{total}元,
                建议提前规划大额支出"

4. 消费趋势分析:
   trend = calculate_trend(History)

   if trend > 0.1:  // 上升趋势
     insight = "您的消费呈上升趋势,
                月均增长{trend}%,
                建议控制支出增长"
   elif trend < -0.1:  // 下降趋势
     insight = "您的消费呈下降趋势,
                月均减少{-trend}%,
                节约效果显著"

5. 分类消费洞察:
   top_categories = get_top_categories(History, n=3)

   for category in top_categories:
     ratio = category.amount / total_amount
     insight = "{category}消费占比{ratio}%,
                是您的主要支出项"
```
