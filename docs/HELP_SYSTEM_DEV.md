# 帮助文档系统开发文档

本文档说明帮助文档系统的技术架构和开发指南。

## 系统架构

### 整体架构

```
┌─────────────────────────────────────────┐
│           用户界面层 (UI Layer)          │
├─────────────────────────────────────────┤
│  HelpPage                               │
│  ├─ HelpSearchWidget                    │
│  ├─ ModuleListWidget                    │
│  └─ PageHelpDetailWidget                │
├─────────────────────────────────────────┤
│         服务层 (Service Layer)          │
├─────────────────────────────────────────┤
│  HelpContentService                     │
│  ├─ 内容加载                            │
│  ├─ 缓存管理                            │
│  ├─ 搜索功能                            │
│  ├─ 搜索历史                            │
│  └─ 使用统计                            │
├─────────────────────────────────────────┤
│         数据层 (Data Layer)             │
├─────────────────────────────────────────┤
│  HelpContent Model                      │
│  HelpStep Model                         │
│  JSON Assets (20个模块文件)             │
└─────────────────────────────────────────┘
```

## 核心组件

### 1. 数据模型

#### HelpContent

```dart
class HelpContent {
  final String pageId;           // 页面标识
  final String title;            // 页面标题
  final String module;           // 所属模块
  final String description;      // 功能描述
  final List<String> useCases;   // 使用场景
  final List<HelpStep> steps;    // 操作步骤
  final List<String> tips;       // 注意事项
  final List<String> relatedPages; // 相关页面
  final List<String> keywords;   // 搜索关键词
}
```

#### HelpStep

```dart
class HelpStep {
  final String title;            // 步骤标题
  final String description;      // 步骤详情
  final String? imageAsset;      // 可选：配图
}
```

### 2. 服务层

#### HelpContentService

单例服务，提供以下功能：

**内容加载**
```dart
Future<void> preload()  // 预加载所有帮助内容
```

**内容获取**
```dart
HelpContent? getContentByPageId(String pageId)
List<HelpContent> getContentsByModule(String module)
List<HelpContent> getAllContents()
```

**搜索功能**
```dart
List<HelpContent> search(String query)  // 多维度搜索
```

**搜索历史**
```dart
Future<void> loadSearchHistory()
Future<void> addSearchHistory(String query)
Future<void> clearSearchHistory()
List<String> getSearchHistory()
```

**使用统计**
```dart
Future<void> loadViewStats()
Future<void> recordView(String pageId)
int getViewCount(String pageId)
List<HelpContent> getPopularContents({int limit = 10})
Future<void> clearViewStats()
```

### 3. UI组件

#### HelpPage

主帮助页面，包含：
- TabBar（快速入门、按模块浏览、常见问题）
- 搜索功能
- 热门问题展示

#### HelpSearchWidget

搜索组件，提供：
- 实时搜索
- 搜索历史
- 搜索结果展示

#### ModuleListWidget

模块列表组件，展示：
- 20个功能模块
- 每个模块的页面数量
- 模块图标和描述

#### PageHelpDetailWidget

页面详情组件，展示：
- 功能描述
- 使用场景
- 操作步骤
- 注意事项
- 相关功能
- 反馈按钮

#### HelpIconButton

帮助图标按钮，可添加到任何页面的AppBar：

```dart
AppBar(
  title: Text('页面标题'),
  actions: [
    HelpIconButton(pageId: '/page-route'),
  ],
)
```

## 数据流

### 内容加载流程

```
1. 应用启动
   ↓
2. HelpContentService.preload()
   ↓
3. 加载20个模块的JSON文件
   ↓
4. 解析JSON并缓存到内存
   ↓
5. 构建索引（pageId和module）
   ↓
6. 加载完成，可以使用
```

### 搜索流程

```
1. 用户输入搜索关键词
   ↓
2. HelpContentService.search(query)
   ↓
3. 多维度匹配：
   - 标题匹配（权重最高）
   - 描述匹配
   - 关键词匹配
   - 使用场景匹配
   - 步骤内容匹配
   ↓
4. 返回匹配结果
   ↓
5. 记录搜索历史
```

### 统计流程

