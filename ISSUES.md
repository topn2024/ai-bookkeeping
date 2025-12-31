# AI 智能记账 - 问题追踪清单

> 最后更新: 2025-12-30

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

## 待处理问题

（暂无）

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
| ✅ 已解决 | 10 |
| 🔄 进行中 | 0 |
| ❌ 待处理 | 0 |
| ⚠️ 已知限制 | 0 |

---

## 更新日志

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
