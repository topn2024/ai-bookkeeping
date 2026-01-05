# AI智能记账 - 功能分类标识文档

> 版本：1.0
> 日期：2026-01-01
> 目的：区分APP功能、管理控制台功能、周边辅助功能，便于基于方案进行开发

---

## 目录

1. [分类标识说明](#1-分类标识说明)
2. [1.X版本已实现功能清单](#2-1x版本已实现功能清单)
3. [2.0版本新增功能清单](#3-20版本新增功能清单)
4. [管理控制台功能清单](#4-管理控制台功能清单)
5. [周边辅助功能清单](#5-周边辅助功能清单)
6. [开发优先级参考](#6-开发优先级参考)

---

## 1. 分类标识说明

### 1.1 功能分类标识

| 标识 | 分类 | 说明 | 技术栈 |
|------|------|------|--------|
| 📱 | **APP端功能** | 手机端用户使用的功能 | Flutter + Dart |
| 🖥️ | **管理控制台功能** | 后台管理系统功能 | Vue 3 + TypeScript + Element Plus |
| 🔧 | **周边辅助功能** | 开发、测试、部署相关 | Python/Bash/PowerShell |
| 🌐 | **后端API** | 服务端接口 | FastAPI + Python |

### 1.2 实现状态标识

| 标识 | 状态 | 说明 |
|------|------|------|
| ✅ | 已完成 | 1.X版本已实现 |
| 🆕 | 新增 | 2.0版本新增功能 |
| 🔄 | 升级 | 需要升级/增强的功能 |
| 📋 | 规划 | 规划中，尚未开发 |

### 1.3 优先级标识

| 优先级 | 说明 |
|--------|------|
| P0 | 核心功能，必须实现 |
| P1 | 重要功能，优先实现 |
| P2 | 增强功能，择机实现 |
| P3 | 远期功能，后续规划 |

---

## 2. 1.X版本已实现功能清单

### 2.1 📱 APP端功能 (136项已完成)

#### 2.1.1 核心记账功能

| 功能模块 | 功能名称 | 状态 | 优先级 | 代码位置参考 |
|----------|----------|------|--------|--------------|
| 手动记账 | 支出记录 | ✅ | P0 | `app/lib/pages/add_transaction_page.dart` |
| 手动记账 | 收入记录 | ✅ | P0 | `app/lib/pages/add_transaction_page.dart` |
| 手动记账 | 转账记录 | ✅ | P0 | `app/lib/pages/add_transaction_page.dart` |
| 手动记账 | 快速记账模板 | ✅ | P1 | `app/lib/pages/quick_entry_page.dart` |
| 手动记账 | 定时记账 | ✅ | P1 | `app/lib/services/recurring_provider.dart` |
| 手动记账 | 拆分交易 | ✅ | P2 | `app/lib/pages/add_transaction_page.dart` |
| 手动记账 | 交易长按操作 | ✅ | P1 | `app/lib/widgets/transaction_item.dart` |
| 手动记账 | 交易快速编辑 | ✅ | P1 | `app/lib/pages/transaction_list_page.dart` |
| 手动记账 | 交易快速删除 | ✅ | P1 | `app/lib/pages/transaction_list_page.dart` |

#### 2.1.2 AI智能记账

| 功能模块 | 功能名称 | AI模型 | 状态 | 代码位置参考 |
|----------|----------|--------|------|--------------|
| AI识别 | 图片识别记账 | qwen-vl-plus | ✅ | `app/lib/pages/image_recognition_page.dart` |
| AI识别 | 语音记账 | qwen-omni-turbo | ✅ | `app/lib/pages/voice_recognition_page.dart` |
| AI识别 | 语音多笔记账 | qwen-omni-turbo | ✅ | `app/lib/services/qwen_service.dart` |
| AI识别 | 邮箱账单解析 | qwen-plus | ✅ | `server/app/services/email_service.py` |
| AI识别 | 智能分类建议 | qwen-turbo | ✅ | `server/app/api/v1/ai.py` |

#### 2.1.3 账目管理

| 功能模块 | 功能名称 | 状态 | 优先级 | 代码位置参考 |
|----------|----------|------|--------|--------------|
| 账本管理 | 多账本 | ✅ | P0 | `app/lib/providers/book_provider.dart` |
| 账本管理 | 账本切换 | ✅ | P0 | `app/lib/pages/main_navigation.dart` |
| 账本管理 | 默认账本 | ✅ | P1 | `app/lib/providers/book_provider.dart` |
| 账本管理 | 账本共享 | ✅ | P2 | `app/lib/pages/member_management_page.dart` |
| 成员协作 | 成员邀请 | ✅ | P1 | `app/lib/pages/join_invite_page.dart` |
| 成员协作 | 角色权限 | ✅ | P1 | `app/lib/models/book_member.dart` |
| 成员协作 | 成员管理 | ✅ | P1 | `app/lib/pages/member_management_page.dart` |
| 成员协作 | 成员预算 | ✅ | P2 | `app/lib/providers/budget_provider.dart` |
| 成员协作 | 消费审批 | ✅ | P2 | `server/app/api/v1/approval.py` |
| 账户管理 | 现金账户 | ✅ | P0 | `app/lib/providers/account_provider.dart` |
| 账户管理 | 银行卡 | ✅ | P0 | `app/lib/providers/account_provider.dart` |
| 账户管理 | 信用卡 | ✅ | P0 | `app/lib/providers/credit_card_provider.dart` |
| 账户管理 | 电子钱包 | ✅ | P0 | `app/lib/providers/account_provider.dart` |
| 账户管理 | 投资账户 | ✅ | P1 | `app/lib/providers/account_provider.dart` |
| 账户管理 | 账户余额 | ✅ | P0 | `app/lib/providers/account_provider.dart` |
| 账户管理 | 账户转账 | ✅ | P0 | `app/lib/pages/add_transaction_page.dart` |
| 分类管理 | 预设分类 | ✅ | P0 | `app/lib/providers/category_provider.dart` |
| 分类管理 | 自定义分类 | ✅ | P0 | `app/lib/pages/category_management_page.dart` |
| 分类管理 | 分类图标 | ✅ | P1 | `app/lib/pages/category_management_page.dart` |
| 分类管理 | 子分类 | ✅ | P1 | `app/lib/providers/category_provider.dart` |
| 分类管理 | 分类排序 | ✅ | P2 | `app/lib/pages/category_management_page.dart` |

#### 2.1.4 预算与目标

| 功能模块 | 功能名称 | 状态 | 优先级 | 代码位置参考 |
|----------|----------|------|--------|--------------|
| 预算管理 | 月度预算 | ✅ | P0 | `app/lib/providers/budget_provider.dart` |
| 预算管理 | 分类预算 | ✅ | P1 | `app/lib/providers/budget_provider.dart` |
| 预算管理 | 预算提醒 | ✅ | P1 | `app/lib/services/notification_service.dart` |
| 预算管理 | 预算结转 | ✅ | P2 | `app/lib/providers/budget_provider.dart` |
| 预算管理 | 零基预算(基础) | ✅ | P1 | `app/lib/providers/budget_provider.dart` |
| 预算管理 | 钱龄指标(基础) | ✅ | P1 | `app/lib/models/money_age.dart` |
| 财务目标 | 储蓄目标 | ✅ | P1 | `app/lib/providers/savings_goal_provider.dart` |
| 财务目标 | 月度开支目标 | ✅ | P1 | `app/lib/providers/budget_provider.dart` |
| 财务目标 | 还债目标 | ✅ | P1 | `app/lib/providers/debt_provider.dart` |
| 财务目标 | 目标进度 | ✅ | P1 | `app/lib/widgets/goal_progress.dart` |
| 债务管理 | 债务录入 | ✅ | P1 | `app/lib/providers/debt_provider.dart` |
| 债务管理 | 债务模板 | ✅ | P2 | `app/lib/models/debt.dart` |
| 债务管理 | 还款记录 | ✅ | P1 | `app/lib/providers/debt_provider.dart` |
| 债务管理 | 还款模拟器 | ✅ | P2 | `app/lib/pages/debt_simulator_page.dart` |
| 债务管理 | 雪球/雪崩策略 | ✅ | P2 | `app/lib/services/debt_strategy_service.dart` |

#### 2.1.5 统计报表

| 功能模块 | 功能名称 | 状态 | 优先级 | 代码位置参考 |
|----------|----------|------|--------|--------------|
| 基础统计 | 收支总览 | ✅ | P0 | `app/lib/pages/home_page.dart` |
| 基础统计 | 日/周/月/年统计 | ✅ | P0 | `app/lib/pages/statistics_page.dart` |
| 基础统计 | 分类占比 | ✅ | P0 | `app/lib/widgets/category_pie_chart.dart` |
| 基础统计 | 趋势图表 | ✅ | P0 | `app/lib/widgets/trend_chart.dart` |
| 基础统计 | 同比/环比 | ✅ | P1 | `app/lib/services/stats_service.dart` |
| 高级报表 | 年度报告 | ✅ | P1 | `app/lib/pages/annual_report_page.dart` |
| 高级报表 | 自定义报表 | ✅ | P2 | `app/lib/pages/custom_report_page.dart` |
| 高级报表 | 成员对比 | ✅ | P2 | `app/lib/pages/member_comparison_page.dart` |
| 高级报表 | 报销统计 | ✅ | P2 | `app/lib/pages/reimbursement_page.dart` |
| 资产分析 | 净资产追踪 | ✅ | P1 | `app/lib/pages/assets_page.dart` |
| 资产分析 | 资产趋势 | ✅ | P1 | `app/lib/widgets/asset_trend_chart.dart` |
| 资产分析 | 资产分布 | ✅ | P1 | `app/lib/widgets/asset_distribution.dart` |

#### 2.1.6 数据管理

| 功能模块 | 功能名称 | 状态 | 优先级 | 代码位置参考 |
|----------|----------|------|--------|--------------|
| 数据同步 | 云端备份 | ✅ | P0 | `app/lib/services/backup_service.dart` |
| 数据同步 | 多设备同步 | ✅ | P0 | `app/lib/services/sync_service.dart` |
| 数据同步 | 数据导出 | ✅ | P1 | `app/lib/services/export_service.dart` |
| 数据同步 | 数据导入 | ✅ | P1 | `app/lib/services/import_service.dart` |
| 数据同步 | 备份管理 | ✅ | P1 | `app/lib/pages/backup_management_page.dart` |
| 离线模式 | 离线记账 | ✅ | P0 | `app/lib/services/offline_queue_service.dart` |
| 离线模式 | 本地缓存 | ✅ | P0 | `app/lib/services/database_service.dart` |
| 离线模式 | 自动同步 | ✅ | P1 | `app/lib/services/auto_sync_service.dart` |
| 离线模式 | 冲突处理 | ✅ | P1 | `app/lib/services/conflict_resolver.dart` |

#### 2.1.7 用户系统

| 功能模块 | 功能名称 | 状态 | 优先级 | 代码位置参考 |
|----------|----------|------|--------|--------------|
| 账户管理 | 用户注册 | ✅ | P0 | `app/lib/pages/register_page.dart` |
| 账户管理 | 用户登录 | ✅ | P0 | `app/lib/pages/login_page.dart` |
| 账户管理 | 个人资料 | ✅ | P0 | `app/lib/pages/profile_page.dart` |
| 账户管理 | 第三方登录 | ✅ | P1 | `app/lib/services/oauth_service.dart` |
| 账户管理 | 找回密码 | ✅ | P1 | `app/lib/pages/forgot_password_page.dart` |
| 安全加密 | HTTPS传输 | ✅ | P0 | `app/lib/services/http_service.dart` |
| 安全加密 | Token管理 | ✅ | P0 | `app/lib/providers/auth_provider.dart` |

#### 2.1.8 个性化设置

| 功能模块 | 功能名称 | 状态 | 优先级 | 代码位置参考 |
|----------|----------|------|--------|--------------|
| 主题换肤 | 深色模式 | ✅ | P0 | `app/lib/core/theme.dart` |
| 主题换肤 | 多主题色 | ✅ | P1 | `app/lib/pages/theme_settings_page.dart` |
| 主题换肤 | 自定义主题(会员) | ✅ | P2 | `app/lib/pages/custom_theme_page.dart` |
| 国际化 | 简体中文 | ✅ | P0 | `app/lib/l10n/app_zh.arb` |
| 国际化 | 繁体中文 | ✅ | P1 | `app/lib/l10n/app_zh_TW.arb` |
| 国际化 | 英语 | ✅ | P0 | `app/lib/l10n/app_en.arb` |
| 国际化 | 日语/韩语 | ✅ | P2 | `app/lib/l10n/app_ja.arb`, `app_ko.arb` |
| 多货币 | 8种货币支持 | ✅ | P0 | `app/lib/core/currency.dart` |
| 多货币 | 手动汇率 | ✅ | P1 | `app/lib/pages/exchange_rate_page.dart` |
| 多货币 | 跨币种转账 | ✅ | P1 | `app/lib/pages/add_transaction_page.dart` |

#### 2.1.9 APP升级

| 功能模块 | 功能名称 | 状态 | 优先级 | 代码位置参考 |
|----------|----------|------|--------|--------------|
| 版本检查 | 自动检查更新 | ✅ | P0 | `app/lib/services/app_upgrade_service.dart` |
| 版本检查 | 强制更新 | ✅ | P0 | `app/lib/widgets/app_update_dialog.dart` |
| 版本检查 | 灰度发布 | ✅ | P1 | `server/app/api/v1/app_upgrade.py` |
| APK下载 | 全量下载 | ✅ | P0 | `app/lib/services/background_download_service.dart` |
| APK下载 | 断点续传 | ✅ | P1 | `app/lib/services/background_download_service.dart` |
| 增量更新 | bspatch应用 | ✅ | P1 | `app/android/app/src/main/kotlin/.../BsPatchHelper.kt` |

### 2.2 🌐 后端API (支撑APP端)

| 模块 | API路由前缀 | 状态 | 代码位置 |
|------|------------|------|----------|
| 用户认证 | `/api/v1/auth` | ✅ | `server/app/api/v1/auth.py` |
| 用户管理 | `/api/v1/users` | ✅ | `server/app/api/v1/users.py` |
| 账本管理 | `/api/v1/books` | ✅ | `server/app/api/v1/books.py` |
| 交易管理 | `/api/v1/transactions` | ✅ | `server/app/api/v1/transactions.py` |
| 账户管理 | `/api/v1/accounts` | ✅ | `server/app/api/v1/accounts.py` |
| 分类管理 | `/api/v1/categories` | ✅ | `server/app/api/v1/categories.py` |
| 预算管理 | `/api/v1/budgets` | ✅ | `server/app/api/v1/budgets.py` |
| 债务管理 | `/api/v1/debts` | ✅ | `server/app/api/v1/debts.py` |
| 储蓄目标 | `/api/v1/savings-goals` | ✅ | `server/app/api/v1/savings_goals.py` |
| 账单提醒 | `/api/v1/bill-reminders` | ✅ | `server/app/api/v1/bill_reminders.py` |
| AI功能 | `/api/v1/ai` | ✅ | `server/app/api/v1/ai.py` |
| 同步备份 | `/api/v1/sync` | ✅ | `server/app/api/v1/sync.py` |
| 文件管理 | `/api/v1/files` | ✅ | `server/app/api/v1/files.py` |
| 应用升级 | `/api/v1/app-upgrade` | ✅ | `server/app/api/v1/app_upgrade.py` |

---

## 3. 2.0版本新增功能清单

### 3.1 📱 APP端新增功能

#### 3.1.1 钱龄智能分析系统 (第4章)

| 功能名称 | 状态 | 优先级 | 设计文档位置 |
|----------|------|--------|--------------|
| 钱龄计算引擎 | 🆕 | P1 | `docs/design/app_v2_design.md#4.3` |
| FIFO资源池模型 | 🆕 | P1 | `docs/design/app_v2_design.md#4.3.1` |
| 钱龄健康等级 | 🆕 | P1 | `docs/design/app_v2_design.md#4.2` |
| 钱龄仪表盘卡片 | 🆕 | P1 | `docs/design/app_v2_design.md#4.4.1` |
| 钱龄趋势图 | 🆕 | P1 | `docs/design/app_v2_design.md#4.4.2` |
| 钱龄详情页 | 🆕 | P1 | `docs/design/app_v2_design.md#4.4` |
| 按分类钱龄分析 | 🆕 | P2 | `docs/design/app_v2_design.md#4.3.2` |
| 钱龄改善建议 | 🆕 | P2 | `docs/design/app_v2_design.md#4.3.2` |
| 历史数据钱龄重建 | 🆕 | P1 | `docs/design/app_v2_design.md#17.2` |

#### 3.1.2 零基预算与小金库系统 (第5章)

| 功能名称 | 状态 | 优先级 | 设计文档位置 |
|----------|------|--------|--------------|
| 零基预算分配向导 | 🆕 | P1 | `docs/design/app_v2_design.md#5` |
| 智能分配建议算法 | 🆕 | P1 | `docs/design/app_v2_design.md#5` |
| 小金库管理 | 🆕 | P1 | `docs/design/app_v2_design.md#5` |
| 小金库概览页 | 🆕 | P1 | `docs/design/app_v2_design.md#17.2` |
| 资金分配页 | 🆕 | P1 | `docs/design/app_v2_design.md#17.2` |
| 交易-小金库自动关联 | 🆕 | P2 | `docs/design/app_v2_design.md#17.2` |
| 预算执行进度追踪 | 🔄 | P1 | `docs/design/app_v2_design.md#5` |
| 预算结转功能增强 | 🔄 | P2 | `docs/design/app_v2_design.md#5` |

#### 3.1.3 金融习惯培养系统 (第6章)

| 功能名称 | 状态 | 优先级 | 设计文档位置 |
|----------|------|--------|--------------|
| 习惯打卡系统 | 🆕 | P2 | `docs/design/app_v2_design.md#6` |
| 积分奖励系统 | 🆕 | P2 | `docs/design/app_v2_design.md#6` |
| 成就徽章系统 | 🆕 | P2 | `docs/design/app_v2_design.md#6` |
| 财务健康画像分析 | 🆕 | P2 | `docs/design/app_v2_design.md#6` |
| 专家任务推荐 | 🆕 | P3 | `docs/design/app_v2_design.md#6` |
| 周期挑战 | 🆕 | P3 | `docs/design/app_v2_design.md#6` |

#### 3.1.4 AI智能识别系统增强 (第7章)

| 功能名称 | 状态 | 优先级 | 设计文档位置 |
|----------|------|--------|--------------|
| 语音识别准确率优化 | 🔄 | P2 | `docs/design/app_v2_design.md#7` |
| 图像识别准确率优化 | 🔄 | P2 | `docs/design/app_v2_design.md#7` |
| 智能分类建议增强 | 🔄 | P2 | `docs/design/app_v2_design.md#7` |
| AI消费模式识别 | 🆕 | P2 | `docs/design/app_v2_design.md#1.4.2` |
| 异常消费检测 | 🆕 | P2 | `docs/design/app_v2_design.md#1.4.2` |
| 支出预测功能 | 🆕 | P2 | `docs/design/app_v2_design.md#1.4.2` |
| 个性化财务报告 | 🆕 | P2 | `docs/design/app_v2_design.md#1.4.2` |

#### 3.1.5 数据导入导出系统增强 (第8章)

| 功能名称 | 状态 | 优先级 | 设计文档位置 |
|----------|------|--------|--------------|
| Excel/CSV批量导入 | 🔄 | P2 | `docs/design/batch_import_export_design.md` |
| 微信账单解析 | 🆕 | P2 | `docs/design/batch_import_export_design.md` |
| 支付宝账单解析 | 🆕 | P2 | `docs/design/batch_import_export_design.md` |
| 智能去重方案 | 🆕 | P2 | `docs/design/batch_import_export_design.md` |
| OFX/QIF格式支持 | 🆕 | P3 | `docs/design/batch_import_export_design.md` |
| 数据导出多格式 | 🔄 | P2 | `docs/design/batch_import_export_design.md` |

#### 3.1.6 数据联动与可视化 (第9章)

| 功能名称 | 状态 | 优先级 | 设计文档位置 |
|----------|------|--------|--------------|
| 图表点击下钻 | 🆕 | P1 | `docs/design/app_v2_design.md#9` |
| 分类饼图下钻 | 🆕 | P1 | `docs/design/app_v2_design.md#17.2` |
| 统计页面关联交易列表 | 🆕 | P1 | `docs/design/app_v2_design.md#1.4.2` |
| 时间段选择联动 | 🆕 | P1 | `docs/design/app_v2_design.md#1.4.2` |
| 跨页面筛选保持 | 🆕 | P1 | `docs/design/app_v2_design.md#1.4.2` |
| 面包屑导航 | 🆕 | P1 | `docs/design/app_v2_design.md#17.2` |
| 下钻过渡动画 | 🆕 | P2 | `docs/design/app_v2_design.md#17.2` |

#### 3.1.7 地理位置智能化 (第11章)

| 功能名称 | 状态 | 优先级 | 设计文档位置 |
|----------|------|--------|--------------|
| 精确位置服务 | 🆕 | P2 | `docs/design/app_v2_design.md#11` |
| 消费场景识别 | 🆕 | P2 | `docs/design/app_v2_design.md#3.2.3` |
| 位置增强钱龄 | 🆕 | P2 | `docs/design/app_v2_design.md#3.2.3` |
| 地理围栏预警 | 🆕 | P3 | `docs/design/app_v2_design.md#3.2.3` |
| 本地化类目推荐 | 🆕 | P3 | `docs/design/app_v2_design.md#3.2.3` |
| 异地消费识别 | 🆕 | P3 | `docs/design/app_v2_design.md#3.2.3` |

#### 3.1.8 体验升级 (第12章)

| 功能名称 | 状态 | 优先级 | 设计文档位置 |
|----------|------|--------|--------------|
| Material Design 3主题 | 🆕 | P1 | `docs/design/app_v2_design.md#17.2` |
| 流畅动画效果 | 🆕 | P1 | `docs/design/app_v2_design.md#1.4.2` |
| 加载骨架屏 | 🆕 | P2 | `docs/design/app_v2_design.md#1.4.2` |
| 手势操作优化 | 🆕 | P2 | `docs/design/app_v2_design.md#1.4.2` |
| 响应式布局适配 | 🆕 | P2 | `docs/design/app_v2_design.md#1.4.2` |
| 性能优化 | 🔄 | P1 | `docs/design/app_v2_design.md#17.2` |

### 3.2 🌐 后端API新增

| 模块 | API路由 | 状态 | 说明 |
|------|---------|------|------|
| 钱龄分析 | `/api/v2/money-age` | 🆕 | 钱龄计算和统计 |
| 小金库 | `/api/v2/vaults` | 🆕 | 小金库CRUD |
| 资源池 | `/api/v2/resource-pools` | 🆕 | 资源池管理 |
| 智能洞察 | `/api/v2/insights` | 🆕 | AI洞察和建议 |
| 习惯培养 | `/api/v2/habits` | 🆕 | 习惯打卡、成就 |
| 位置服务 | `/api/v2/locations` | 🆕 | 位置智能功能 |

---

## 4. 管理控制台功能清单

### 4.1 🖥️ 管理后台功能 (94项已完成)

#### 4.1.1 仪表盘模块 (12项)

| 功能ID | 功能名称 | 状态 | 代码位置 |
|--------|----------|------|----------|
| DB-001 | 今日新增用户 | ✅ | `admin-web/src/views/dashboard/Index.vue` |
| DB-002 | 今日活跃用户 | ✅ | `admin-web/src/views/dashboard/Index.vue` |
| DB-003 | 今日交易笔数 | ✅ | `admin-web/src/views/dashboard/Index.vue` |
| DB-004 | 今日交易金额 | ✅ | `admin-web/src/views/dashboard/Index.vue` |
| DB-005 | 累计用户数 | ✅ | `admin-web/src/views/dashboard/Index.vue` |
| DB-006 | 累计交易笔数 | ✅ | `admin-web/src/views/dashboard/Index.vue` |
| DB-007 | 用户增长趋势图 | ✅ | `admin-web/src/views/dashboard/Index.vue` |
| DB-008 | 交易趋势图 | ✅ | `admin-web/src/views/dashboard/Index.vue` |
| DB-009 | 交易类型分布 | ✅ | `admin-web/src/views/dashboard/Index.vue` |
| DB-010 | 用户活跃热力图 | ✅ | `admin-web/src/views/dashboard/Index.vue` |
| DB-011 | TOP10活跃用户 | ✅ | `admin-web/src/views/dashboard/Index.vue` |
| DB-012 | 实时交易流水 | ✅ | `admin-web/src/views/dashboard/Index.vue` |

#### 4.1.2 用户管理模块 (15项)

| 功能ID | 功能名称 | 状态 | 代码位置 |
|--------|----------|------|----------|
| UM-001 | 用户列表展示 | ✅ | `admin-web/src/views/users/List.vue` |
| UM-002 | 关键词搜索 | ✅ | `admin-web/src/views/users/List.vue` |
| UM-003 | 高级筛选 | ✅ | `admin-web/src/views/users/List.vue` |
| UM-004 | 多字段排序 | ✅ | `admin-web/src/views/users/List.vue` |
| UM-005 | 批量导出 | ✅ | `admin-web/src/views/users/List.vue` |
| UM-006 | 批量操作 | ✅ | `admin-web/src/views/users/List.vue` |
| UM-007 | 基本信息查看 | ✅ | `admin-web/src/views/users/Detail.vue` |
| UM-008 | 账户概览 | ✅ | `admin-web/src/views/users/Detail.vue` |
| UM-009 | 登录历史 | ✅ | `admin-web/src/views/users/Detail.vue` |
| UM-010 | 关联数据查看 | ✅ | `admin-web/src/views/users/Detail.vue` |
| UM-011 | 用户行为分析 | ✅ | `admin-web/src/views/users/Detail.vue` |
| UM-012 | 禁用/启用账户 | ✅ | `admin-web/src/views/users/List.vue` |
| UM-013 | 重置密码 | ✅ | `admin-web/src/views/users/List.vue` |
| UM-014 | 清除登录状态 | ✅ | `admin-web/src/views/users/List.vue` |
| UM-015 | 删除用户 | ✅ | `admin-web/src/views/users/List.vue` |

#### 4.1.3 数据管理模块 (18项)

| 功能ID | 功能名称 | 状态 | 代码位置 |
|--------|----------|------|----------|
| DM-001 | 全局交易列表 | ✅ | `admin-web/src/views/data/Transactions.vue` |
| DM-002 | 交易搜索 | ✅ | `admin-web/src/views/data/Transactions.vue` |
| DM-003 | 交易详情 | ✅ | `admin-web/src/views/data/Transactions.vue` |
| DM-004 | 异常交易标记 | ✅ | `admin-web/src/views/data/Transactions.vue` |
| DM-005 | 交易数据导出 | ✅ | `admin-web/src/views/data/Transactions.vue` |
| DM-006 | 交易统计 | ✅ | `admin-web/src/views/data/Transactions.vue` |
| DM-007 | 账本列表 | ✅ | `admin-web/src/views/data/Books.vue` |
| DM-008 | 账户列表 | ✅ | `admin-web/src/views/data/Accounts.vue` |
| DM-009 | 账户类型统计 | ✅ | `admin-web/src/views/data/Accounts.vue` |
| DM-010 | 数据完整性检查 | ✅ | `admin-web/src/views/data/Integrity.vue` |
| DM-011 | 系统分类列表 | ✅ | `admin-web/src/views/data/Categories.vue` |
| DM-012 | 添加系统分类 | ✅ | `admin-web/src/views/data/Categories.vue` |
| DM-013 | 编辑系统分类 | ✅ | `admin-web/src/views/data/Categories.vue` |
| DM-014 | 分类使用统计 | ✅ | `admin-web/src/views/data/Categories.vue` |
| DM-015 | 备份列表 | ✅ | `admin-web/src/views/data/Backups.vue` |
| DM-016 | 备份存储统计 | ✅ | `admin-web/src/views/data/Backups.vue` |
| DM-017 | 过期备份清理 | ✅ | `admin-web/src/views/data/Backups.vue` |
| DM-018 | 备份策略配置 | ✅ | `admin-web/src/views/data/Backups.vue` |

#### 4.1.4 统计分析模块 (16项)

| 功能ID | 功能名称 | 状态 | 代码位置 |
|--------|----------|------|----------|
| SA-001 | 用户增长分析 | ✅ | `admin-web/src/views/statistics/Users.vue` |
| SA-002 | 用户留存分析 | ✅ | `admin-web/src/views/statistics/Retention.vue` |
| SA-003 | 用户流失预警 | ✅ | `admin-web/src/views/statistics/Churn.vue` |
| SA-004 | 用户画像分析 | ✅ | `admin-web/src/views/statistics/Portrait.vue` |
| SA-005 | 新老用户对比 | ✅ | `admin-web/src/views/statistics/Comparison.vue` |
| SA-006 | 收支趋势分析 | ✅ | `admin-web/src/views/statistics/Transactions.vue` |
| SA-007 | 分类消费排行 | ✅ | `admin-web/src/views/statistics/Categories.vue` |
| SA-008 | 平均交易金额 | ✅ | `admin-web/src/views/statistics/Transactions.vue` |
| SA-009 | 交易时段分布 | ✅ | `admin-web/src/views/statistics/Transactions.vue` |
| SA-010 | 交易频率分析 | ✅ | `admin-web/src/views/statistics/Transactions.vue` |
| SA-011 | 功能使用率 | ✅ | `admin-web/src/views/statistics/Features.vue` |
| SA-012 | 会员转化分析 | ✅ | `admin-web/src/views/statistics/Conversion.vue` |
| SA-013 | 付费用户分析 | ✅ | `admin-web/src/views/statistics/Premium.vue` |
| SA-014 | 日报生成 | ✅ | `admin-web/src/views/reports/Daily.vue` |
| SA-015 | 周报/月报 | ✅ | `admin-web/src/views/reports/Periodic.vue` |
| SA-016 | 自定义报表 | ✅ | `admin-web/src/views/reports/Custom.vue` |

#### 4.1.5 系统监控模块 (10项)

| 功能ID | 功能名称 | 状态 | 代码位置 |
|--------|----------|------|----------|
| SM-001 | API健康检查 | ✅ | `admin-web/src/views/monitor/Health.vue` |
| SM-002 | 数据库状态 | ✅ | `admin-web/src/views/monitor/Resources.vue` |
| SM-003 | Redis状态 | ✅ | `admin-web/src/views/monitor/Resources.vue` |
| SM-004 | 存储空间监控 | ✅ | `admin-web/src/views/monitor/Resources.vue` |
| SM-005 | API响应时间 | ✅ | `admin-web/src/views/monitor/Performance.vue` |
| SM-006 | 请求量统计 | ✅ | `admin-web/src/views/monitor/Performance.vue` |
| SM-007 | 错误率统计 | ✅ | `admin-web/src/views/monitor/Performance.vue` |
| SM-008 | 慢查询日志 | ✅ | `admin-web/src/views/monitor/SlowQueries.vue` |
| SM-009 | 告警规则配置 | ✅ | `admin-web/src/views/monitor/Alerts.vue` |
| SM-010 | 告警通知配置 | ✅ | `admin-web/src/views/monitor/Alerts.vue` |

#### 4.1.6 系统设置模块 (14项)

| 功能ID | 功能名称 | 状态 | 代码位置 |
|--------|----------|------|----------|
| SS-001 | 系统信息配置 | ✅ | `admin-web/src/views/settings/General.vue` |
| SS-002 | 注册开关 | ✅ | `admin-web/src/views/settings/General.vue` |
| SS-003 | 邮件服务配置 | ✅ | `admin-web/src/views/settings/Email.vue` |
| SS-004 | 短信服务配置 | ✅ | `admin-web/src/views/settings/Sms.vue` |
| SS-005 | 千问API配置 | ✅ | `admin-web/src/views/settings/AI.vue` |
| SS-006 | 模型参数调整 | ✅ | `admin-web/src/views/settings/AI.vue` |
| SS-007 | 调用限额设置 | ✅ | `admin-web/src/views/settings/AI.vue` |
| SS-008 | 登录策略配置 | ✅ | `admin-web/src/views/settings/Security.vue` |
| SS-009 | IP白名单 | ✅ | `admin-web/src/views/settings/Security.vue` |
| SS-010 | 二次确认配置 | ✅ | `admin-web/src/views/settings/Security.vue` |
| SS-011 | 管理员列表 | ✅ | `admin-web/src/views/settings/Admins.vue` |
| SS-012 | 添加管理员 | ✅ | `admin-web/src/views/settings/Admins.vue` |
| SS-013 | 编辑管理员 | ✅ | `admin-web/src/views/settings/Admins.vue` |
| SS-014 | 删除管理员 | ✅ | `admin-web/src/views/settings/Admins.vue` |

#### 4.1.7 应用版本管理

| 功能ID | 功能名称 | 状态 | 代码位置 |
|--------|----------|------|----------|
| AV-001 | 版本列表 | ✅ | `admin-web/src/views/settings/AppVersions.vue` |
| AV-002 | 创建版本 | ✅ | `admin-web/src/views/settings/AppVersions.vue` |
| AV-003 | APK上传 | ✅ | `admin-web/src/views/settings/AppVersions.vue` |
| AV-004 | 发布版本 | ✅ | `admin-web/src/views/settings/AppVersions.vue` |
| AV-005 | 灰度配置 | ✅ | `admin-web/src/views/settings/AppVersions.vue` |
| AV-006 | 升级统计 | ✅ | `admin-web/src/views/settings/AppVersions.vue` |

#### 4.1.8 通用功能 (9项)

| 功能ID | 功能名称 | 状态 | 代码位置 |
|--------|----------|------|----------|
| GF-001 | 管理员登录 | ✅ | `admin-web/src/views/auth/Login.vue` |
| GF-002 | MFA二次验证 | ✅ | `admin-web/src/views/auth/MFA.vue` |
| GF-003 | 密码修改 | ✅ | `admin-web/src/views/settings/Profile.vue` |
| GF-004 | 登出 | ✅ | `admin-web/src/layouts/MainLayout.vue` |
| GF-005 | 操作日志记录 | ✅ | `server/admin/api/logs.py` |
| GF-006 | 日志查询 | ✅ | `admin-web/src/views/logs/Audit.vue` |
| GF-007 | 日志导出 | ✅ | `admin-web/src/views/logs/Audit.vue` |
| GF-008 | 个人信息修改 | ✅ | `admin-web/src/views/settings/Profile.vue` |
| GF-009 | 通知偏好设置 | ✅ | `admin-web/src/views/settings/Notifications.vue` |

### 4.2 🌐 管理后台API

| 模块 | API路由前缀 | 状态 | 代码位置 |
|------|------------|------|----------|
| 认证 | `/admin/auth` | ✅ | `server/admin/api/auth.py` |
| 仪表盘 | `/admin/dashboard` | ✅ | `server/admin/api/dashboard.py` |
| 用户管理 | `/admin/users` | ✅ | `server/admin/api/users.py` |
| 数据管理 | `/admin/data` | ✅ | `server/admin/api/data.py` |
| 统计分析 | `/admin/statistics` | ✅ | `server/admin/api/statistics.py` |
| 系统监控 | `/admin/monitoring` | ✅ | `server/admin/api/monitoring.py` |
| 系统设置 | `/admin/settings` | ✅ | `server/admin/api/settings.py` |
| 审计日志 | `/admin/logs` | ✅ | `server/admin/api/logs.py` |
| 应用版本 | `/admin/app-versions` | ✅ | `server/admin/api/app_versions.py` |

---

## 5. 周边辅助功能清单

### 5.1 🔧 测试用例

#### 5.1.1 后端测试 (pytest)

| 测试文件 | 测试范围 | 状态 | 代码位置 |
|----------|----------|------|----------|
| test_auth.py | 用户认证测试 | ✅ | `server/tests/test_auth.py` |
| test_books.py | 账本管理测试 | ✅ | `server/tests/test_books.py` |
| test_transactions.py | 交易记录测试 | ✅ | `server/tests/test_transactions.py` |
| test_budgets.py | 预算统计测试 | ✅ | `server/tests/test_budgets.py` |
| test_debts_and_goals.py | 债务储蓄测试 | ✅ | `server/tests/test_debts_and_goals.py` |
| test_collaboration.py | 成员协作测试 | ✅ | `server/tests/test_collaboration.py` |
| test_ai_features.py | AI功能测试 | ✅ | `server/tests/test_ai_features.py` |
| test_security.py | 安全测试 | ✅ | `server/tests/test_security.py` |
| test_admin_api.py | 管理后台测试 | ✅ | `server/tests/test_admin_api.py` |
| test_e2e_scenarios.py | 端到端测试 | ✅ | `server/tests/test_e2e_scenarios.py` |
| test_app_upgrade.py | 升级功能测试 | ✅ | `server/tests/test_app_upgrade.py` |
| conftest.py | 测试配置fixtures | ✅ | `server/tests/conftest.py` |

#### 5.1.2 前端测试 (Flutter)

| 测试文件 | 测试范围 | 状态 | 代码位置 |
|----------|----------|------|----------|
| widget_test.dart | Widget单元测试 | ✅ | `app/test/widget_test.dart` |
| models_test.dart | 数据模型测试 | ✅ | `app/test/models_test.dart` |
| integration_test.dart | 集成测试 | ✅ | `app/test/integration_test.dart` |

#### 5.1.3 2.0版本新增测试 (需开发)

| 测试文件 | 测试范围 | 状态 |
|----------|----------|------|
| test_money_age.py | 钱龄计算测试 | 🆕 |
| test_vaults.py | 小金库测试 | 🆕 |
| test_habits.py | 习惯培养测试 | 🆕 |
| money_age_test.dart | 钱龄UI测试 | 🆕 |
| vault_test.dart | 小金库UI测试 | 🆕 |

### 5.2 🔧 编译脚本

| 脚本名称 | 功能 | 平台 | 代码位置 |
|----------|------|------|----------|
| build.dart | Flutter构建脚本 | 全平台 | `scripts/build.dart` |
| flutter-dev.bat | Flutter开发启动 | Windows | `scripts/flutter-dev.bat` |
| run-app.bat | 应用运行脚本 | Windows | `scripts/run-app.bat` |
| run-app-android.bat | Android运行脚本 | Windows | `scripts/run-app-android.bat` |
| start-app.bat | 应用启动脚本 | Windows | `scripts/start-app.bat` |
| install-apk.bat | APK安装脚本 | Windows | `scripts/install-apk.bat` |

### 5.3 🔧 发布脚本

| 脚本名称 | 功能 | 平台 | 代码位置 |
|----------|------|------|----------|
| publish_apk.sh | APK发布脚本 | Linux/Mac/Git Bash | `scripts/publish_apk.sh` |
| publish_version.py | 版本发布脚本 | 全平台 | `scripts/publish_version.py` |
| build.env | 构建环境配置 | 全平台 | `scripts/build.env` |

### 5.4 🔧 环境配置脚本

| 脚本名称 | 功能 | 平台 | 代码位置 |
|----------|------|------|----------|
| setup-android-dev-env.ps1 | Android开发环境配置 | Windows | `scripts/setup-android-dev-env.ps1` |
| install-android-env.ps1 | Android环境安装 | Windows | `scripts/install-android-env.ps1` |
| install-android-env.bat | Android环境安装 | Windows | `scripts/install-android-env.bat` |
| check-env.ps1 | 环境检查 | Windows | `scripts/check-env.ps1` |
| update-flutter-path.ps1 | Flutter路径更新 | Windows | `scripts/update-flutter-path.ps1` |
| update-ide-flutter-config.ps1 | IDE配置更新 | Windows | `scripts/update-ide-flutter-config.ps1` |

### 5.5 🔧 模拟器/ADB脚本

| 脚本名称 | 功能 | 平台 | 代码位置 |
|----------|------|------|----------|
| start-emulator.ps1 | 模拟器启动 | Windows | `scripts/start-emulator.ps1` |
| start_emulator.bat | 模拟器启动 | Windows | `scripts/start_emulator.bat` |
| start_emulator_window.bat | 模拟器窗口启动 | Windows | `scripts/start_emulator_window.bat` |
| start_emulator_background.bat | 后台启动模拟器 | Windows | `scripts/start_emulator_background.bat` |
| start-adb.bat | ADB启动 | Windows | `scripts/start-adb.bat` |
| start_adb_5038.bat | ADB端口5038启动 | Windows | `scripts/start_adb_5038.bat` |
| start_adb_5038.ps1 | ADB端口5038启动 | Windows | `scripts/start_adb_5038.ps1` |
| configure_adb_port_5038.ps1 | ADB端口配置 | Windows | `scripts/configure_adb_port_5038.ps1` |
| adb.bat | ADB封装脚本 | Windows | `scripts/adb.bat` |
| check_emulator_status.ps1 | 模拟器状态检查 | Windows | `scripts/check_emulator_status.ps1` |
| kill_emulator.ps1 | 关闭模拟器 | Windows | `scripts/kill_emulator.ps1` |

### 5.6 🔧 服务端部署脚本

| 脚本名称 | 功能 | 平台 | 代码位置 |
|----------|------|------|----------|
| setup-server-env.ps1 | 服务端环境配置 | Windows | `scripts/setup-server-env.ps1` |
| setup-server-docker.ps1 | Docker环境配置 | Windows | `scripts/setup-server-docker.ps1` |
| check-server-env.ps1 | 服务端环境检查 | Windows | `scripts/check-server-env.ps1` |
| install-docker.ps1 | Docker安装 | Windows | `scripts/install-docker.ps1` |

### 5.7 🔧 测试运行脚本

| 脚本名称 | 功能 | 平台 | 代码位置 |
|----------|------|------|----------|
| run_all_tests.bat | 运行全部测试 | Windows | `scripts/run_all_tests.bat` |
| run_all_tests.sh | 运行全部测试 | Linux/Mac | `scripts/run_all_tests.sh` |
| test-flutter.bat | Flutter测试 | Windows | `scripts/test-flutter.bat` |

### 5.8 🔧 数据库迁移脚本

| 脚本位置 | 功能 | 状态 |
|----------|------|------|
| `server/migrations/*.sql` | 数据库迁移脚本 | ✅ |
| `server/scripts/migrate.py` | 迁移执行脚本 | ✅ |
| `server/alembic/` | Alembic迁移配置 | ✅ |

### 5.9 🔧 增量更新相关

| 文件位置 | 功能 | 状态 |
|----------|------|------|
| `server/scripts/generate_patch.py` | 生成增量补丁 | ✅ |
| `app/android/.../BsPatchHelper.kt` | 原生bspatch实现 | ✅ |

---

## 6. 开发优先级参考

### 6.1 2.0版本开发阶段

```
┌────────────────────────────────────────────────────────────────────┐
│                       2.0 版本开发路线图                            │
├────────────────────────────────────────────────────────────────────┤
│                                                                    │
│  阶段一：基础架构 (Alpha)                                          │
│  ├── 📱 数据库迁移脚本 (v14 -> v20)                               │
│  ├── 📱 ResourcePool 资源池模型                                    │
│  ├── 📱 BudgetVault 小金库模型                                     │
│  ├── 📱 Provider 架构升级 (CrudNotifier)                          │
│  ├── 🌐 资源池API                                                  │
│  └── 🔧 单元测试框架                                               │
│                                                                    │
│  阶段二：核心功能 (Beta)                                           │
│  ├── 📱 钱龄计算引擎 (MoneyAgeCalculator)                         │
│  ├── 📱 历史数据钱龄重建                                           │
│  ├── 📱 零基预算分配服务                                           │
│  ├── 📱 小金库CRUD功能                                             │
│  ├── 📱 数据联动导航服务                                           │
│  ├── 🌐 钱龄/小金库API                                             │
│  └── 🔧 集成测试                                                   │
│                                                                    │
│  阶段三：体验优化 (RC)                                             │
│  ├── 📱 钱龄仪表盘卡片                                             │
│  ├── 📱 钱龄趋势图                                                 │
│  ├── 📱 小金库概览页                                               │
│  ├── 📱 分类饼图下钻                                               │
│  ├── 📱 Material Design 3 主题                                    │
│  ├── 📱 下钻过渡动画                                               │
│  └── 🔧 性能测试                                                   │
│                                                                    │
│  阶段四：发布准备 (Release)                                        │
│  ├── 🔧 全量测试                                                   │
│  ├── 🔧 文档更新                                                   │
│  ├── 🔧 应用商店准备                                               │
│  └── 🔧 灰度发布脚本                                               │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

### 6.2 功能优先级矩阵

| 优先级 | 功能类别 | 功能模块 | 状态 |
|--------|----------|----------|------|
| **P0** | 📱 APP | 基础记账、账户管理、分类管理、统计图表 | ✅ 已有 |
| **P0** | 🖥️ 控制台 | 仪表盘、用户管理、基础认证 | ✅ 已有 |
| **P0** | 🔧 辅助 | 测试框架、编译脚本 | ✅ 已有 |
| **P1** | 📱 APP | 钱龄分析系统 | 🆕 新增 |
| **P1** | 📱 APP | 零基预算系统 | 🆕 新增 |
| **P1** | 📱 APP | 小金库系统 | 🆕 新增 |
| **P1** | 📱 APP | 数据联动下钻 | 🆕 新增 |
| **P1** | 🌐 API | 钱龄/小金库API | 🆕 新增 |
| **P1** | 🔧 辅助 | 2.0版本测试用例 | 🆕 新增 |
| **P2** | 📱 APP | AI识别优化 | 🔄 升级 |
| **P2** | 📱 APP | 批量导入增强 | 🔄 升级 |
| **P2** | 📱 APP | 金融习惯培养 | 🆕 新增 |
| **P2** | 📱 APP | 位置智能功能 | 🆕 新增 |
| **P3** | 📱 APP | 家庭共享增强 | 📋 规划 |
| **P3** | 📱 APP | 智能投资建议 | 📋 规划 |

---

## 文档版本历史

| 版本 | 日期 | 变更内容 |
|------|------|----------|
| 1.0 | 2026-01-01 | 初始版本，整理1.X和2.0功能分类 |

---

*本文档基于 `ARCHITECTURE.md`、`FEATURES.md`、`app_v2_design.md`、`ADMIN_PLATFORM_FEATURES.md`、`TESTING.md` 等文档整理*