```
1. 用户打开帮助详情页
   ↓
2. PageHelpDetailWidget.initState()
   ↓
3. HelpContentService.recordView(pageId)
   ↓
4. 更新查看次数
   ↓
5. 保存到SharedPreferences
```

## 性能优化

### 1. 内存缓存

所有帮助内容在应用启动时加载到内存，避免重复读取文件。

```dart
final Map<String, HelpContent> _cache = {};
final Map<String, List<HelpContent>> _moduleCache = {};
```

### 2. 懒加载（可选）

如果内容量很大，可以实现按需加载：

```dart
Future<void> loadModule(String module) async {
  if (_moduleCache.containsKey(module)) return;
  // 加载指定模块
}
```

### 3. 搜索优化

使用相关度评分算法，优先返回最相关的结果：

```dart
double score = 0.0;
if (title完全匹配) score += 10.0;
if (title包含) score += 5.0;
if (description包含) score += 3.0;
// ...
```

## 扩展功能

### 1. 多语言支持

修改文件结构：

```
app/assets/help/
├── zh/
│   ├── home.json
│   └── ...
├── en/
│   ├── home.json
│   └── ...
```

修改加载逻辑：

```dart
String _getHelpPath(String fileName) {
  final locale = Localizations.localeOf(context).languageCode;
  return 'assets/help/$locale/$fileName';
}
```

### 2. 在线更新

实现从服务器下载最新帮助内容：

```dart
Future<void> updateFromServer() async {
  final response = await http.get('https://api.example.com/help');
  final data = json.decode(response.body);
  // 保存到本地
  // 重新加载
}
```

### 3. 图片支持

在HelpStep中添加图片：

```json
{
  "title": "步骤标题",
  "description": "步骤说明",
  "imageAsset": "assets/help/images/step1.png"
}
```

显示图片：

```dart
if (step.imageAsset != null) {
  Image.asset(step.imageAsset!);
}
```

### 4. 视频教程

添加视频字段：

```json
{
  "pageId": "/example",
  "videoUrl": "https://example.com/tutorial.mp4"
}
```

## 测试

### 单元测试

测试数据模型：

```dart
test('HelpContent fromJson', () {
  final json = {...};
  final content = HelpContent.fromJson(json);
  expect(content.pageId, '/test');
});
```

测试服务层：

```dart
test('HelpContentService search', () {
  final service = HelpContentService();
  await service.preload();
  final results = service.search('记账');
  expect(results.isNotEmpty, true);
});
```

### 集成测试

测试UI组件：

```dart
testWidgets('HelpPage displays correctly', (tester) async {
  await tester.pumpWidget(MyApp());
  await tester.tap(find.text('帮助'));
  await tester.pumpAndSettle();
  expect(find.text('快速入门'), findsOneWidget);
});
```

## 调试

### 启用日志

```dart
// 在HelpContentService中添加
static bool debugMode = true;

void _log(String message) {
  if (debugMode) print('[HelpService] $message');
}
```

### 查看缓存状态

```dart
void printCacheStats() {
  print('Cached contents: ${_cache.length}');
  print('Cached modules: ${_moduleCache.length}');
  print('Search history: ${_searchHistory.length}');
}
```

## 常见问题

### Q: 如何添加新的模块？

A: 
1. 在`app/assets/help/`创建新的JSON文件
2. 在`HelpContentService._moduleFiles`添加映射
3. 在`HelpPage._moduleNames`和`_moduleIcons`添加配置

### Q: 如何优化搜索性能？

A: 
1. 使用Isolate进行异步搜索
2. 实现搜索结果缓存
3. 限制搜索结果数量

### Q: 如何处理大量帮助内容？

A: 
1. 实现懒加载
2. 使用数据库存储
3. 实现分页加载

## 最佳实践

1. **保持单一职责**：每个组件只负责一个功能
2. **使用依赖注入**：便于测试和维护
3. **错误处理**：优雅地处理加载失败等异常
4. **性能监控**：记录加载时间和搜索性能
5. **用户反馈**：收集用户对帮助内容的反馈

## 参考资料

- Flutter官方文档
- Material Design指南
- 应用内其他功能的实现

## 更新日志

查看 CHANGELOG.md 了解系统的更新历史。
