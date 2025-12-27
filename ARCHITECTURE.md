# AI智能记账应用 - 架构设计文档

## 一、项目概述

### 1.1 项目名称
**AI Bookkeeping** (智能记账)

### 1.2 项目目标
打造一款AI驱动的智能记账应用，支持多种记账方式（图片识别、语音输入、邮箱账单解析、手动录入），提供丰富的统计报表功能，帮助用户轻松管理个人/家庭财务。

### 1.3 核心功能
1. **智能记账**
   - 图片/拍照识别：自动识别小票、发票、账单
   - 语音记账：语音转文字自动解析金额和分类
   - 邮箱账单解析：自动获取信用卡账单生成记录
   - 手动记账：支持支出/收入/转账

2. **账目管理**
   - 多账本支持
   - 多成员协作
   - 分类管理（支出/收入）
   - 账户管理（现金、银行卡、信用卡、支付宝、微信等）

3. **统计报表**
   - 收支总览
   - 趋势分析（日/周/月/年）
   - 分类占比
   - 报销统计
   - 预算管理

4. **个人中心**
   - 会员系统
   - 主题设置
   - 数据导入/导出
   - 定时记账

---

## 二、技术架构

### 2.1 整体架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                        客户端 (Mobile App)                        │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │              Flutter (iOS & Android)                        │ │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐       │ │
│  │  │   首页   │ │   统计   │ │   账单   │ │   我的   │       │ │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘       │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ HTTPS/REST API
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         API Gateway                              │
│                    (Nginx / Kong / AWS ALB)                      │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      后端服务 (Backend)                          │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                    Python FastAPI                           │ │
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐        │ │
│  │  │  用户服务    │ │  记账服务    │ │  统计服务    │        │ │
│  │  └──────────────┘ └──────────────┘ └──────────────┘        │ │
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐        │ │
│  │  │  AI识别服务  │ │  邮件解析    │ │  通知服务    │        │ │
│  │  └──────────────┘ └──────────────┘ └──────────────┘        │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
           ┌──────────────────┼──────────────────┐
           ▼                  ▼                  ▼
┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
│    PostgreSQL    │ │      Redis       │ │   MinIO/OSS      │
│   (主数据库)     │ │   (缓存/队列)    │ │   (文件存储)     │
└──────────────────┘ └──────────────────┘ └──────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       AI 服务层                                  │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐            │
│  │ Claude API   │ │ Whisper API  │ │ OCR Service  │            │
│  │ (文本理解)   │ │ (语音识别)   │ │ (图片识别)   │            │
│  └──────────────┘ └──────────────┘ └──────────────┘            │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 技术栈选型

#### 前端 (Mobile App)
| 技术 | 选型 | 说明 |
|------|------|------|
| 框架 | **Flutter 3.x** | 一套代码，同时支持iOS和Android |
| 状态管理 | **Riverpod** | 简洁、类型安全的状态管理 |
| 网络请求 | **Dio** | 强大的HTTP客户端 |
| 本地存储 | **Hive + SQLite** | 离线数据缓存 |
| 图表 | **fl_chart** | 美观的统计图表 |
| 相机 | **camera + image_picker** | 拍照和图片选择 |
| 语音 | **speech_to_text** | 语音输入 |
| UI组件 | **自定义组件库** | 参照设计稿定制 |

#### 后端 (Backend)
| 技术 | 选型 | 说明 |
|------|------|------|
| 语言 | **Python 3.11+** | AI生态丰富 |
| 框架 | **FastAPI** | 高性能异步框架 |
| ORM | **SQLAlchemy 2.0** | 数据库映射 |
| 数据库 | **PostgreSQL 15** | 主数据存储 |
| 缓存 | **Redis 7** | 缓存和消息队列 |
| 任务队列 | **Celery** | 异步任务处理 |
| 文件存储 | **MinIO / 阿里云OSS** | 图片等文件存储 |

