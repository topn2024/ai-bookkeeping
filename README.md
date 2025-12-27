# AI Bookkeeping - 智能记账

一款AI驱动的智能记账应用，支持图片识别、语音输入、邮箱账单解析等多种记账方式。

## 功能特性

- **智能记账**：图片OCR识别、语音记账、邮箱账单自动解析
- **多维度管理**：多账本、多账户、多成员协作
- **丰富报表**：收支统计、趋势分析、分类占比、预算管理
- **跨平台**：支持iOS和Android

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
- PaddleOCR (图片识别)
- Whisper (语音识别)
- Claude API (智能解析)

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
