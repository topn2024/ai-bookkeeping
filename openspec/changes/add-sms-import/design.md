# 短信导入功能技术设计

## 上下文
用户希望通过读取手机短信快速导入交易记录。短信中包含银行、支付宝、微信等支付通知，包含交易金额、时间、商户等信息。该功能需要处理权限申请、短信读取、AI解析、重复检测等多个环节。

### 约束
- iOS平台无法直接读取短信，仅支持Android平台
- 需要申请敏感权限READ_SMS，需要向用户明确说明用途
- 短信格式多样，需要AI智能解析
- 需要复用现有的重复检测和导入流程

### 利益相关者
- 用户：希望快速批量导入交易记录
- 开发团队：需要保证代码质量和可维护性
- 隐私合规：需要妥善处理短信权限和数据安全

## 目标 / 非目标

### 目标
- 实现Android平台的短信读取和导入功能
- 支持用户自定义时间范围筛选
- 使用AI智能解析短信内容
- 复用现有的重复检测和导入流程
- 提供良好的用户体验和错误处理

### 非目标
- 不支持iOS平台的短信读取（系统限制）
- 不实现本地规则匹配解析（用户选择AI解析）
- 不支持导出短信内容到文件
- 不实现短信内容的本地存储（仅临时处理）

## 决策

### 1. 架构设计决策
**决策**：创建独立的SmsImportService，不继承BillParser接口

**理由**：
- 短信导入与文件导入的输入源本质不同（短信列表 vs 文件字节流）
- BillParser接口设计为`parse(Uint8List bytes)`，不适合短信场景
- 参考现有的VoiceBatchImportService架构，它也是独立服务
- 保持架构清晰，避免强行适配不合适的接口

**架构对比**：
```
文件导入架构：
BatchImportService → BillParser (策略模式)
├── WechatBillParser
├── AlipayBillParser
└── GenericBankParser

非文件导入架构（语音、短信）：
独立Service → 生成ImportCandidate → 复用BatchImportService的后续流程
├── VoiceBatchImportService (已有)
└── SmsImportService (新增)
```

**关键原则**：
- 不同输入源使用不同的Service
- 统一输出格式：ImportCandidate
- 复用核心逻辑：DuplicateScorer、ImportPreviewPage、导入流程

### 2. 短信读取方案
**决策**：使用`telephony`插件读取Android短信

**理由**：
- `telephony`是Flutter官方推荐的短信处理插件
- 支持按时间范围查询短信
- 支持过滤发件人地址
- 活跃维护，兼容性好

**替代方案**：
- `sms_advanced`：功能较少，更新不活跃
- `flutter_sms`：主要用于发送短信，读取功能有限

### 2. 短信读取方案
**决策**：使用`telephony`插件读取Android短信

**理由**：
- `telephony`是Flutter官方推荐的短信处理插件
- 支持按时间范围查询短信
- 支持过滤发件人地址
- 活跃维护，兼容性好

**替代方案**：
- `sms_advanced`：功能较少，更新不活跃
- `flutter_sms`：主要用于发送短信，读取功能有限

### 3. AI解析策略
**决策**：使用通义千问API批量解析短信内容

**实现方式**：
- 将多条短信（如10-20条）合并为一个批次
- 构造结构化的Prompt，要求AI返回JSON格式的交易列表
- 每个交易包含：金额、类型（收入/支出）、时间、商户、备注、**分类**等字段
- 对于无法识别的短信，AI返回null或空对象

**Prompt设计**：
```
你是一个专业的交易记录解析助手。请从以下短信中提取交易信息，返回JSON数组格式。

短信列表：
1. [发件人: 95588] 您尾号1234的储蓄卡12月20日10:30支出500.00元，余额1234.56元
2. [发件人: 支付宝] 支付宝：您在星巴克消费45.00元
...

要求：
- 只提取交易相关的短信，忽略验证码、广告等
- 每条交易包含：
  - amount（金额）
  - type（income/expense）
  - date（ISO格式）
  - merchant（商户名）
  - note（备注）
  - category（分类ID，如food_drink、transport_taxi等）← 要求AI返回分类
- 如果短信不包含交易信息，返回null
- 返回格式：[{...}, {...}, null, ...]
```