#### AI服务
| 功能 | 技术方案 | 说明 |
|------|----------|------|
| 图片识别(OCR) | **PaddleOCR** + Claude | 本地OCR + AI理解 |
| 语音识别 | **Whisper API** | OpenAI语音转文字 |
| 智能分类 | **Claude API** | 自动识别消费类型 |
| 账单解析 | **Claude API** | 解析邮件中的账单 |

---

## 三、数据库设计

### 3.1 核心表结构

```sql
-- 用户表
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone VARCHAR(20) UNIQUE,
    email VARCHAR(100) UNIQUE,
    password_hash VARCHAR(255),
    nickname VARCHAR(50),
    avatar_url VARCHAR(500),
    member_level INT DEFAULT 0,  -- 0:普通 1:VIP
    member_expire_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- 账本表
CREATE TABLE books (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    name VARCHAR(100) NOT NULL,
    icon VARCHAR(50),
    cover_image VARCHAR(500),
    book_type INT DEFAULT 0,  -- 0:普通 1:家庭 2:商务
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW()
);

-- 账本成员表
CREATE TABLE book_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    book_id UUID REFERENCES books(id),
    user_id UUID REFERENCES users(id),
    role INT DEFAULT 0,  -- 0:成员 1:管理员 2:所有者
    joined_at TIMESTAMP DEFAULT NOW()
);

-- 账户表（现金、银行卡、支付宝等）
CREATE TABLE accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    name VARCHAR(100) NOT NULL,
    account_type INT NOT NULL,  -- 1:现金 2:储蓄卡 3:信用卡 4:支付宝 5:微信
    icon VARCHAR(50),
    balance DECIMAL(15,2) DEFAULT 0,
    credit_limit DECIMAL(15,2),  -- 信用卡额度
    bill_day INT,  -- 账单日
    repay_day INT,  -- 还款日
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW()
);

-- 分类表
CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID,  -- NULL表示系统预设
    parent_id UUID REFERENCES categories(id),
    name VARCHAR(50) NOT NULL,
    icon VARCHAR(50),
    category_type INT NOT NULL,  -- 1:支出 2:收入
    sort_order INT DEFAULT 0,
    is_system BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW()
);

-- 账目记录表
CREATE TABLE transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    book_id UUID REFERENCES books(id),
    account_id UUID REFERENCES accounts(id),
    target_account_id UUID REFERENCES accounts(id),  -- 转账目标
    category_id UUID REFERENCES categories(id),
    transaction_type INT NOT NULL,  -- 1:支出 2:收入 3:转账
    amount DECIMAL(15,2) NOT NULL,
    fee DECIMAL(15,2) DEFAULT 0,  -- 手续费
    transaction_date DATE NOT NULL,
    transaction_time TIME,
    note VARCHAR(500),
    tags VARCHAR(200)[],
    images VARCHAR(500)[],
    location VARCHAR(200),
    is_reimbursable BOOLEAN DEFAULT FALSE,  -- 可报销
    is_reimbursed BOOLEAN DEFAULT FALSE,    -- 已报销
    is_exclude_stats BOOLEAN DEFAULT FALSE, -- 不计收支
    source INT DEFAULT 0,  -- 0:手动 1:图片 2:语音 3:邮件
    ai_confidence DECIMAL(3,2),  -- AI识别置信度
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- 预算表
CREATE TABLE budgets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    book_id UUID REFERENCES books(id),
    category_id UUID REFERENCES categories(id),  -- NULL表示总预算
    budget_type INT NOT NULL,  -- 1:月度 2:年度
    amount DECIMAL(15,2) NOT NULL,
    year INT NOT NULL,
    month INT,  -- 年度预算为NULL
    created_at TIMESTAMP DEFAULT NOW()
);

-- 定时记账表
CREATE TABLE scheduled_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    template_data JSONB NOT NULL,  -- 记账模板
    frequency INT NOT NULL,  -- 1:每天 2:每周 3:每月 4:每年
    next_execute_at TIMESTAMP NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW()
);

-- 邮箱绑定表
CREATE TABLE email_bindings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    email VARCHAR(100) NOT NULL,
    email_type INT NOT NULL,  -- 1:Gmail 2:Outlook 3:QQ 4:163
    access_token TEXT,
    refresh_token TEXT,
    last_sync_at TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW()
);
```

