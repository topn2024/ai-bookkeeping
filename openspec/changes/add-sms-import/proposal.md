# 变更：在智能账单导入页面增加短信导入交易记录功能

## 为什么
用户的银行、支付宝、微信等支付通知短信包含大量交易信息，手动逐条记账效率低下。通过自动读取和解析短信，可以快速批量导入交易记录，大幅提升记账效率。

## 变更内容
- 在智能账单导入页面（SmartImportPage）新增"短信导入"入口按钮
- 实现短信读取功能（仅Android平台，需要READ_SMS权限）
- 支持用户自定义时间范围筛选短信
- 使用AI智能解析短信内容，提取交易金额、时间、商户等信息
- 复用现有的重复判断策略（DuplicateScorer），防止重复导入
- 将解析后的交易记录转换为ImportCandidate格式
- 复用现有的预览确认流程（ImportPreviewPage）
- iOS平台显示功能不可用提示

## 架构设计
- **不继承BillParser**：短信导入采用独立服务架构（参考VoiceBatchImportService）
- **原因**：输入源不同（短信列表 vs 文件字节流），解析方式不同（AI vs 规则）
- **详细对比**：参见 `COMPARISON.md` - 短信导入 vs 微信/支付宝文件导入架构对比
- **架构文档**：参见 `ARCHITECTURE.md` - 完整的架构设计说明

## 影响
- 受影响规范：smart-import（智能导入功能）
- 受影响代码：
  - app/lib/pages/import/smart_import_page.dart（新增短信导入入口）
  - app/lib/services/import/（新增短信读取和解析服务）
  - app/lib/services/import/batch_import_service.dart（集成短信导入流程）
  - app/lib/services/import/duplicate_scorer.dart（复用重复判断逻辑）
  - app/android/app/src/main/AndroidManifest.xml（新增READ_SMS权限声明）
  - app/pubspec.yaml（可能需要添加短信读取相关依赖）

## 技术考虑
- Android平台需要动态申请READ_SMS权限，需要向用户说明权限用途
- 短信数量可能很大，需要分页加载和进度显示
- AI解析需要调用通义千问API，需要处理网络异常和API限流
- 短信格式多样，需要设计灵活的解析策略
- 需要过滤非交易类短信，减少无效解析