**优化**：
- 批量解析减少API调用次数
- 设置合理的超时时间（30秒）
- 实现失败重试机制（最多3次）

### 4. 分类推断策略
**决策**：AI直接分类 + 规则引擎兜底（复用BillParser.inferCategory）

**理由**：
- AI在解析短信时可以理解上下文语义，直接推断分类
- 使用BillParser.inferCategory作为兜底，确保总有分类
- 与文件导入保持一致（文件导入也使用inferCategory）
- 用户可在预览页面手动修改分类

**实现方式**：
```dart
// 1. AI Prompt中要求返回category字段
// 2. 转换ImportCandidate时处理分类
ImportCandidate toImportCandidate(ParsedTransaction transaction, String ledgerId) {
  // 优先使用AI返回的分类
  String category = transaction.category ?? '';

  // 如果AI未返回分类或分类无效，使用规则引擎兜底
  if (category.isEmpty || !_isValidCategory(category)) {
    category = BillParser.inferCategory(
      transaction.merchant,
      transaction.note,
      transaction.type,
    );
  }

  return ImportCandidate(
    // ...
    category: category,
  );
}
```

**复用的分类推断能力**：
- **BillParser.inferCategory**：500+行关键词规则匹配
- 支持中英文关键词
- 优先级规则（具体 > 一般）
- 返回标准分类ID

**详细说明**：参见 `CATEGORY_INFERENCE.md`

### 5. 架构设计

#### 5.1 服务层架构（参考VoiceBatchImportService）
```
SmsImportService (主服务，独立于BillParser体系)
├── SmsReaderService (短信读取)
│   ├── 权限检查和申请
│   ├── 按时间范围查询
│   └── 发件人过滤
├── SmsParserService (短信解析)
│   ├── AI批量解析
│   ├── 结果转换为ImportCandidate
│   └── 错误处理
└── 复用现有服务
    ├── DuplicateScorer (重复检测)
    ├── ImportPreviewPage (预览确认)
    └── BatchImportService.executeImport (执行导入)
```

**职责划分**：
- **SmsImportService**：协调整个短信导入流程，管理会话状态
- **SmsReaderService**：封装短信读取逻辑，处理权限和平台差异
- **SmsParserService**：封装AI解析逻辑，处理批量解析和错误重试
- **复用现有服务**：重复检测、预览、导入等核心逻辑完全复用

**与VoiceBatchImportService的对比**：
| 特性 | VoiceBatchImportService | SmsImportService |
|------|------------------------|------------------|
| 输入源 | 音频文件 | 短信列表 |
| 识别方式 | 语音识别引擎 | AI文本解析 |
| 批量处理 | 逐条添加到会话 | 批量读取后解析 |
| 会话管理 | VoiceBatchSession | SmsImportSession |
| 输出格式 | ImportCandidate | ImportCandidate |
| 复用流程 | 预览+导入 | 预览+导入 |

**关键设计原则**：
- 短信导入生成的ImportCandidate格式与文件导入完全一致
- 复用现有的BatchImportService处理导入流程
- 复用现有的ImportPreviewPage进行预览确认
- 最大化代码复用，减少重复开发

#### 4.2 数据流
```
1. 用户选择时间范围
   ↓
2. SmsImportService.startImport() 创建导入会话
   ↓
3. SmsReaderService读取短信
   - 检查和申请权限
   - 按时间范围查询
   - 过滤发件人（银行、支付宝、微信等）
   ↓
4. SmsParserService批量解析
   - AI批量解析（15-20条/批）
   - 转换为ImportCandidate格式
   - 设置source="短信导入"
   ↓
5. DuplicateScorer检测重复
   - 复用现有的重复检测逻辑
   - 标记疑似重复的记录
   ↓
6. 返回解析结果给UI层
   ↓
7. ImportPreviewPage预览确认（复用现有界面）
   - 显示所有解析结果
   - 支持筛选（全部/待导入/跳过/重复）
   - 支持批量操作（智能选择/全部导入/全部跳过）
   - 支持单条记录编辑和修改
   - 用户确认后执行导入
   ↓
8. BatchImportService.executeImport() 批量导入到数据库
```

#### 4.3 核心类设计