### 3.2 索引设计

```sql
-- 账目查询优化
CREATE INDEX idx_transactions_user_date ON transactions(user_id, transaction_date DESC);
CREATE INDEX idx_transactions_book_date ON transactions(book_id, transaction_date DESC);
CREATE INDEX idx_transactions_category ON transactions(category_id, transaction_date DESC);

-- 统计查询优化
CREATE INDEX idx_transactions_stats ON transactions(user_id, book_id, transaction_type, transaction_date);
```

---

## 四、API设计

### 4.1 API规范
- RESTful风格
- JWT Token认证
- 统一响应格式

```json
{
    "code": 0,
    "message": "success",
    "data": {}
}
```

### 4.2 核心API列表

#### 认证模块
| 方法 | 路径 | 说明 |
|------|------|------|
| POST | /api/v1/auth/register | 注册 |
| POST | /api/v1/auth/login | 登录 |
| POST | /api/v1/auth/refresh | 刷新Token |
| POST | /api/v1/auth/logout | 登出 |

#### 账本模块
| 方法 | 路径 | 说明 |
|------|------|------|
| GET | /api/v1/books | 获取账本列表 |
| POST | /api/v1/books | 创建账本 |
| PUT | /api/v1/books/{id} | 更新账本 |
| DELETE | /api/v1/books/{id} | 删除账本 |
| POST | /api/v1/books/{id}/members | 添加成员 |

#### 记账模块
| 方法 | 路径 | 说明 |
|------|------|------|
| GET | /api/v1/transactions | 获取账目列表 |
| POST | /api/v1/transactions | 创建账目 |
| PUT | /api/v1/transactions/{id} | 更新账目 |
| DELETE | /api/v1/transactions/{id} | 删除账目 |
| POST | /api/v1/transactions/batch | 批量创建 |

#### AI记账模块
| 方法 | 路径 | 说明 |
|------|------|------|
| POST | /api/v1/ai/recognize-image | 图片识别记账 |
| POST | /api/v1/ai/recognize-voice | 语音识别记账 |
| POST | /api/v1/ai/parse-bill | 解析账单邮件 |

#### 统计模块
| 方法 | 路径 | 说明 |
|------|------|------|
| GET | /api/v1/stats/overview | 收支概览 |
| GET | /api/v1/stats/trend | 趋势分析 |
| GET | /api/v1/stats/category | 分类统计 |
| GET | /api/v1/stats/budget | 预算执行情况 |

#### 账户模块
| 方法 | 路径 | 说明 |
|------|------|------|
| GET | /api/v1/accounts | 账户列表 |
| POST | /api/v1/accounts | 创建账户 |
| PUT | /api/v1/accounts/{id} | 更新账户 |
| GET | /api/v1/accounts/{id}/balance | 账户余额 |

---

## 五、前端页面设计

### 5.1 页面结构

```
App
├── 启动页 (Splash)
├── 登录/注册
│   ├── 手机号登录
│   ├── 验证码登录
│   └── 第三方登录（微信）
├── 主页面 (底部导航)
│   ├── 首页 (Home)
│   │   ├── 账本切换
│   │   ├── 本月概览卡片
│   │   ├── 快捷功能入口
│   │   ├── 预算进度
│   │   └── 月账单列表
│   ├── 统计 (Stats)
│   │   ├── 时间筛选（月/年/范围/日/周）
│   │   ├── 总览Tab
│   │   ├── 趋势Tab
│   │   └── 分类Tab
│   ├── 账单 (Bills)
│   │   └── 账单列表/日历视图
│   └── 我的 (Profile)
│       ├── 会员信息
│       ├── 设置列表
│       └── 管理功能
├── 记账页面
│   ├── 支出记账
│   ├── 收入记账
│   └── 转账记账
├── AI记账
│   ├── 拍照/图片识别
│   ├── 语音记账
│   └── 账单导入
└── 设置页面
    ├── 个人设置
    ├── 账本管理
    ├── 分类管理
    ├── 账户管理
    └── 主题设置
```

