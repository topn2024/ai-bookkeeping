# AI 智能记账 - 问题追踪清单

> 最后更新: 2026-01-01

## 问题状态说明
- ✅ 已解决
- 🔄 进行中
- ❌ 待处理
- ⚠️ 已知限制

---

## 已解决问题

### #001 同步功能编译错误
**状态**: ✅ 已解决
**发现日期**: 2025-12-30
**解决日期**: 2025-12-30

**问题描述**:
- `custom_theme_page.dart:215` - CustomTheme? 类型传递给需要 CustomTheme 的方法
- `sync_settings_page.dart` - 未定义的 getters (retentionDays, totalCount, transactionCount, deletedCount)
- `sync_provider.dart` - SyncStatus 命名冲突（ambiguous import）

**解决方案**:
1. 添加 `!` 操作符断言非空
2. 在 CleanupSettings、CleanupResult、CleanupPreview 类中添加别名 getters
3. 使用 `hide SyncStatus` 解决导入冲突

**相关文件**:
- `app/lib/pages/custom_theme_page.dart`
- `app/lib/pages/sync_settings_page.dart`
- `app/lib/providers/sync_provider.dart`
- `app/lib/models/sync.dart`
- `app/lib/services/data_cleanup_service.dart`

---

### #002 登录页面 oauthState 未定义
**状态**: ✅ 已解决
**发现日期**: 2025-12-30
**解决日期**: 2025-12-30

**问题描述**:
`login_page.dart` 中使用了 `oauthState` 变量，但只调用了 `ref.watch(oauthProvider)` 而没有赋值给变量。

**解决方案**:
```dart
// 修改前
ref.watch(oauthProvider);

// 修改后
final oauthState = ref.watch(oauthProvider);
```

**相关文件**:
- `app/lib/pages/login_page.dart`

---

### #003 flutter install 导致用户数据丢失
**状态**: ✅ 已解决（记录教训）
**发现日期**: 2025-12-30
**解决日期**: 2025-12-30

**问题描述**:
使用 `flutter install` 命令更新 APK 会先卸载旧版本再安装，导致用户数据丢失。

**解决方案**:
**永远使用 `adb install -r` 命令更新 APK**

| 命令 | 效果 | 用户数据 |
|------|------|---------|
| `adb install -r xxx.apk` | 替换安装 | ✅ 保留 |
| `flutter install` | 先卸载再安装 | ❌ 丢失 |

**相关文件**: 无（操作流程问题）

---

### #004 语音记账 API 错误: No API-key provided
**状态**: ✅ 已解决
**发现日期**: 2025-12-30
**解决日期**: 2025-12-30

**问题描述**:
语音记账功能报错 "API错误: No API-key provided"。

**根本原因**:
Flutter 端的 `QwenService` 直接调用千问 API，API key 需要通过 `--dart-define` 在构建时传入，而不是从后端获取。

**解决方案**:
1. 构建时传入 API key:
```bash
flutter build apk --debug \
  --dart-define=QWEN_API_KEY=xxx \
  --dart-define=API_BASE_URL=xxx
```

2. 更新构建脚本 `scripts/build.dart`，自动从 `scripts/build.env` 读取配置

3. 创建 `scripts/build.env` 配置文件（已加入 .gitignore）

**相关文件**:
- `app/lib/core/config.dart`
- `app/lib/services/qwen_service.dart`
- `scripts/build.dart`
- `scripts/build.env`

---

### #005 快速记账后返回首页 SnackBar 继续显示
**状态**: ✅ 已解决
**发现日期**: 2025-12-30
**解决日期**: 2025-12-30

**问题描述**:
使用快速记账功能生成账单后，返回首页时底部的 SnackBar 提示仍然显示。

**根本原因**:
SnackBar 显示时间为 4 秒，用户在此期间返回首页，SnackBar 会跟随到首页继续显示。

**解决方案**:
在 `QuickEntryPage` 的 `dispose` 方法中清除 SnackBar：
```dart
@override
void dispose() {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  super.dispose();
}
```

**相关文件**:
- `app/lib/pages/quick_entry_page.dart`

---

### #006 服务器 Supervisor 配置指向错误目录
**状态**: ✅ 已解决
**发现日期**: 2025-12-30
**解决日期**: 2025-12-30

**问题描述**:
服务器上新增的 `/api/v1/config/ai` 端点返回 404，尽管代码已正确部署。