**SmsMessage（数据模型）**
```dart
class SmsMessage {
  final String id;
  final String address;      // 发件人号码/名称
  final String body;         // 短信内容
  final DateTime date;       // 接收时间

  SmsMessage({
    required this.id,
    required this.address,
    required this.body,
    required this.date,
  });
}
```

**SmsReaderService（短信读取服务）**
```dart
class SmsReaderService {
  // 检查权限
  Future<bool> checkPermission();

  // 申请权限
  Future<bool> requestPermission();

  // 读取短信
  Future<List<SmsMessage>> readSms({
    required DateTime startDate,
    required DateTime endDate,
    List<String>? senderFilter,
    Function(int current, int total)? onProgress,
  });

  // 获取常见支付平台发件人列表
  List<String> getPaymentSenders() {
    return [
      '95588',  // 工商银行
      '95599',  // 农业银行
      '95533',  // 建设银行
      '95566',  // 中国银行
      '95555',  // 招商银行
      '支付宝',
      'Alipay',
      '微信支付',
      'WeChat',
      // ... 更多
    ];
  }
}
```

**ParsedTransaction（解析结果模型）**
```dart
class ParsedTransaction {
  final double amount;
  final TransactionType type;  // income/expense
  final DateTime date;
  final String? merchant;
  final String? note;
  final String? category;
  final String originalSmsBody;  // 保留原始短信内容

  ParsedTransaction({
    required this.amount,
    required this.type,
    required this.date,
    this.merchant,
    this.note,
    this.category,
    required this.originalSmsBody,
  });
}
```

**SmsParserService（短信解析服务）**
```dart
class SmsParserService {
  final AIService _aiService;

  // 批量解析短信
  Future<List<ParsedTransaction?>> parseBatch(
    List<SmsMessage> messages, {
    int batchSize = 15,
    Function(int current, int total)? onProgress,
  }) async {
    final results = <ParsedTransaction?>[];

    // 分批处理
    for (int i = 0; i < messages.length; i += batchSize) {
      final batch = messages.skip(i).take(batchSize).toList();
      final batchResults = await _parseSmsBatch(batch);
      results.addAll(batchResults);

      onProgress?.call(i + batch.length, messages.length);
    }

    return results;
  }

  // 解析单批短信（调用AI）
  Future<List<ParsedTransaction?>> _parseSmsBatch(
    List<SmsMessage> messages,
  ) async {
    final prompt = _buildPrompt(messages);
    final response = await _aiService.chat(prompt);
    return _parseAIResponse(response, messages);
  }

  // 转换为ImportCandidate
  ImportCandidate toImportCandidate(
    ParsedTransaction transaction,
    String ledgerId,
  ) {
    // 分类推断：AI直接分类 + 规则兜底
    String category = transaction.category ?? '';

    // 如果AI未返回分类或分类无效，使用规则引擎兜底
    if (category.isEmpty || !_isValidCategory(category)) {
      category = BillParser.inferCategory(
        transaction.merchant,
        transaction.note,
        transaction.type,
      );
    }

    return ImportCandidate(
      id: const Uuid().v4(),
      ledgerId: ledgerId,
      amount: transaction.amount,
      type: transaction.type,
      date: transaction.date,
      merchant: transaction.merchant,
      note: transaction.note,
      category: category,  // 使用推断的分类（AI + 规则兜底）
      source: '短信导入',
      sourceNote: transaction.originalSmsBody,  // 保留原始短信
      action: ImportAction.import_,  // 默认导入
    );
  }

  // 验证分类ID是否有效
  bool _isValidCategory(String categoryId) {
    return categoryId.isNotEmpty && !categoryId.startsWith('unknown');
  }
}
```

