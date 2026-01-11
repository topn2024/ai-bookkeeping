# 规范：统一格式化服务

## 新增需求

### 需求：货币格式化

系统**必须**提供统一的货币格式化方法 `formatCurrency()`，支持多币种。

#### 场景：格式化人民币金额

**Given** 金额为 1234.56，币种为 CNY
**When** 调用 `formatCurrency(1234.56, currencyCode: 'CNY')`
**Then** 应返回 "¥1234.56"

#### 场景：格式化美元金额

**Given** 金额为 1234.56，币种为 USD
**When** 调用 `formatCurrency(1234.56, currencyCode: 'USD')`
**Then** 应返回 "$1,234.56"（带千位分隔符）

#### 场景：不显示货币符号

**Given** 需要纯数字显示
**When** 调用 `formatCurrency(1234.56, showSymbol: false)`
**Then** 应返回 "1234.56"

#### 场景：自定义小数位数

**Given** 需要整数显示
**When** 调用 `formatCurrency(1234.56, decimalPlaces: 0)`
**Then** 应返回 "¥1235"（四舍五入）

---

### 需求：数字格式化

系统**必须**提供 `formatNumber()` 方法，支持带千位分隔符的数字格式化。

#### 场景：格式化大数字

**Given** 数字为 1234567.89
**When** 调用 `formatNumber(1234567.89)`
**Then** 应返回 "1,234,567.89"

---

### 需求：百分比格式化

系统**必须**提供 `formatPercentage()` 方法，支持比例到百分比的格式化。

#### 场景：格式化比例为百分比

**Given** 比例为 0.1234
**When** 调用 `formatPercentage(0.1234)`
**Then** 应返回 "12.3%"

---

### 需求：日期格式化

系统**必须**提供日期格式化方法 `formatDate()` 和相对时间格式化方法 `formatRelativeTime()`。

#### 场景：格式化日期

**Given** 日期为 2024-01-15
**When** 调用 `formatDate(date)`
**Then** 应返回 "2024-01-15" 或本地化格式

#### 场景：格式化相对时间

**Given** 时间为 5 分钟前
**When** 调用 `formatRelativeTime(date)`
**Then** 应返回 "5分钟前"

---

### 需求：扩展方法便捷访问

系统**必须**提供 `double` 类型的扩展方法，便于链式调用格式化。

#### 场景：使用扩展方法格式化

**Given** 金额变量 `amount = 99.9`
**When** 调用 `amount.toCurrency()`
**Then** 应返回 "¥99.90"

---

## 技术约束

- 服务位于 `lib/core/formatting/formatting_service.dart`
- 使用单例模式 `FormattingService.instance`
- 支持通过 `setLocale()` 切换本地化
- 扩展方法位于同文件
