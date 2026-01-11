# 规范：基础本地化服务

## 新增需求

### 需求：泛型本地化基类

系统**必须**提供一个泛型抽象基类 `BaseLocalizationService<T>`，封装所有本地化服务的共享逻辑。

#### 场景：初始化本地化服务

**Given** 应用启动
**When** 本地化服务被初始化
**Then** 应使用系统默认语言或用户偏好设置
**And** 支持的语言应包括：zh, en, ja, ko

#### 场景：设置用户偏好语言

**Given** 本地化服务已初始化
**When** 用户选择新的语言
**Then** `currentLocale` 应更新为新语言
**And** `isUserOverride` 应返回 true

#### 场景：映射不支持的语言

**Given** 系统语言为不支持的语言（如 fr）
**When** 服务初始化
**Then** 应回退到默认语言 en

---

## 修改需求

### 需求：AccountLocalizationService 继承基类

`AccountLocalizationService` **必须**继承 `BaseLocalizationService<Account>` 并移除重复代码。

#### 场景：获取账户本地化名称

**Given** 语言设置为中文
**When** 调用 `getLocalizedName(account)`
**Then** 应返回账户的中文名称

---

### 需求：CategoryLocalizationService 继承基类

`CategoryLocalizationService` **必须**继承 `BaseLocalizationService<Category>` 并移除重复代码。

#### 场景：获取分类本地化名称

**Given** 语言设置为英文
**When** 调用 `getLocalizedName(category)`
**Then** 应返回分类的英文名称

---

## 技术约束

- 基类位于 `lib/core/base/base_localization_service.dart`
- 保持现有公共 API 不变
- 单例模式通过子类实现
