# AI Bookkeeping - 智能记账

一款AI驱动的智能记账应用，支持图片识别、语音输入、邮箱账单解析等多种记账方式。

## 功能特性

- **智能记账**：图片OCR识别、语音记账、邮箱账单自动解析
- **多维度管理**：多账本、多账户、多成员协作
- **丰富报表**：收支统计、趋势分析、分类占比、预算管理
- **跨平台**：支持iOS和Android

## 开发环境要求

| 工具 | 版本要求 |
|------|---------|
| Node.js | >= 20.0.0 |
| npm | >= 10.0.0 |
| Python | >= 3.11 |
| Flutter | >= 3.10.0 |

## 快速开始

### 1. 克隆仓库后初始化

```bash
# 安装根目录依赖（husky、lint-staged）
npm install

# 安装前端依赖
cd admin-web && npm install && cd ..

# 安装后端依赖
cd server && pip install -r requirements.txt && cd ..

# 安装Flutter依赖
cd app && flutter pub get && cd ..
```

### 2. 配置环境变量

```bash
# 后端配置
cp server/.env.example server/.env
# 编辑 server/.env 填入实际值

# 前端配置（可选）
cp admin-web/.env.example admin-web/.env
```

### 3. 启动开发环境

```bash
# 启动后端依赖服务（PostgreSQL、Redis、MinIO）
cd server && docker compose up -d

# 启动后端服务
cd server && uvicorn app.main:app --reload --port 8001

# 启动前端服务
cd admin-web && npm run dev

# 启动Flutter应用
cd app && flutter run
```

## 代码规范

项目使用以下工具保证代码质量：

- **前端 (admin-web)**: ESLint + Prettier
- **后端 (server)**: Ruff (linting + formatting)
- **移动端 (app)**: flutter_lints

提交代码前会自动运行 lint-staged 检查代码规范。

### 手动检查

```bash
# 前端
cd admin-web
npm run lint        # 检查代码规范
npm run lint:fix    # 自动修复
npm run format      # 格式化代码

# 后端
cd server
ruff check .        # 检查代码规范
ruff check . --fix  # 自动修复
ruff format .       # 格式化代码

# Flutter
cd app
flutter analyze     # 检查代码规范
```

## 配置说明

敏感配置信息（API密钥、数据库密码等）应通过环境变量配置，不要提交到代码仓库。

- 后端配置：复制 `server/.env.example` 为 `server/.env` 并填入实际值
- 前端配置：构建时通过 `--dart-define` 传入配置值

## 技术栈

### 前端 (Mobile App)
- Flutter 3.x
- Riverpod (状态管理)
- Dio (网络请求)

### 后端 (Backend)
- Python 3.11+
- FastAPI
- PostgreSQL
- Redis

### AI服务
- 通义千问 Qwen (主要) - 图片识别、文本解析、账单解析
- 智谱 GLM (备选) - 当千问不可用时自动切换

## 项目结构

```
ai-bookkeeping/
├── app/                    # Flutter前端应用
├── server/                 # Python后端服务
├── docs/                   # 文档
└── ARCHITECTURE.md         # 架构设计文档
```

## 快速开始

详见 [架构设计文档](./ARCHITECTURE.md)

## License

MIT