**SmsImportService（主服务）**
```dart
class SmsImportService {
  final SmsReaderService _readerService;
  final SmsParserService _parserService;
  final DuplicateScorer _duplicateScorer;

  // 缓存的候选记录（供预览使用）
  List<ImportCandidate>? _lastCandidates;

  SmsImportService({
    SmsReaderService? readerService,
    SmsParserService? parserService,
    DuplicateScorer? duplicateScorer,
  }) : _readerService = readerService ?? SmsReaderService(),
       _parserService = parserService ?? SmsParserService(),
       _duplicateScorer = duplicateScorer ?? DuplicateScorer();

  // 获取最后的候选记录
  List<ImportCandidate>? get lastCandidates => _lastCandidates;

  // 完整导入流程（返回候选记录供预览）
  Future<SmsImportResult> importFromSms({
    required DateTime startDate,
    required DateTime endDate,
    required String ledgerId,
    Function(ImportStage stage, int current, int total, String? message)? onProgress,
  }) async {
    try {
      // 1. 检查权限
      final hasPermission = await _readerService.checkPermission();
      if (!hasPermission) {
        final granted = await _readerService.requestPermission();
        if (!granted) {
          return SmsImportResult.error('未授予短信读取权限');
        }
      }

      // 2. 读取短信
      onProgress?.call(ImportStage.detecting, 0, 1, '正在读取短信...');
      final messages = await _readerService.readSms(
        startDate: startDate,
        endDate: endDate,
        senderFilter: _readerService.getPaymentSenders(),
        onProgress: (current, total) {
          onProgress?.call(ImportStage.detecting, current, total, '正在读取短信... ($current/$total)');
        },
      );

      if (messages.isEmpty) {
        return SmsImportResult.error('未找到相关短信');
      }

      // 3. 解析短信
      onProgress?.call(ImportStage.parsing, 0, messages.length, '正在解析短信...');
      final parsedTransactions = await _parserService.parseBatch(
        messages,
        onProgress: (current, total) {
          onProgress?.call(ImportStage.parsing, current, total, '正在解析短信... ($current/$total)');
        },
      );

      // 4. 转换为ImportCandidate
      final candidates = <ImportCandidate>[];
      for (final transaction in parsedTransactions) {
        if (transaction != null) {
          candidates.add(_parserService.toImportCandidate(transaction, ledgerId));
        }
      }

      if (candidates.isEmpty) {
        return SmsImportResult.error('未能解析出有效的交易记录');
      }

      // 5. 检测重复
      onProgress?.call(ImportStage.deduplicating, 0, candidates.length, '正在检查重复...');
      await _duplicateScorer.checkDuplicates(
        candidates,
        externalSource: ExternalSource.sms,
        onProgress: (current, total) {
          onProgress?.call(ImportStage.deduplicating, current, total, '正在检查重复... ($current/$total)');
        },
      );

      // 6. 缓存结果
      _lastCandidates = candidates;

      return SmsImportResult.success(
        candidates: candidates,
        totalSmsCount: messages.length,
        parsedCount: candidates.length,
      );
    } catch (e) {
      return SmsImportResult.error('导入失败: $e');
    }
  }

  // 清除缓存
  void clearCache() {
    _lastCandidates = null;
  }
}
```

**SmsImportResult（结果模型）**
```dart
class SmsImportResult {
  final bool success;
  final String? error;
  final List<ImportCandidate>? candidates;
  final int? totalSmsCount;
  final int? parsedCount;

  SmsImportResult.success({
    required this.candidates,
    required this.totalSmsCount,
    required this.parsedCount,
  }) : success = true, error = null;

  SmsImportResult.error(this.error)
    : success = false,
      candidates = null,
      totalSmsCount = null,
      parsedCount = null;
}
```

### 6. UI界面复用策略
**决策**：完全复用现有的ImportPreviewPage进行预览确认

**理由**：
- ImportPreviewPage已经实现了完善的预览确认功能
- 支持筛选、批量操作、单条编辑等所有必需功能
- 用户体验一致，降低学习成本
- 减少重复开发，提高代码质量

**实现方式**：
- 短信解析结果转换为标准的ImportCandidate格式
- 设置source字段为"短信导入"以区分来源
- 在ImportCandidate中保留原始短信内容作为sourceNote字段
- 直接传递给ImportPreviewPage进行展示

**ImportPreviewPage提供的功能**：
1. **列表展示**：显示所有解析出的交易候选记录
2. **筛选功能**：全部/待导入/跳过/重复
3. **批量操作**：智能选择/全部导入/全部跳过
4. **单条编辑**：点击记录可修改金额、类型、日期、商户、分类等
5. **重复标记**：自动标记疑似重复的记录
6. **统计信息**：显示总数、待导入、重复、跳过数量
7. **确认导入**：用户确认后执行实际导入操作

