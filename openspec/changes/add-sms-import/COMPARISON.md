# 短信导入 vs 微信/支付宝文件导入架构对比

## 架构对比总览

### 微信/支付宝文件导入（现有）
```
BatchImportService（协调器）
└── BillParser（抽象类）
    ├── WechatBillParser
    │   ├── 输入：Uint8List bytes（CSV/Excel文件）
    │   ├── 解析：列映射 + 格式解析
    │   └── 输出：ImportCandidate列表
    │
    └── AlipayBillParser
        ├── 输入：Uint8List bytes（CSV文件）
        ├── 解析：列映射 + 格式解析
        └── 输出：ImportCandidate列表
```

### 短信导入（新增）
```
SmsImportService（独立服务）
├── 输入：短信列表（SmsMessage[]）
├── 解析：AI智能解析
└── 输出：ImportCandidate列表
```

## 详细对比

### 1. 架构模式

| 维度 | 微信/支付宝导入 | 短信导入 |
|------|----------------|---------|
| **设计模式** | 策略模式（Strategy Pattern） | 独立服务模式 |
| **继承关系** | 继承BillParser抽象类 | 不继承，独立服务 |
| **接口约束** | 必须实现parse(Uint8List bytes) | 自定义接口 |
| **服务选择** | BatchImportService根据sourceType选择Parser | 直接调用SmsImportService |
| **参考对象** | 其他BillParser实现 | VoiceBatchImportService |

**为什么不同？**
- 文件导入：输入都是字节流，适合统一接口
- 短信导入：输入是短信列表，不适合字节流接口

### 2. 输入源

| 维度 | 微信/支付宝导入 | 短信导入 |
|------|----------------|---------|
| **输入类型** | Uint8List bytes | List<SmsMessage> |
| **数据来源** | 文件系统（用户选择文件） | 系统短信数据库 |
| **格式** | CSV/Excel（结构化） | 自然语言文本（非结构化） |
| **编码处理** | UTF-8/GBK/Latin1 | 系统默认编码 |
| **权限要求** | 文件读取权限（通常已有） | READ_SMS权限（敏感） |

### 3. 解析方式

| 维度 | 微信/支付宝导入 | 短信导入 |
|------|----------------|---------|
| **解析方法** | 规则解析（列映射） | AI智能解析 |
| **列映射** | 固定的列名映射表 | 无需列映射 |
| **格式识别** | 查找表头行（"交易时间"、"金额"） | AI自动识别 |
| **数据提取** | CSV/Excel库解析 | AI提取结构化数据 |
| **准确率** | 100%（格式匹配） | 依赖AI（95%+） |
| **容错性** | 格式不匹配则失败 | AI可处理多种格式 |

**微信/支付宝解析示例**：
```dart
// 列映射
static const _columnMappings = {
  '交易时间': 'date',
  '交易对方': 'merchant',
  '金额(元)': 'amount',
  '收/支': 'direction',
};

// 解析逻辑
for (final row in rows) {
  final date = row[dateIndex];
  final merchant = row[merchantIndex];
  final amount = row[amountIndex];
  // ... 创建ImportCandidate
}
```

**短信解析示例**：
```dart
// AI Prompt
final prompt = '''
解析以下短信，提取交易信息：
1. [95588] 您尾号1234的储蓄卡12月20日10:30支出500.00元
2. [支付宝] 您在星巴克消费45.00元
返回JSON格式：[{amount, type, date, merchant}, ...]
''';

// AI解析
final response = await aiService.chat(prompt);
final transactions = parseJSON(response);
```

### 4. 数据流对比

#### 微信/支付宝文件导入流程
```
1. 用户选择文件
   ↓
2. BatchImportService.detectFormat()
   - 读取文件字节
   - BillFormatDetector识别格式
   ↓
3. BatchImportService.parseBytes()
   - 根据sourceType选择Parser
   - WechatBillParser.parse(bytes)
     - 解析CSV/Excel
     - 列映射提取字段
     - 生成ImportCandidate
   ↓
4. DuplicateScorer.checkDuplicates()
   ↓
5. ImportPreviewPage（预览确认）
   ↓
6. BatchImportService.executeImport()
```

