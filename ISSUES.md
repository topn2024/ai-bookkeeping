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

## 待处理问题

（暂无）

---

## 已知限制

### API Key 安全性
**状态**: ⚠️ 已知限制

**描述**:
当前 Flutter 端直接调用千问 API，API key 通过 `--dart-define` 编译到 APK 中。虽然不是明文存储，但理论上可以被反编译提取。

**建议改进**:
将 AI 调用改为通过后端 API 代理，API key 只存储在服务器端。

---

## 问题统计

| 状态 | 数量 |
|------|------|
| ✅ 已解决 | 5 |
| 🔄 进行中 | 0 |
| ❌ 待处理 | 0 |
| ⚠️ 已知限制 | 1 |

---

## 更新日志

### 2025-12-30
- 创建问题追踪清单
- 记录 #001 ~ #005 已解决问题
- 记录 API Key 安全性已知限制
