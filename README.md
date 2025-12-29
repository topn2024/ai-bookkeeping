# AI Bookkeeping - 智能记账

一款AI驱动的智能记账应用，支持图片识别、语音输入、邮箱账单解析等多种记账方式。

## 功能特性

- **智能记账**：图片OCR识别、语音记账、邮箱账单自动解析
- **多维度管理**：多账本、多账户、多成员协作
- **丰富报表**：收支统计、趋势分析、分类占比、预算管理
- **跨平台**：支持iOS和Android

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
