# 短信导入架构设计总结

## 核心架构决策

### 1. 独立服务架构（不继承BillParser）

**决策**：创建独立的SmsImportService，不继承BillParser接口

**理由**：
- 短信导入与文件导入的输入源本质不同（短信列表 vs 文件字节流）
- BillParser接口设计为`parse(Uint8List bytes)`，不适合短信场景
- 参考现有的VoiceBatchImportService架构，它也是独立服务
- 保持架构清晰，避免强行适配不合适的接口

### 2. 架构对比

#### 文件导入架构（现有）
```
BatchImportService（协调器）
└── BillParser（策略模式）
    ├── WechatBillParser
    ├── AlipayBillParser
    └── GenericBankParser

特点：
- 统一的parse(Uint8List bytes)接口
- 策略模式选择不同的解析器
- 适合文件格式的解析
```

#### 非文件导入架构（语音、短信）
```
独立Service
├── VoiceBatchImportService（已有）
│   ├── 输入：音频文件
│   ├── 处理：语音识别 + AI解析
│   └── 输出：ImportCandidate列表
│
└── SmsImportService（新增）
    ├── 输入：短信列表
    ├── 处理：AI批量解析
    └── 输出：ImportCandidate列表

特点：
- 独立的服务类
- 不继承BillParser
- 生成标准的ImportCandidate
- 复用后续流程（重复检测、预览、导入）
```

### 3. 服务层职责划分

```
SmsImportService（主服务）
├── 职责：协调整个导入流程，管理状态
├── 依赖：
│   ├── SmsReaderService（短信读取）
│   ├── SmsParserService（AI解析）
│   └── DuplicateScorer（重复检测）
└── 输出：ImportCandidate列表

SmsReaderService（短信读取服务）
├── 职责：封装短信读取逻辑
├── 功能：
│   ├── 权限检查和申请
│   ├── 按时间范围查询
│   └── 发件人过滤
└── 输出：SmsMessage列表

SmsParserService（短信解析服务）
├── 职责：封装AI解析逻辑
├── 功能：
│   ├── 批量解析（15-20条/批）
│   ├── 结果转换为ImportCandidate
│   └── 错误处理和重试
└── 输出：ParsedTransaction列表
```

### 4. 数据流

```
用户操作
  ↓
SmsImportService.importFromSms()
  ↓
1. SmsReaderService.readSms()
   - 检查权限
   - 读取短信
   - 过滤发件人
  ↓
2. SmsParserService.parseBatch()
   - AI批量解析
   - 转换为ImportCandidate
  ↓
3. DuplicateScorer.checkDuplicates()
   - 复用现有逻辑
   - 标记重复记录
  ↓
4. 返回ImportCandidate列表
  ↓
5. ImportPreviewPage（复用现有界面）
   - 显示解析结果
   - 支持编辑和筛选
   - 用户确认
  ↓
6. BatchImportService.executeImport()
   - 复用现有导入逻辑
   - 批量写入数据库
```

### 5. 关键复用点

| 组件 | 复用方式 | 说明 |
|------|---------|------|
| ImportCandidate | 完全复用 | 短信导入生成的格式与文件导入一致 |
| DuplicateScorer | 完全复用 | 使用相同的重复检测逻辑 |
| ImportPreviewPage | 完全复用 | 预览确认界面完全一致 |
| BatchImportService.executeImport | 完全复用 | 导入逻辑完全一致 |
| BillParser.inferCategory | 可选复用 | 可以使用现有的分类推断逻辑 |

### 6. 与VoiceBatchImportService的对比

| 特性 | VoiceBatchImportService | SmsImportService |
|------|------------------------|------------------|
| 输入源 | 音频文件 | 短信列表 |
| 识别方式 | 语音识别引擎 | AI文本解析 |
| 批量处理 | 逐条添加到会话 | 批量读取后解析 |
| 会话管理 | VoiceBatchSession | 无需会话（一次性） |
| 输出格式 | ImportCandidate | ImportCandidate |
| 复用流程 | 预览+导入 | 预览+导入 |

**相似点**：
- 都是独立服务，不继承BillParser
- 都生成标准的ImportCandidate
- 都复用预览和导入流程

**差异点**：
- 语音导入是交互式的（逐条添加），短信导入是批量的（一次性读取）
- 语音导入需要会话管理，短信导入不需要

### 7. 架构优势

1. **清晰的职责分离**：
   - SmsReaderService专注于短信读取
   - SmsParserService专注于AI解析
   - SmsImportService协调整体流程

2. **最大化代码复用**：
   - 复用ImportCandidate数据模型
   - 复用DuplicateScorer重复检测
   - 复用ImportPreviewPage预览界面
   - 复用BatchImportService导入逻辑

3. **易于测试**：
   - 每个服务职责单一
   - 可以独立测试每个组件
   - 可以mock依赖进行单元测试

4. **易于扩展**：
   - 未来可以添加其他非文件导入方式
   - 可以替换AI解析服务
   - 可以添加本地规则匹配作为补充

5. **符合SOLID原则**：
   - 单一职责原则（SRP）：每个服务职责单一
   - 开闭原则（OCP）：对扩展开放，对修改封闭
   - 依赖倒置原则（DIP）：依赖抽象而非具体实现

### 8. 实现注意事项

1. **ExternalSource枚举**：
   - 需要在ExternalSource枚举中添加`sms`值
   - 用于重复检测时标识来源

2. **ImportCandidate字段**：
   - `source`字段设置为"短信导入"
   - `sourceNote`字段保留原始短信内容
   - `externalId`可以使用短信ID（可选）

3. **错误处理**：
   - 权限错误：友好提示和引导
   - 网络错误：重试机制
   - 解析错误：部分成功处理

4. **性能优化**：
   - 批量解析减少API调用
   - 后台线程避免阻塞UI
   - 分页读取避免内存溢出

## 总结

短信导入采用独立服务架构，参考VoiceBatchImportService的设计模式，通过生成标准的ImportCandidate格式，最大化复用现有的重复检测、预览确认和导入逻辑。这种架构设计清晰、易于维护、符合设计原则，同时保持了与现有系统的良好集成。
