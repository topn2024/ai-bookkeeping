# 更新日志

## [未发布]

### 新增功能

#### 帮助文档系统 (2024-01-28)

完整的帮助文档系统，为用户提供全面的应用使用指导。

**基础架构**
- 创建 HelpContent 和 HelpStep 数据模型，支持 JSON 序列化
- 实现 HelpContentService 服务层
  - 从 assets 加载 20 个模块的 JSON 文件
  - 内存缓存机制（pageId 和 module 双重索引）
  - 智能搜索功能（多维度匹配：标题、描述、关键词、场景、步骤）
  - 搜索历史记录（使用 SharedPreferences 持久化）
  - 使用统计功能（记录查看次数，展示热门内容）
- 重构帮助页面 UI
  - TabBar 结构：快速入门、按模块浏览、常见问题
  - 实时搜索功能
  - 热门问题展示

**UI 组件**
- HelpSearchWidget - 搜索组件
- ModuleListWidget - 模块列表组件
- PageHelpDetailWidget - 页面详情组件（支持反馈功能）
- HelpIconButton - 帮助图标按钮（可添加到任何页面）
- FloatingHelpButton - 浮动帮助按钮

**帮助内容**
- 为 20 个功能模块创建完整的帮助内容
  - 首页与快速记账（6页）
  - 统计报表（12页）
  - 账户管理（6页）
  - 零基预算（8页）
  - 语音交互（8页）
  - 设置中心（10页）
  - 其他 14 个模块的基础内容

**增强功能**
- 页面内帮助入口（HelpIconButton 组件）
- 帮助内容使用统计
- 帮助内容反馈功能（有帮助/无帮助）
- 热门问题展示

**文档**
- 帮助内容编写规范（docs/HELP_CONTENT_GUIDE.md）
- 开发文档（docs/HELP_SYSTEM_DEV.md）
- 实施总结（openspec/changes/enhance-help-documentation-system/IMPLEMENTATION_SUMMARY.md）

**技术特性**
- 数据驱动架构，易于维护和更新
- 模块化设计，20 个独立模块文件
- 智能搜索算法，相关度评分
- 用户友好的 UI 界面
- 完整的使用统计和反馈系统

### 改进

- 优化帮助内容的搜索体验
- 改进帮助页面的导航结构
- 增强用户反馈收集机制

### 文件变更

**新增文件**
- app/lib/models/help_content.dart
- app/lib/services/help_content_service.dart
- app/lib/widgets/help/help_search_widget.dart
- app/lib/widgets/help/module_list_widget.dart
- app/lib/widgets/help/page_help_detail_widget.dart
- app/lib/widgets/help/help_icon_button.dart
- app/assets/help/*.json (20个模块文件)
- docs/HELP_CONTENT_GUIDE.md
- docs/HELP_SYSTEM_DEV.md

**修改文件**
- app/lib/pages/help_page.dart (完全重构)
- app/pubspec.yaml (添加 assets 配置)

### 统计数据

- 代码行数：约 3,000+ 行
- 模块数量：20 个
- 帮助页面：70+ 个
- 文件数量：30+ 个新文件

---

## 历史版本

### [2.0.12] - 2024-01-27

之前的更新内容...