### 7. 权限处理策略
**决策**：采用渐进式权限申请流程

**流程**：
1. 用户点击"短信导入"按钮
2. 显示权限说明对话框，解释为什么需要短信权限
3. 用户同意后，调用系统权限申请
4. 如果用户拒绝，显示引导信息（如何在设置中开启）
5. 如果用户选择"不再询问"，提供跳转到应用设置的按钮

**隐私保护**：
- 短信内容仅在内存中临时处理，不存储到本地数据库
- 只上传短信文本到AI服务进行解析，不包含发件人号码
- 在隐私政策中明确说明短信权限用途

### 8. 性能优化

#### 8.1 短信读取优化
- 使用分页查询，每次读取1000条
- 在后台线程执行，避免阻塞UI
- 显示实时进度

#### 8.2 AI解析优化
- 批量解析：每批15-20条短信
- 并发控制：最多3个并发请求
- 缓存机制：相同短信内容不重复解析（使用短信内容hash作为key）

#### 8.3 内存优化
- 分批处理，避免一次性加载所有短信到内存
- 解析完成后立即释放短信内容
- 使用Stream处理大量数据

### 9. 错误处理

#### 9.1 权限错误
- 权限被拒绝：显示友好提示，引导用户开启权限
- 权限被永久拒绝：提供跳转到应用设置的按钮

#### 9.2 网络错误
- API调用失败：显示错误信息，提供重试按钮
- 超时：增加超时时间或减少批次大小
- 限流：显示提示，建议稍后重试

#### 9.3 解析错误
- AI返回格式错误：记录日志，跳过该批次
- 部分解析失败：继续处理成功的部分，统计失败数量
- 全部解析失败：显示错误信息，建议检查网络或联系客服

## 风险 / 权衡

### 风险1：AI解析准确率
**风险**：不同银行和支付平台的短信格式差异大，AI可能无法准确解析所有格式

**缓解措施**：
- 在Prompt中提供多种短信格式示例
- 允许用户在预览页面手动修正解析错误
- 收集解析失败的案例，持续优化Prompt
- 考虑后续版本添加本地规则匹配作为补充

### 风险2：API调用成本
**风险**：大量短信解析会产生较高的API调用成本

**缓解措施**：
- 批量解析减少调用次数
- 过滤非交易类短信（如验证码、广告）
- 限制单次导入的时间范围（建议不超过90天）
- 使用缓存避免重复解析

### 风险3：用户隐私担忧
**风险**：用户可能担心短信内容被上传到云端

**缓解措施**：
- 在权限申请时明确说明用途和数据处理方式
- 在隐私政策中详细说明
- 提供"仅本地处理"选项（后续版本考虑）
- 不存储短信原文，只保存解析后的交易记录

### 风险4：性能问题
**风险**：大量短信读取和解析可能导致应用卡顿

**缓解措施**：
- 使用后台线程处理
- 分批处理，显示进度
- 支持取消操作
- 限制单次处理的短信数量上限（如5000条）

## 迁移计划

### 阶段1：基础功能开发（第1-2周）
1. 添加telephony依赖和权限配置
2. 实现SmsReaderService和SmsParserService
3. 实现基本的UI界面

### 阶段2：集成和测试（第3周）
1. 集成到BatchImportService
2. 实现完整的导入流程
3. 单元测试和集成测试

### 阶段3：优化和发布（第4周）
1. 性能优化和错误处理
2. 用户体验优化
3. 文档和发布准备

### 回滚计划
- 如果发现严重问题，可以通过功能开关禁用短信导入入口
- 不影响现有的文件导入功能
- 可以安全回滚到之前版本

## 待决问题

1. **短信发件人过滤列表**：需要收集常见银行和支付平台的发件人号码/名称
2. **AI Prompt优化**：需要测试不同的Prompt格式，找到最佳解析效果
3. **批次大小**：需要测试确定最优的批量解析数量（15-20条）
4. **缓存策略**：是否需要缓存解析结果，缓存多久
5. **用户反馈机制**：是否需要提供"报告解析错误"功能，帮助改进