**根本原因**:
Supervisor 配置文件中的 `directory` 参数指向了 `/home/ai-bookkeeping/app/`（Flutter 应用目录），而不是正确的 `/home/ai-bookkeeping/app/server/`（Python 后端目录）。导致 uvicorn 加载了旧版本的 `app` 模块。

**解决方案**:
修改 `/etc/supervisor/conf.d/ai-bookkeeping.conf`:
```ini
# 修改前
directory=/home/ai-bookkeeping/app

# 修改后
directory=/home/ai-bookkeeping/app/server
```

同时修复日志目录权限：
```bash
mkdir -p /home/ai-bookkeeping/app/server/logs
chown -R ai-bookkeeping:ai-bookkeeping /home/ai-bookkeeping/app/server/logs
```

**相关文件**:
- `/etc/supervisor/conf.d/ai-bookkeeping.conf`（服务器端）
- `server/app/api/v1/config.py`
- `server/app/api/v1/__init__.py`

---

### #007 API Key 从服务器获取失败
**状态**: ✅ 已解决
**发现日期**: 2025-12-30
**解决日期**: 2025-12-30

**问题描述**:
语音记账功能报错 "API错误: No API-key provided"。APP 尝试从服务器获取 API Key 但失败（404）。

**根本原因**:
1. 服务器端 `/api/v1/config/ai` 路由未加载（参见 #006）
2. APP 端需要在用户登录后从服务器获取 API Key 并缓存

**解决方案**:
1. 修复服务器端路由加载问题（#006）
2. 在 `auth_provider.dart` 的登录/注册成功后调用 `appConfig.fetchFromServer()`
3. 在 `config.dart` 中实现从服务器获取和缓存 API Key 的逻辑

**相关文件**:
- `app/lib/core/config.dart`
- `app/lib/providers/auth_provider.dart`
- `server/app/api/v1/config.py`

---

### #008 语音识别返回空转写（transcription 为空）
**状态**: ✅ 已解决
**发现日期**: 2025-12-30
**解决日期**: 2025-12-30

**问题描述**:
语音记账时，千问 API 返回的 JSON 中 `transcription` 字段为空字符串，`amount` 为 null，导致无法识别金额。

**根本原因**:
音频输入格式不符合阿里云百炼平台 qwen-omni-turbo 模型的 API 规范。

错误格式：
```dart
{'audio': 'data:audio/wav;base64,$base64Audio'}
```

正确格式：
```dart
{
  'type': 'input_audio',
  'input_audio': {
    'data': base64Audio,
    'format': 'wav',
  }
}
```

**解决方案**:
修改 `qwen_service.dart` 中的 `recognizeAudio` 方法，使用正确的音频输入结构。

**相关文件**:
- `app/lib/services/qwen_service.dart`

