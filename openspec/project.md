# 项目上下文

## 目的
AI Bookkeeping（智能记账）是一款AI驱动的智能记账应用，旨在通过多种智能输入方式（图片OCR识别、语音记账、邮箱账单自动解析）简化用户的记账流程，提供多维度的财务管理和丰富的数据分析报表。

## 技术栈

### 移动端 (app/)
- Flutter 3.x (Dart SDK ^3.10.0)
- Riverpod (状态管理)
- Dio (网络请求)
- SQLite (本地存储)
- flutter_secure_storage (安全存储)

### 后端 (server/)
- Python 3.11+
- FastAPI (Web框架)
- PostgreSQL (数据库)
- Redis (缓存)
- Alembic (数据库迁移)

### 管理后台 (admin-web/)
- Vue 3.4+
- TypeScript 5.3
- Vite 5.x (构建工具)
- Element Plus (UI组件库)
- Pinia (状态管理)
- ECharts (图表)

### AI服务
- 通义千问 Qwen (主要) - 图片识别、文本解析、账单解析
- 智谱 GLM (备选) - 当千问不可用时自动切换

## 项目约定

### 代码风格
- **Flutter**: 使用 flutter_lints 规范，遵循 Dart 官方风格指南
- **Python**: 使用 Ruff 进行 linting 和格式化，行宽 120 字符，双引号字符串
- **TypeScript/Vue**: 使用 ESLint + Prettier，遵循 Vue 3 组合式 API 风格

### 架构模式
- **Flutter**:
  - 分层架构：models/ (数据模型), services/ (业务逻辑), providers/ (状态管理), pages/ (页面), widgets/ (组件)
  - 使用 Riverpod 进行依赖注入和状态管理
  - 服务类采用单例模式
- **Python**:
  - FastAPI 路由分层
  - 使用 Pydantic 进行数据验证
  - 异步编程模式
- **Vue**:
  - 组合式 API (Composition API)
  - Pinia stores 进行状态管理

### 测试策略
- **Flutter**: widget_test.dart (组件测试), models_test.dart (模型测试), services/ (服务测试)
- **Python**: pytest + asyncio_mode="auto"
- **Vue**: Vitest

### Git工作流
- 分支策略：feature/* 功能分支，从 master 分支创建
- 提交信息格式：`<type>: <description>` (中文描述)
  - feat: 新功能
  - fix: 修复bug
  - docs: 文档更新
  - refactor: 重构
- 提交前自动运行 lint-staged 检查

## 领域上下文
- **账本 (Ledger)**: 用户的记账容器，支持多账本管理
- **交易 (Transaction)**: 收入/支出/转账记录
- **分类 (Category)**: 交易分类，支持自定义
- **账户 (Account)**: 资金账户（现金、银行卡、支付宝等）
- **预算 (Budget)**: 分类预算管理
- **家庭账本**: 多成员协作记账
- **小金库**: 储蓄目标管理
- **游戏化**: 记账成就和激励系统

## 重要约束
- 敏感配置（API密钥、数据库密码）通过环境变量配置，不提交到代码仓库
- 移动端支持离线使用，数据本地优先
- 支持国际化 (i18n)，默认中文
- 遵循 OWASP 安全最佳实践

## 外部依赖
- **AI服务**: 阿里云通义千问 API、智谱 GLM API
- **存储服务**: MinIO (对象存储)
- **推送服务**: 本地通知 (flutter_local_notifications)
- **地理位置**: Geolocator
