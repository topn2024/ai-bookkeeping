# 模型序列化规范

## 新增需求

### 需求：DateTime 字段必须使用 ISO 8601 格式序列化

所有模型中的 DateTime 字段在序列化时必须使用 ISO 8601 字符串格式，以确保跨平台兼容性和可读性。

#### 场景：序列化 DateTime 字段

**给定** 一个包含 DateTime 字段的模型实例
**当** 调用 `toMap()` 或 `toJson()` 方法时
**那么** DateTime 字段应该使用 `toIso8601String()` 格式输出

**示例**：
```dart
// 输入
final model = Transaction(createdAt: DateTime(2024, 1, 15, 10, 30));

// 输出
{'createdAt': '2024-01-15T10:30:00.000'}
```

#### 场景：反序列化兼容旧格式

**给定** 一个包含旧格式（毫秒时间戳）DateTime 数据的 Map
**当** 调用 `fromMap()` 工厂构造函数时
**那么** 应该能正确解析毫秒时间戳格式
**并且** 应该能正确解析 ISO 8601 字符串格式

---

### 需求：Boolean 字段序列化必须根据存储目标区分

Boolean 字段序列化必须根据存储目标采用不同格式：SQLite 存储必须使用整数格式（0/1），JSON/API 传输必须使用原生布尔值。

#### 场景：序列化 Boolean 用于 SQLite 存储

**给定** 一个包含 Boolean 字段的模型实例
**当** 调用 `toMap()` 方法用于数据库存储时
**那么** Boolean 字段应该输出为 `1`（true）或 `0`（false）

#### 场景：序列化 Boolean 用于 API 传输

**给定** 一个包含 Boolean 字段的模型实例
**当** 调用 `toJson()` 方法用于 API 传输时
**那么** Boolean 字段应该输出为原生布尔值 `true` 或 `false`

---

### 需求：Enum 字段必须使用 name 而非 index 序列化

Enum 序列化必须使用枚举值的名称字符串，以避免枚举顺序变化导致的数据错误。

#### 场景：序列化 Enum 字段

**给定** 一个包含 Enum 字段的模型实例
**当** 调用 `toMap()` 方法时
**那么** Enum 字段应该输出为枚举值的 `name` 属性

**示例**：
```dart
// 枚举定义
enum TransactionStatus { pending, completed, cancelled }

// 输入
final model = Transaction(status: TransactionStatus.completed);

// 输出
{'status': 'completed'}  // 而非 {'status': 1}
```

#### 场景：反序列化兼容旧格式

**给定** 一个包含旧格式（index 整数）Enum 数据的 Map
**当** 调用 `fromMap()` 工厂构造函数时
**那么** 应该能正确解析 index 整数格式
**并且** 应该能正确解析 name 字符串格式
**并且** 解析失败时应该返回默认值而非抛出异常

---

### 需求：所有持久化模型必须实现完整的序列化方法

需要持久化存储的模型必须实现 `toMap()`、`fromMap()` 和 `copyWith()` 方法。

#### 场景：模型序列化往返一致性

**给定** 一个完整初始化的模型实例
**当** 依次调用 `toMap()` 和 `fromMap()` 方法
**那么** 还原后的实例应该与原始实例相等

**示例**：
```dart
final original = Transaction(...);
final map = original.toMap();
final restored = Transaction.fromMap(map);
expect(restored, equals(original));
```

---

## 修改需求

### 需求：模型类名必须唯一

必须修改现有允许同名类存在的隐式规则。所有模型类名在整个 `models/` 目录下必须唯一，禁止定义同名类。

#### 场景：避免类名冲突

**给定** 项目中已存在一个名为 `Achievement` 的模型类
**当** 需要定义另一个表示不同概念的成就类时
**那么** 必须使用不同的类名（如 `LeaderboardAchievement`）
**以便** 避免导入冲突和混淆