### 5.2 设计规范

#### 颜色系统
```dart
// 主色调
static const primary = Color(0xFF00C9A7);      // 薄荷绿
static const primaryLight = Color(0xFFE8FFF8);

// 功能色
static const expense = Color(0xFFFF6B6B);      // 支出红
static const income = Color(0xFF4CAF50);       // 收入绿
static const transfer = Color(0xFF2196F3);     // 转账蓝

// 中性色
static const textPrimary = Color(0xFF333333);
static const textSecondary = Color(0xFF999999);
static const background = Color(0xFFF5F5F5);
static const cardBackground = Color(0xFFFFFFFF);
```

#### 字体规范
```dart
// 标题
static const headlineLarge = TextStyle(fontSize: 28, fontWeight: FontWeight.bold);
static const headlineMedium = TextStyle(fontSize: 24, fontWeight: FontWeight.bold);

// 金额
static const amountLarge = TextStyle(fontSize: 32, fontWeight: FontWeight.bold);
static const amountMedium = TextStyle(fontSize: 20, fontWeight: FontWeight.w600);

// 正文
static const bodyLarge = TextStyle(fontSize: 16);
static const bodyMedium = TextStyle(fontSize: 14);
static const bodySmall = TextStyle(fontSize: 12);
```

---

## 六、AI功能设计

### 6.1 图片识别流程

```
┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│ 用户拍照  │ ──▶ │ OCR识别  │ ──▶ │ Claude   │ ──▶ │ 返回结果  │
│ /选图片  │     │ 文字提取  │     │ 智能解析  │     │ 确认保存  │
└──────────┘     └──────────┘     └──────────┘     └──────────┘
```

**识别内容：**
- 商户名称
- 消费金额
- 消费时间
- 商品明细
- 自动分类建议

### 6.2 语音记账流程

```
┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│ 用户说话  │ ──▶ │ Whisper  │ ──▶ │ Claude   │ ──▶ │ 返回结果  │
│ 按住录音  │     │ 语音转文字│     │ 意图解析  │     │ 确认保存  │
└──────────┘     └──────────┘     └──────────┘     └──────────┘
```

**示例输入：**
- "今天午饭花了35块"
- "买了一杯咖啡28元"
- "这个月工资到账8000"

### 6.3 邮箱账单解析

```
┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│ 授权邮箱  │ ──▶ │ 获取邮件  │ ──▶ │ Claude   │ ──▶ │ 批量导入  │
│ OAuth    │     │ 筛选账单  │     │ 解析账单  │     │ 用户确认  │
└──────────┘     └──────────┘     └──────────┘     └──────────┘
```

**支持银行：**
- 招商银行、工商银行、建设银行等
- 支付宝、微信账单
- 信用卡电子账单

---

## 七、项目目录结构

### 7.1 前端项目结构

