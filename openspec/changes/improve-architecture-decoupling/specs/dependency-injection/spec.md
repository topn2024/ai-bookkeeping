# 依赖注入架构

## 新增需求

### 需求：服务定位器

应用**必须**通过统一的服务定位器管理所有服务依赖。

#### 场景：注册服务

**假设** 应用初始化
**当** 调用 `initServiceLocator()`
**那么** 所有核心服务应被注册到服务定位器

#### 场景：获取服务

**假设** 服务已注册
**当** 调用 `sl<ITransactionService>()`
**那么** 应返回 `ITransactionService` 的实现实例

### 需求：服务接口定义

所有核心服务**必须**定义抽象接口，实现依赖倒置原则。

#### 场景：事务服务接口

**假设** 定义 `ITransactionService` 接口
**当** 需要使用事务服务
**那么** 应通过接口类型获取，而非具体实现

#### 场景：服务可替换

**假设** 服务通过接口定义
**当** 需要进行单元测试
**那么** 可以注入模拟实现替代真实服务

### 需求：Repository 数据访问

数据访问**必须**通过 Repository 模式统一管理。

#### 场景：创建 Repository

**假设** 需要访问交易数据
**当** 创建 `TransactionRepository`
**那么** 应实现 `ITransactionRepository` 接口
**并且** 封装所有数据库操作细节

#### 场景：服务使用 Repository

**假设** `TransactionService` 需要访问数据
**当** 进行 CRUD 操作
**那么** 应通过 `ITransactionRepository` 接口访问
**而非** 直接调用 `DatabaseService`

---

## 修改需求

### 需求：模型层解耦

数据模型**禁止**直接依赖服务层。

#### 场景：移除 Account 服务依赖

**假设** `Account` 模型需要本地化名称
**当** 调用 `localizedName`
**那么** 应通过扩展方法传入服务
**而非** 模型内部直接调用 `LocalizationService`

#### 场景：移除 Category 服务依赖

**假设** `Category` 模型需要本地化名称
**当** 获取显示名称
**那么** 应通过扩展方法或 ViewModel 处理
**而非** 模型内部调用服务

### 需求：UI 层分离

UI 层**禁止**直接访问数据访问层。

#### 场景：页面通过 Provider 访问数据

**假设** 页面需要显示交易列表
**当** 加载数据
**那么** 应通过 `TransactionProvider` 获取
**而非** 直接调用 `DatabaseService`

#### 场景：移除页面中的数据库调用

**假设** 页面中存在 `DatabaseService()` 调用
**当** 重构后
**那么** 所有数据访问应通过 Provider 层
