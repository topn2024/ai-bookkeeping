# 规范：自定义SQL查询

## 新增需求

### 需求：SQL查询生成器

系统必须能够根据查询请求自动生成安全的SQL查询语句。

#### 场景：简单聚合查询生成

**前置条件**：
- 查询请求包含时间范围和聚合类型

**操作**：
- 系统生成SQL查询

**预期结果**：
- 生成正确的SELECT语句
- 包含WHERE子句（时间范围）
- 包含聚合函数（SUM/AVG/COUNT等）

**示例**：
```sql
SELECT SUM(amount) as value
FROM transactions
WHERE date >= 1704067200000 AND date < 1706745600000
  AND type = 'expense'
```

#### 场景：分组查询生成

**前置条件**：
- 查询请求包含分组维度

**操作**：
- 系统生成带GROUP BY的SQL查询

**预期结果**：
- 生成正确的SELECT语句
- 包含GROUP BY子句
- 包含聚合函数

**示例**：
```sql
SELECT category, SUM(amount) as value
FROM transactions
WHERE date >= 1704067200000 AND date < 1706745600000
GROUP BY category
ORDER BY value DESC
```

#### 场景：时间序列查询生成

**前置条件**：
- 查询请求按日期或月份分组

**操作**：
- 系统生成时间序列SQL查询

**预期结果**：
- 使用strftime函数格式化日期
- 按时间分组
- 按时间排序

**示例**：
```sql
SELECT strftime('%Y-%m', date / 1000, 'unixepoch') as month,
       SUM(amount) as value
FROM transactions
WHERE date >= 1704067200000 AND date < 1706745600000
GROUP BY month
ORDER BY month ASC
```

### 需求：SQL安全验证

系统必须验证生成的SQL查询的安全性，防止SQL注入和恶意查询。

#### 场景：危险关键字检测

**前置条件**：
- SQL查询已生成

**操作**：
- 系统验证SQL安全性

**预期结果**：
- 检测到DROP/DELETE/UPDATE/INSERT/ALTER/CREATE等危险关键字
- 抛出SecurityException异常
- 拒绝执行查询

#### 场景：表名白名单验证

**前置条件**：
- SQL查询已生成

**操作**：
- 系统验证表名

**预期结果**：
- 只允许查询transactions表
- 其他表名抛出SecurityException异常

#### 场景：字段名白名单验证

**前置条件**：
- SQL查询已生成

**操作**：
- 系统验证字段名

**预期结果**：
- 只允许查询预定义的字段（id, amount, category, date等）
- 其他字段名抛出SecurityException异常

#### 场景：查询复杂度限制

**前置条件**：
- SQL查询已生成

**操作**：
- 系统检查查询复杂度

**预期结果**：
- SQL长度 ≤ 1000字符
- 超过限制抛出SecurityException异常

### 需求：参数化查询

系统必须使用参数化查询防止SQL注入。

#### 场景：参数转义

**前置条件**：
- 查询请求包含用户输入（如分类名称）

**操作**：
- 系统转义用户输入

**预期结果**：
- 单引号被转义为两个单引号
- 特殊字符被正确处理
- 无法注入恶意SQL

**示例**：
- 输入：`餐饮' OR '1'='1`
- 转义后：`餐饮'' OR ''1''=''1`

### 需求：查询结果转换

系统必须将原始SQL查询结果转换为统一的数据结构。

#### 场景：聚合结果转换

**前置条件**：
- SQL查询返回聚合结果

**操作**：
- 系统转换查询结果

**预期结果**：
- 转换为QueryResult对象
- 包含totalExpense、totalIncome等字段
- 数据类型正确

#### 场景：分组结果转换

**前置条件**：
- SQL查询返回分组结果

**操作**：
- 系统转换查询结果

**预期结果**：
- 转换为QueryResult对象
- groupedData字段包含Map<String, double>
- 每个分组的数据正确

#### 场景：时间序列结果转换

**前置条件**：
- SQL查询返回时间序列结果

**操作**：
- 系统转换查询结果

**预期结果**：
- 转换为QueryResult对象
- detailedData字段包含List<DataPoint>
- 每个数据点包含timestamp和value

## 修改需求

### 需求：DatabaseService扩展

现有的DatabaseService必须支持原始SQL查询。

#### 场景：执行原始SQL查询

**前置条件**：
- 需要执行自定义SQL查询

**操作**：
- 调用DatabaseService.rawQuery()

**预期结果**：
- 执行SQL查询
- 返回List<Map<String, dynamic>>
- 支持参数化查询

## 相关功能

- 依赖：[query-complexity-analysis](../query-complexity-analysis/spec.md) - 判定是否需要自定义查询
- 关联：[query-result-routing](../query-result-routing/spec.md) - 处理查询结果
- 关联：[interactive-query-chart](../interactive-query-chart/spec.md) - 显示复杂查询结果