```
ai-bookkeeping-app/
├── android/                    # Android原生代码
├── ios/                        # iOS原生代码
├── lib/
│   ├── main.dart              # 入口文件
│   ├── app/
│   │   ├── app.dart           # App配置
│   │   └── routes.dart        # 路由配置
│   ├── core/
│   │   ├── constants/         # 常量定义
│   │   ├── theme/             # 主题配置
│   │   ├── utils/             # 工具类
│   │   └── extensions/        # 扩展方法
│   ├── data/
│   │   ├── models/            # 数据模型
│   │   ├── repositories/      # 数据仓库
│   │   ├── providers/         # 状态提供者
│   │   └── services/          # API服务
│   ├── features/
│   │   ├── auth/              # 认证模块
│   │   ├── home/              # 首页模块
│   │   ├── stats/             # 统计模块
│   │   ├── bills/             # 账单模块
│   │   ├── profile/           # 个人中心
│   │   ├── transaction/       # 记账模块
│   │   └── ai/                # AI记账模块
│   └── shared/
│       ├── widgets/           # 通用组件
│       └── dialogs/           # 弹窗组件
├── assets/
│   ├── images/                # 图片资源
│   ├── icons/                 # 图标资源
│   └── fonts/                 # 字体文件
├── test/                      # 测试代码
├── pubspec.yaml               # 依赖配置
└── README.md
```

### 7.2 后端项目结构

```
ai-bookkeeping-server/
├── app/
│   ├── __init__.py
│   ├── main.py                # FastAPI入口
│   ├── core/
│   │   ├── config.py          # 配置管理
│   │   ├── security.py        # 安全认证
│   │   ├── database.py        # 数据库连接
│   │   └── exceptions.py      # 异常处理
│   ├── api/
│   │   ├── v1/
│   │   │   ├── auth.py        # 认证接口
│   │   │   ├── users.py       # 用户接口
│   │   │   ├── books.py       # 账本接口
│   │   │   ├── transactions.py# 记账接口
│   │   │   ├── accounts.py    # 账户接口
│   │   │   ├── categories.py  # 分类接口
│   │   │   ├── stats.py       # 统计接口
│   │   │   └── ai.py          # AI接口
│   │   └── deps.py            # 依赖注入
│   ├── models/
│   │   ├── user.py            # 用户模型
│   │   ├── book.py            # 账本模型
│   │   ├── transaction.py     # 记账模型
│   │   ├── account.py         # 账户模型
│   │   └── category.py        # 分类模型
│   ├── schemas/
│   │   ├── user.py            # 用户Schema
│   │   ├── book.py            # 账本Schema
│   │   ├── transaction.py     # 记账Schema
│   │   └── stats.py           # 统计Schema
│   ├── services/
│   │   ├── auth_service.py    # 认证服务
│   │   ├── transaction_service.py
│   │   ├── stats_service.py   # 统计服务
│   │   └── ai_service.py      # AI服务
│   └── tasks/
│       ├── email_parser.py    # 邮件解析任务
│       └── scheduled.py       # 定时任务
├── migrations/                 # 数据库迁移
├── tests/                      # 测试代码
├── requirements.txt            # Python依赖
├── Dockerfile                  # Docker配置
├── docker-compose.yml          # Docker编排
└── README.md
```

---

## 八、部署架构

### 8.1 开发环境
- 本地开发使用Docker Compose
- 热重载支持

### 8.2 生产环境

```
                           ┌─────────────────┐
                           │   CDN (静态)    │
                           └────────┬────────┘
                                    │
                           ┌────────▼────────┐
                           │  负载均衡 (SLB) │
                           └────────┬────────┘
                                    │
              ┌─────────────────────┼─────────────────────┐
              │                     │                     │
     ┌────────▼────────┐   ┌────────▼────────┐   ┌────────▼────────┐
     │   API Server 1  │   │   API Server 2  │   │   API Server N  │
     │   (K8s Pod)     │   │   (K8s Pod)     │   │   (K8s Pod)     │
     └────────┬────────┘   └────────┬────────┘   └────────┬────────┘
              │                     │                     │
              └─────────────────────┼─────────────────────┘
                                    │
     ┌──────────────────────────────┼──────────────────────────────┐
     │                              │                              │
┌────▼────┐                   ┌─────▼─────┐                  ┌─────▼─────┐
│PostgreSQL│                   │   Redis   │                  │   MinIO   │
│ (RDS)   │                   │  Cluster  │                  │   (OSS)   │
└─────────┘                   └───────────┘                  └───────────┘
```

