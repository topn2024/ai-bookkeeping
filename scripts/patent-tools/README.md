# 专利文档工具集

本目录包含用于管理和处理专利文档的自动化工具。

## 工具列表

| 工具 | 用途 |
|------|------|
| `migrate-patent.py` | 将旧格式专利文档迁移到新标准结构 |
| `validate-patent.py` | 验证专利文档的完整性和规范性 |
| `generate-index.py` | 生成专利索引和 README 文件 |

## 环境要求

- Python 3.8+
- 依赖包：见 `requirements.txt`

## 安装

```bash
cd scripts/patent-tools
pip install -r requirements.txt
```

## 使用方法

### 1. 迁移专利文档

将旧格式专利文档迁移到新的标准化结构：

```bash
# 迁移所有专利
python migrate-patent.py --all

# 迁移单个专利
python migrate-patent.py --source "docs/patents/01-FIFO钱龄计算" --target "docs/patents/patents/P01-fifo-money-age"

# 预览模式（不实际执行）
python migrate-patent.py --all --dry-run
```

### 2. 验证专利文档

检查专利文档的完整性和规范性：

```bash
# 验证所有专利
python validate-patent.py --all

# 验证单个专利
python validate-patent.py --patent P01

# 生成验证报告
python validate-patent.py --all --report
```

### 3. 生成索引

生成专利索引和 README 文件：

```bash
# 生成所有索引
python generate-index.py

# 仅生成 index.json
python generate-index.py --json-only

# 仅生成 README.md
python generate-index.py --readme-only
```

## 目录结构

```
scripts/patent-tools/
├── README.md              # 本文档
├── requirements.txt       # Python 依赖
├── migrate-patent.py      # 迁移工具
├── validate-patent.py     # 验证工具
└── generate-index.py      # 索引生成工具
```

## 配置

工具读取以下配置文件：

- `docs/patents/standards/naming-convention.md` - 命名规范
- `docs/patents/standards/figure-style.yaml` - 流程图样式

## 输出

- `docs/patents/index.json` - 专利索引（机器可读）
- `docs/patents/README.md` - 专利总览（人类可读）
- `docs/patents/validation-report.md` - 验证报告
