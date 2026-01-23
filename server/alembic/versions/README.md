# Alembic 迁移脚本目录

## ⚠️ 此目录为空

本项目**不使用** Alembic 迁移脚本进行数据库版本管理。

## 为什么？

1. **简化开发流程** - 无需维护复杂的迁移脚本
2. **避免不一致** - 模型定义就是唯一的数据源
3. **适合早期项目** - 没有真实用户数据，可以随时重建数据库
4. **防止错误** - 避免迁移脚本与模型定义不一致导致的问题

## 如何初始化数据库？

```bash
# 使用初始化脚本（推荐）
cd server
python scripts/init_database.py

# 或者使用 Python 代码
python -c "from app.core.database import engine, Base; from app.models import *; Base.metadata.create_all(bind=engine)"
```

## 详细文档

请参阅项目根目录下的 `DATABASE_SCHEMA_GUIDE.md`

---

**注意**: 如果项目上线后有真实用户数据，可以考虑引入 Alembic 进行版本化管理。