#### 短信导入流程
```
1. 用户选择时间范围
   ↓
2. SmsImportService.importFromSms()
   - SmsReaderService.readSms()
     - 检查权限
     - 读取短信列表
     - 过滤发件人
   ↓
3. SmsParserService.parseBatch()
   - AI批量解析
   - 生成ImportCandidate
   ↓
4. DuplicateScorer.checkDuplicates()
   ↓
5. ImportPreviewPage（预览确认）
   ↓
6. BatchImportService.executeImport()
```

**共同点**：
- ✅ 步骤4-6完全相同（重复检测、预览、导入）
- ✅ 都生成标准的ImportCandidate格式
- ✅ 都使用相同的预览和导入流程

**差异点**：
- ❌ 步骤1-3完全不同（输入源和解析方式）
- ❌ 文件导入使用格式检测，短信导入使用权限检查
- ❌ 文件导入使用规则解析，短信导入使用AI解析

### 5. 核心类对比

#### WechatBillParser（文件导入）
```dart
class WechatBillParser extends BillParser {
  @override
  BillSourceType get sourceType => BillSourceType.wechatPay;

  @override
  ExternalSource get externalSource => ExternalSource.wechatPay;

  @override
  Future<BillParseResult> parse(Uint8List bytes) async {
    // 1. 尝试Excel格式
    // 2. 尝试CSV格式
    // 3. 查找表头行
    // 4. 列映射解析
    // 5. 生成ImportCandidate
  }

  // 列映射表
  static const _columnMappings = {...};
}
```

#### SmsImportService（短信导入）
```dart
class SmsImportService {
  final SmsReaderService _readerService;
  final SmsParserService _parserService;
  final DuplicateScorer _duplicateScorer;

  Future<SmsImportResult> importFromSms({
    required DateTime startDate,
    required DateTime endDate,
    required String ledgerId,
  }) async {
    // 1. 检查权限
    // 2. 读取短信
    // 3. AI解析
    // 4. 生成ImportCandidate
    // 5. 重复检测
  }
}
```

**关键差异**：
- WechatBillParser：单一职责（解析），依赖BatchImportService协调
- SmsImportService：多职责（读取+解析+检测），自己协调流程

### 6. 复用程度对比

| 组件 | 微信/支付宝导入 | 短信导入 |
|------|----------------|---------|
| **BatchImportService** | 完全依赖 | 部分复用（仅executeImport） |
| **BillFormatDetector** | 使用 | 不使用 |
| **BillParser基类** | 继承 | 不继承 |
| **DuplicateScorer** | 复用 | 复用 |
| **ImportPreviewPage** | 复用 | 复用 |
| **ImportCandidate** | 复用 | 复用 |
| **inferCategory方法** | 使用 | 可选使用 |

### 7. 优缺点对比

#### 微信/支付宝文件导入

**优点**：
- ✅ 解析准确率100%（格式匹配）
- ✅ 无需网络请求
- ✅ 无API调用成本
- ✅ 架构统一（都继承BillParser）
- ✅ 易于添加新的文件格式

**缺点**：
- ❌ 只能处理固定格式
- ❌ 格式变化需要更新代码
- ❌ 需要用户手动导出文件
- ❌ 列映射维护成本

#### 短信导入

**优点**：
- ✅ 无需用户导出文件
- ✅ 自动读取，用户体验好
- ✅ AI可处理多种格式
- ✅ 适应性强，格式变化无需更新代码

**缺点**：
- ❌ 需要AI解析，有成本
- ❌ 需要网络请求
- ❌ 准确率依赖AI（95%+）
- ❌ 需要敏感权限（READ_SMS）
- ❌ 架构独立，不在BillParser体系内

### 8. 为什么短信导入不继承BillParser？