### 8.3 推荐云服务
- **服务器**：阿里云ECS / AWS EC2
- **数据库**：阿里云RDS PostgreSQL
- **缓存**：阿里云Redis
- **存储**：阿里云OSS
- **容器**：阿里云ACK (Kubernetes)

---

## 九、开发计划

### 第一阶段：基础功能 (MVP)
- [ ] 用户认证系统
- [ ] 手动记账（支出/收入/转账）
- [ ] 基础分类管理
- [ ] 账目列表和详情
- [ ] 简单统计（本月收支）

### 第二阶段：核心功能
- [ ] 多账本支持
- [ ] 账户管理
- [ ] 完整统计报表
- [ ] 预算功能
- [ ] 数据导出

### 第三阶段：AI功能
- [ ] 图片识别记账
- [ ] 语音记账
- [ ] 邮箱账单解析
- [ ] 智能分类建议

### 第四阶段：高级功能
- [ ] 多成员协作
- [ ] 定时记账
- [ ] 桌面小组件
- [ ] 会员系统

---

## 十、分类预设

### 10.1 支出分类
| 图标 | 分类 | 子分类 |
|------|------|--------|
| 🍽️ | 餐饮 | 早餐、午餐、晚餐、饮料、零食 |
| 🏠 | 住房 | 房租、物业费、水电燃气、维修 |
| 🎮 | 娱乐 | 游戏、电影、KTV、旅游 |
| 👥 | 人情 | 红包、礼物、请客 |
| 👶 | 育儿 | 奶粉、玩具、教育、医疗 |
| ✈️ | 差旅 | 机票、酒店、打车、火车 |
| 🚌 | 交通 | 公交、地铁、打车、共享单车 |
| 🚗 | 汽车 | 加油、停车、保养、保险 |
| 🛒 | 购物 | 服装、日用品、数码产品 |
| 💼 | 办公 | 办公用品、打印、快递 |
| 🏥 | 医疗 | 挂号、药品、体检 |
| 🏃 | 运动 | 健身卡、运动装备 |
| 📚 | 学习 | 书籍、课程、培训 |
| 📱 | 会员订阅 | 视频会员、音乐会员、软件 |

### 10.2 收入分类
| 图标 | 分类 | 说明 |
|------|------|------|
| 💰 | 工资 | 月薪、周薪 |
| ⏰ | 加班 | 加班费 |
| 💼 | 兼职 | 兼职收入 |
| 📈 | 理财 | 利息、股票、基金 |
| 🎁 | 福利 | 公司福利 |
| 🏆 | 奖金 | 年终奖、绩效奖 |
| 🏦 | 公积金 | 公积金提取 |
| 🧧 | 红包 | 收到的红包 |
| 💝 | 礼金 | 收到的礼金 |
| 🏪 | 经营所得 | 生意收入 |
| 🎲 | 意外来钱 | 中奖、退款等 |

---

## 十一、安全设计

### 11.1 数据安全
- 敏感数据加密存储
- HTTPS全链路加密
- SQL注入防护
- XSS攻击防护

### 11.2 用户隐私
- 最小化数据收集
- 用户数据可导出/删除
- 第三方服务数据脱敏
- 符合GDPR/个人信息保护法

### 11.3 API安全
- JWT Token + Refresh Token
- 请求频率限制
- 接口签名验证
- 敏感操作二次验证

---

## 十二、待确认事项

1. **用户体系**：是否需要支持微信/Apple登录？
2. **货币支持**：是否需要多货币记账？
3. **数据同步**：是否需要离线模式和本地数据？
4. **推送通知**：是否需要记账提醒、账单提醒？
5. **商业模式**：会员功能的具体权益是什么？
6. **国际化**：是否需要多语言支持？

---

以上是AI智能记账应用的完整架构设计，请确认是否有需要调整的地方。