**参考文档**:
- [阿里云 Qwen-Omni 文档](https://help.aliyun.com/zh/model-studio/qwen-omni)

---

### #009 分类管理对话框无法显示
**状态**: ✅ 已解决
**发现日期**: 2025-12-30
**解决日期**: 2025-12-30

**问题描述**:
在分类管理页面点击一级分类旁边的 + 按钮（添加子分类），屏幕会变暗（对话框遮罩层出现），但对话框内容不显示。用户无法点击其他按钮，也无法看到添加子分类的界面。

**根本原因**:
`showDialog` 在特定页面上下文中（ListView.builder 内的 ListTile）存在渲染问题。具体原因可能与以下因素有关：
- StatefulBuilder 在对话框中的状态管理
- Material 3 主题与对话框的兼容性
- 嵌套滚动视图（GridView 在 SingleChildScrollView 内）

**解决方案**:
将对话框改为全屏页面导航方式：
```dart
// 修改前：使用 showDialog
showDialog(
  context: context,
  builder: (context) => AlertDialog(...),
);

// 修改后：使用 Navigator.push
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (context) => _CategoryEditPage(...),
  ),
);
```

创建了独立的 `_CategoryEditPage` Widget 类来处理分类的添加和编辑。

**相关文件**:
- `app/lib/pages/category_management_page.dart`

---

### #010 管理控制台用户管理操作按钮换行
**状态**: ✅ 已解决
**发现日期**: 2026-01-01
**解决日期**: 2026-01-01

**问题描述**:
用户管理页面的操作列（查看、禁用、删除三个按钮）被分布到两行显示，布局不整齐。

**根本原因**:
操作列宽度设置为180px，不足以容纳三个按钮在同一行显示。

**解决方案**:
将操作列宽度从180px增加到220px：
```vue
<!-- 修改前 -->
<el-table-column label="操作" width="180" fixed="right">

<!-- 修改后 -->
<el-table-column label="操作" width="220" fixed="right">
```

**相关文件**:
- `admin-web/src/views/users/List.vue`

---

### #011 管理控制台账本管理操作按钮换行
**状态**: ✅ 已解决
**发现日期**: 2026-01-01
**解决日期**: 2026-01-01

**问题描述**:
账本管理页面的操作列（交易、详情两个按钮）被分布到两行显示，而且不对齐。

**根本原因**:
操作列宽度设置为120px，不足以容纳两个按钮在同一行显示。

**解决方案**:
将操作列宽度从120px增加到160px：
```vue
<!-- 修改前 -->
<el-table-column label="操作" width="120" fixed="right">

<!-- 修改后 -->
<el-table-column label="操作" width="160" fixed="right">
```

**相关文件**:
- `admin-web/src/views/data/Books.vue`

---

### #012 管理控制台表格容器不必要的滚动条
**状态**: ✅ 已解决
**发现日期**: 2026-01-01
**解决日期**: 2026-01-01

**问题描述**:
管理控制台多个页面的表格区域出现不必要的滚动条，表格只差一点点就出现横向滚动条，不美观。

**根本原因**:
`.table-container` 样式设置了 `overflow: hidden`，导致表格固定列的阴影效果被裁切，Element Plus 表格自动添加滚动容器。

**解决方案**:
将 `overflow: hidden` 改为 `overflow: visible`：
```scss
// 修改前
.table-container {
  overflow: hidden;
}

// 修改后
.table-container {
  overflow: visible;
}
```

**相关文件**:
- `admin-web/src/assets/styles/main.scss`

---

### #013 仪表盘交易类型分布饼图无数据
**状态**: ✅ 已解决
**发现日期**: 2026-01-01
**解决日期**: 2026-01-01

**问题描述**:
仪表盘页面的"交易类型分布"饼图显示空白，没有任何数据。

**根本原因**:
饼图使用 `stats.income_count` 和 `stats.expense_count` 渲染数据，但 `/dashboard/stats` API 返回的数据结构中并不包含这些字段。正确的数据来源应该是 `/dashboard/distribution/transaction-type` API。

**解决方案**:
1. 添加 `fetchTypeDistribution()` 函数调用正确的 API
2. 修改 `renderTransactionPieChart()` 使用 `typeDistribution` 数据
3. 在 `onMounted` 中调用 `fetchTypeDistribution()`

```typescript
// 添加状态
const typeDistribution = ref<any>(null)

// 添加获取数据函数
const fetchTypeDistribution = async () => {
  const data = await getTypeDistribution('30d')
  typeDistribution.value = data
  renderTransactionPieChart()
}

// 修改渲染函数使用正确的数据
const dist = typeDistribution.value || {}
const incomeCount = dist.income_count || 0
const expenseCount = dist.expense_count || 0
const transferCount = dist.transfer_count || 0
```

**相关文件**:
- `admin-web/src/views/dashboard/Index.vue`
- `admin-web/src/api/dashboard.ts`

---

### #014 仪表盘最近交易金额显示为空
**状态**: ✅ 已解决
**发现日期**: 2026-01-01
**解决日期**: 2026-01-01

**问题描述**:
仪表盘页面"最近交易记录"表格中，金额列显示为空。但点击"查看全部"跳转到交易管理页面后，金额是正常显示的。

**根本原因**:
1. 前端使用 `row.type` 判断收入/支出，但 API 返回的字段是 `transaction_type`（1=支出, 2=收入, 3=转账）
2. 金额字段 `row.amount` 已经是格式化的字符串（如 `¥123.00`），但前端又调用 `formatMoney()` 尝试格式化，导致显示异常

**解决方案**:
1. 修改类型判断逻辑：`row.type === 'income'` → `row.transaction_type === 2`
2. 金额直接显示，不再调用 `formatMoney()`：

```vue
<!-- 修改前 -->
<el-tag :type="row.type === 'income' ? 'success' : 'danger'">
  {{ row.type === 'income' ? '收入' : '支出' }}
</el-tag>
<span>{{ row.type === 'income' ? '+' : '-' }}{{ formatMoney(row.amount) }}</span>

<!-- 修改后 -->
<el-tag :type="row.transaction_type === 2 ? 'success' : 'danger'">
  {{ row.type_name || (row.transaction_type === 2 ? '收入' : '支出') }}
</el-tag>
<span>{{ row.amount }}</span>
```

**相关文件**:
- `admin-web/src/views/dashboard/Index.vue`

---

### #015 交易详情显示 Invalid Date
**状态**: ✅ 已解决
**发现日期**: 2026-01-01
**解决日期**: 2026-01-01

**问题描述**:
交易管理、分类管理、备份管理、账本管理等页面的日期字段显示 "Invalid Date"，而不是格式化的日期或占位符。

**根本原因**:
JavaScript 的 `new Date()` 处理 null 或无效字符串时返回 "Invalid Date"，前端的 `formatDateTime` 函数没有对这种情况做处理。

**解决方案**:
修改各页面的 `formatDateTime` 函数，添加空值检查和 `isNaN` 验证：
```typescript
const formatDateTime = (date: string | null | undefined) => {
  if (!date) return '-'
  const d = new Date(date)
  if (isNaN(d.getTime())) return '-'
  return d.toLocaleString('zh-CN')
}
```

**相关文件**:
- `admin-web/src/views/data/Transactions.vue`
- `admin-web/src/views/data/Categories.vue`
- `admin-web/src/views/data/Backups.vue`
- `admin-web/src/views/data/Books.vue`

---

### #016 交易管理页面汇总统计始终为0
**状态**: ✅ 已解决
**发现日期**: 2026-01-01
**解决日期**: 2026-01-01

**问题描述**:
交易管理页面顶部的总交易数、总收入、总支出等统计数据始终显示为0。

**根本原因**:
后端 API `/admin/transactions` 返回的响应中不包含 `summary` 统计数据，前端期望的 `response.summary` 为 undefined。

**解决方案**:
1. 在 `admin/schemas/data_management.py` 添加 `TransactionSummary` schema
2. 修改 `TransactionListResponse` 添加 `summary` 字段
3. 在 `admin/api/transactions.py` 的 `list_transactions` 函数中添加汇总统计查询

```python
class TransactionSummary(BaseModel):
    total_count: int = 0
    total_income: Decimal = Decimal("0")
    total_expense: Decimal = Decimal("0")
    net_income: Decimal = Decimal("0")

# 在 list_transactions 中添加汇总查询
summary_query = select(
    func.count(Transaction.id).label("total_count"),
    func.coalesce(func.sum(case((Transaction.transaction_type == 2, Transaction.amount), else_=0)), 0).label("total_income"),
    func.coalesce(func.sum(case((Transaction.transaction_type == 1, Transaction.amount), else_=0)), 0).label("total_expense"),
)
```

**相关文件**:
- `server/admin/schemas/data_management.py`
- `server/admin/api/transactions.py`

---

### #017 用户管理"最后登录"字段名称不准确
**状态**: ✅ 已解决
**发现日期**: 2026-01-01
**解决日期**: 2026-01-01

**问题描述**:
用户管理页面表格中 `last_login_at` 字段的列标题显示为"最后登录"，但实际该字段反映的是用户的最后活跃时间。

**解决方案**:
将列标题从"最后登录"改为"最后活跃"：
```vue
<!-- 修改前 -->
<el-table-column prop="last_login_at" label="最后登录" width="180">

<!-- 修改后 -->
<el-table-column prop="last_login_at" label="最后活跃" width="180">
```

**相关文件**:
- `admin-web/src/views/users/List.vue`

---

### #018 仪表盘今日交易统计使用错误的时间字段
**状态**: ✅ 已解决
**发现日期**: 2026-01-01
**解决日期**: 2026-01-01

**问题描述**:
仪表盘页面的"今日交易"统计数据按照数据同步时间（`created_at`）计算，而不是交易发生时间（`transaction_date`）。

**根本原因**:
后端 `dashboard.py` 中使用 `func.date(Transaction.created_at) == today` 查询今日交易，`created_at` 是记录入库时间而非业务发生时间。

**解决方案**:
修改后端查询条件，使用 `transaction_date` 字段：
```python
# 修改前
.where(func.date(Transaction.created_at) == today)

# 修改后
.where(Transaction.transaction_date == today)
```

**相关文件**:
- `server/admin/api/dashboard.py`

---

### #019 账本管理货币和类型显示问题
**状态**: ✅ 已解决
**发现日期**: 2026-01-01
**解决日期**: 2026-01-01

**问题描述**:
1. 账本管理页面货币字段显示为空
2. 类型字段使用图标标签（tag）显示，但图标不够清晰

**根本原因**:
1. 货币字段没有默认值，当 `currency` 为 null 时显示空白
2. 类型字段使用 `type` 属性（期望字符串如 "personal"），但 API 返回的是 `book_type`（整数 0/1/2）
3. 类型标签只有颜色没有文字，不够直观

**解决方案**:
1. 添加货币默认值：`{{ row.currency || 'CNY' }}`
2. 修改类型列使用 `book_type` 字段并添加文字说明
3. 更新 `getBookTypeTag` 和 `getBookTypeText` 函数支持数字类型：

```typescript
const getBookTypeText = (type: number | string) => {
  const typeNum = typeof type === 'string' ? parseInt(type) : type
  const map: Record<number, string> = {
    0: '个人账本',
    1: '家庭账本',
    2: '商业账本',
  }
  return map[typeNum] || `类型${type}`
}
```

**相关文件**:
- `admin-web/src/views/data/Books.vue`

---

### #020 分类管理详情按钮报错及统计为0
**状态**: ✅ 已解决
**发现日期**: 2026-01-01
**解决日期**: 2026-01-01

**问题描述**:
1. 分类管理页面点击"详情"按钮时报错（404）
2. 页面顶部的总分类数、收入分类、支出分类等统计数据全部显示为0

**根本原因**:
1. 后端缺少 `/admin/categories/{category_id}` 详情接口
2. 后端 `list_categories` API 返回的响应不包含 `stats` 统计数据

**解决方案**:
1. 在 `admin/schemas/data_management.py` 添加 `CategoryStats` schema
2. 修改 `CategoryListResponse` 添加 `stats` 字段
3. 在 `list_categories` 函数中添加分类统计查询
4. 添加新的 `get_category_detail` 端点

```python
class CategoryStats(BaseModel):
    total_count: int = 0
    income_count: int = 0
    expense_count: int = 0
    custom_count: int = 0

@router.get("/{category_id}")
async def get_category_detail(category_id: UUID, ...):
    # 返回分类详情及使用趋势
```

**相关文件**:
- `server/admin/schemas/data_management.py`
- `server/admin/api/categories.py`

---

### #021 备份管理缺少用户名列
**状态**: ✅ 已解决
**发现日期**: 2026-01-01
**解决日期**: 2026-01-01

**问题描述**:
备份管理页面的表格缺少用户名称/邮箱列，无法直观了解备份属于哪个用户。

**解决方案**:
在表格中添加用户列，显示 `user_email` 字段：
```vue
<el-table-column prop="user_email" label="用户" width="180">
  <template #default="{ row }">
    {{ row.user_email || '-' }}
  </template>
</el-table-column>
```

**相关文件**:
- `admin-web/src/views/data/Backups.vue`

---

## 待处理问题

（暂无）

---

## 待重构项目（架构优化）

以下问题需要较大规模重构，已列入后续迭代计划：

### #R001 DatabaseService 过大
**优先级**: P2
**影响范围**: 全局

**问题描述**:
`app/lib/services/database_service.dart` 文件达到 2639 行，包含 45 个异步方法，违反单一职责原则。

**建议方案**:
拆分为领域服务：
- `TransactionDatabaseService` - 交易相关操作
- `AccountDatabaseService` - 账户相关操作
- `CategoryDatabaseService` - 分类相关操作
- `ImportDatabaseService` - 导入相关操作
- 等等

**相关文件**:
- `app/lib/services/database_service.dart`

---

### #R002 缺乏依赖注入机制
**优先级**: P2
**影响范围**: 全部 Provider

**问题描述**:
每个 Provider 直接 `new Service()`，没有统一的依赖管理：
```dart
// 当前方式
final AIService _aiService = AIService();
final HttpService _http = HttpService();
```

**建议方案**:
1. 使用 Riverpod 的 Provider 管理 Service 依赖
2. 或引入 get_it 等依赖注入框架

**相关文件**:
- `app/lib/providers/*.dart`
- `app/lib/providers/base/crud_notifier.dart`

---

### #R003 同步服务职责混乱
**优先级**: P2
**影响范围**: 数据同步功能

**问题描述**:
三个服务功能重叠：
- `sync_service.dart` (576行) - 包含 CloudSyncService 和 BackupRestoreService
- `server_sync_service.dart` (605行) - 服务器同步
- `backup_service.dart` (454行) - 备份管理

**建议方案**:
重新设计同步架构，明确职责分离：
- `SyncCoordinator` - 协调各类同步
- `CloudSyncService` - 云端数据同步
- `BackupService` - 本地/云备份

**相关文件**:
- `app/lib/services/sync_service.dart`
- `app/lib/services/server_sync_service.dart`
- `app/lib/services/backup_service.dart`

---

### #R004 AIService 过度包装
**优先级**: P3
**影响范围**: AI 识别功能

**问题描述**:
`AIService` (764行) 仅是 `QwenService` (1275行) 的简单包装，只做格式转换，没有实际添加价值。

**建议方案**:
1. 移除 AIService，直接使用 QwenService
2. 或将 AIService 改造为 AI 服务抽象层，支持多种 AI 后端

**相关文件**:
- `app/lib/services/ai_service.dart`
- `app/lib/services/qwen_service.dart`

---

### #R005 本地化服务重复
**优先级**: P3
**影响范围**: 多语言功能

**问题描述**:
存在两个独立的本地化服务，代码重复：
- `account_localization_service.dart`
- `category_localization_service.dart`

**建议方案**:
合并为通用的 `LocalizationService`，使用配置区分不同类型。

**相关文件**:
- `app/lib/services/account_localization_service.dart`
- `app/lib/services/category_localization_service.dart`

---

## 已知限制

### API Key 安全性
**状态**: ✅ 已解决

**描述**:
~~当前 Flutter 端直接调用千问 API，API key 通过 `--dart-define` 编译到 APK 中。虽然不是明文存储，但理论上可以被反编译提取。~~

**改进方案（已实施）**:
1. API Key 存储在服务器端环境变量中
2. APP 通过 `/api/v1/config/ai` 端点获取 API Key（需认证）
3. 获取后缓存到本地 SecureStorage，支持离线使用
4. 用户登出时清除缓存的 API Key

**相关文件**:
- `server/app/api/v1/config.py` - 服务器端配置接口
- `app/lib/core/config.dart` - 客户端配置管理
- `app/lib/providers/auth_provider.dart` - 登录后获取配置

---

## 问题统计

| 状态 | 数量 |
|------|------|
| ✅ 已解决 | 21 |
| 🔄 进行中 | 0 |
| ❌ 待处理 | 0 |
| 🔧 待重构 | 5 |
| ⚠️ 已知限制 | 0 |

---

## 更新日志

### 2026-01-01（晚间）
- 添加待重构项目 #R001 ~ #R005（架构优化）
- 实现服务端 `/auth/check-email`、`/auth/reset-password`、`PATCH /users/me` API
- 修复 `source_file_sync_service` 绕过 httpService 拦截器问题
- 修复 `member_management_page` 和 `join_invite_page` 硬编码用户ID
- 实现通用银行账单解析器 `generic_bank_parser.dart`
- 标记旧 `import_service.dart` 为废弃

### 2026-01-01（下午）
- 新增 #015 交易详情显示 Invalid Date
- 新增 #016 交易管理页面汇总统计始终为0
- 新增 #017 用户管理"最后登录"字段名称不准确
- 新增 #018 仪表盘今日交易统计使用错误的时间字段
- 新增 #019 账本管理货币和类型显示问题
- 新增 #020 分类管理详情按钮报错及统计为0
- 新增 #021 备份管理缺少用户名列

### 2026-01-01（上午）
- 新增 #010 管理控制台用户管理操作按钮换行
- 新增 #011 管理控制台账本管理操作按钮换行
- 新增 #012 管理控制台表格容器不必要的滚动条
- 新增 #013 仪表盘交易类型分布饼图无数据
- 新增 #014 仪表盘最近交易金额显示为空

### 2025-12-30（晚间）
- 新增 #009 分类管理对话框无法显示

### 2025-12-30（下午）
- 新增 #006 服务器 Supervisor 配置错误
- 新增 #007 API Key 从服务器获取失败
- 新增 #008 语音识别返回空转写
- 更新 API Key 安全性限制（现已通过服务器端配置解决）

### 2025-12-30（上午）
- 创建问题追踪清单
- 记录 #001 ~ #005 已解决问题
- 记录 API Key 安全性已知限制