#### 技术原因
1. **接口不匹配**：
   - BillParser.parse()接收`Uint8List bytes`
   - 短信数据是`List<SmsMessage>`，不是字节流
   - 强行转换会破坏语义

2. **职责不同**：
   - BillParser：纯解析器，只负责解析
   - SmsImportService：需要权限管理、短信读取、AI解析等多个职责

3. **依赖不同**：
   - BillParser：依赖CSV/Excel解析库
   - SmsImportService：依赖telephony插件、AI服务

#### 架构原因
1. **参考先例**：
   - VoiceBatchImportService也是独立服务
   - 证明了非文件导入可以不继承BillParser

2. **保持清晰**：
   - 避免强行适配不合适的接口
   - 保持代码可读性和可维护性

3. **灵活性**：
   - 独立服务更容易扩展
   - 不受BillParser接口约束

### 9. 如果强行继承BillParser会怎样？

#### 方案A：将短信转换为字节流
```dart
class SmsBillParser extends BillParser {
  @override
  Future<BillParseResult> parse(Uint8List bytes) async {
    // 1. 将bytes反序列化为短信列表（不自然）
    final messages = deserializeSmsMessages(bytes);

    // 2. 需要在bytes中编码权限状态（奇怪）
    // 3. 需要在bytes中编码时间范围（奇怪）

    // 4. AI解析
    // ...
  }
}

// 调用方需要先序列化
final smsBytes = serializeSmsMessages(messages);
final result = await smsBillParser.parse(smsBytes);
```

**问题**：
- ❌ 语义不清晰（短信不是文件）
- ❌ 需要额外的序列化/反序列化
- ❌ 权限管理无处安放
- ❌ 时间范围参数无法传递

#### 方案B：扩展BillParser接口
```dart
abstract class BillParser {
  Future<BillParseResult> parse(Uint8List bytes);

  // 新增方法（破坏现有实现）
  Future<BillParseResult> parseFromSms(List<SmsMessage> messages) {
    throw UnimplementedError();
  }
}
```

**问题**：
- ❌ 破坏接口单一职责
- ❌ 所有现有Parser需要处理新方法
- ❌ 违反开闭原则

### 10. 最佳实践总结

#### 何时继承BillParser？
✅ **适合继承的场景**：
- 输入是文件字节流
- 解析逻辑是规则驱动的
- 格式是结构化的（CSV/Excel/JSON等）
- 只负责解析，不涉及其他职责

**示例**：
- WechatBillParser ✓
- AlipayBillParser ✓
- GenericBankParser ✓
- 未来的其他银行账单Parser ✓

#### 何时使用独立服务？
✅ **适合独立服务的场景**：
- 输入不是文件字节流
- 需要额外的职责（权限、读取等）
- 解析逻辑是AI驱动的
- 需要会话管理或状态管理

**示例**：
- VoiceBatchImportService ✓
- SmsImportService ✓
- 未来的邮件导入Service ✓
- 未来的API同步Service ✓

## 结论

短信导入与微信/支付宝文件导入的核心差异在于：

1. **输入源不同**：短信列表 vs 文件字节流
2. **解析方式不同**：AI智能解析 vs 规则列映射
3. **职责范围不同**：多职责协调 vs 单一解析职责

因此，短信导入采用独立服务架构是**正确的设计决策**，它：
- ✅ 保持了架构清晰性
- ✅ 避免了强行适配不合适的接口
- ✅ 参考了VoiceBatchImportService的成功先例
- ✅ 最大化复用了核心组件（ImportCandidate、DuplicateScorer、ImportPreviewPage）
- ✅ 符合SOLID设计原则

同时，两种架构在**关键环节保持一致**：
- ✅ 都生成标准的ImportCandidate格式
- ✅ 都使用相同的重复检测逻辑
- ✅ 都使用相同的预览确认界面
- ✅ 都使用相同的导入执行逻辑

这种设计既保持了架构的灵活性，又确保了核心流程的一致性。
