# AI 智能记账 - 测试文档

## 测试概述

本项目包含完整的端到端自动化测试套件，覆盖所有已开发功能。

## 测试结构

```
ai-bookkeeping/
├── server/tests/              # 后端 API 测试
│   ├── conftest.py            # 测试配置和 fixtures
│   ├── test_auth.py           # 用户认证测试
│   ├── test_books.py          # 账本管理测试
│   ├── test_transactions.py   # 交易记录测试
│   ├── test_budgets.py        # 预算和统计测试
│   ├── test_debts_and_goals.py # 债务和储蓄目标测试
│   ├── test_collaboration.py  # 成员协作和数据同步测试
│   ├── test_ai_features.py    # AI 功能测试
│   ├── test_security.py       # 安全测试
│   ├── test_admin_api.py      # 管理后台 API 测试
│   └── test_e2e_scenarios.py  # 端到端场景测试
├── app/test/                  # 前端测试
│   ├── widget_test.dart       # Widget 单元测试（货币/安全/源文件）
│   ├── models_test.dart       # 数据模型测试
│   └── integration_test.dart  # 集成测试
└── scripts/                   # 测试运行脚本
    ├── run_all_tests.bat      # Windows 测试脚本
    └── run_all_tests.sh       # Linux/Mac 测试脚本
```

## 运行测试

### 快速开始

```bash
# Windows
scripts\run_all_tests.bat

# Linux/Mac
chmod +x scripts/run_all_tests.sh
./scripts/run_all_tests.sh
```

### 后端测试

```bash
cd server

# 安装依赖
pip install -r requirements.txt

# 运行所有测试
python -m pytest tests/ -v

# 运行特定模块测试
python -m pytest tests/test_auth.py -v
python -m pytest tests/test_transactions.py -v

# 带覆盖率报告
python -m pytest tests/ --cov=app --cov-report=html

# 生成 HTML 测试报告
python -m pytest tests/ --html=report.html
```

### 前端测试

```bash
cd app

# 运行所有测试
flutter test

# 运行特定测试
flutter test test/widget_test.dart

# 带覆盖率
flutter test --coverage
```

## 测试覆盖范围

### 1. 用户认证模块 (test_auth.py)
| 测试用例 | 描述 |
|---------|------|
| 邮箱注册成功 | 验证用户可以使用有效邮箱注册 |
| 手机号注册成功 | 验证用户可以使用手机号注册 |
| 重复邮箱注册失败 | 验证已注册邮箱无法再次注册 |
| 弱密码注册失败 | 验证密码强度验证生效 |
| 邮箱登录成功 | 验证正确凭证可以登录 |
| 错误密码登录失败 | 验证错误密码被拒绝 |
| 获取当前用户信息 | 验证已认证用户可获取个人信息 |
| Token 刷新 | 验证 token 可以正确刷新 |
| OAuth 配置获取 | 验证 OAuth 配置接口正常 |

### 2. 账本管理模块 (test_books.py)
| 测试用例 | 描述 |
|---------|------|
| 创建账本 | 验证可以创建新账本 |
| 列出账本 | 验证可以获取用户的账本列表 |
| 获取账本详情 | 验证可以获取特定账本信息 |
| 更新账本 | 验证可以修改账本信息 |
| 删除账本 | 验证可以删除账本 |
| 设置默认账本 | 验证可以设置默认账本 |
| 创建账户 | 验证可以创建各类账户 |
| 创建分类 | 验证可以创建收支分类 |
| 创建子分类 | 验证二级分类功能 |

### 3. 交易记录模块 (test_transactions.py)
| 测试用例 | 描述 |
|---------|------|
| 创建支出交易 | 验证支出记录创建 |
| 创建收入交易 | 验证收入记录创建 |
| 创建转账交易 | 验证账户间转账 |
| 支出更新余额 | 验证支出后账户余额减少 |
| 收入更新余额 | 验证收入后账户余额增加 |
| 按日期筛选 | 验证日期范围筛选功能 |
| 按分类筛选 | 验证分类筛选功能 |
| 更新交易 | 验证交易修改功能 |
| 删除交易 | 验证交易删除功能 |
| 交易标签 | 验证标签功能 |
| 可报销标记 | 验证报销标记功能 |
| 多币种账户创建 | 验证不同币种账户创建（CNY/USD/EUR/JPY/GBP/KRW/HKD/TWD） |
| 跨币种转账 | 验证不同货币账户间转账（手动汇率） |
| 手动汇率设置 | 验证手动设置汇率功能 |
| 汇率获取 | 验证获取当前汇率设置 |
| 货币转换计算 | 验证货币金额转换计算 |
| 多币种资产汇总 | 验证多币种资产汇总报告 |
| 货币分布报告 | 验证资产货币分布统计 |
| 按币种分组账户 | 验证按货币分组账户列表 |

### 4. 预算统计模块 (test_budgets.py)
| 测试用例 | 描述 |
|---------|------|
| 创建月度预算 | 验证月度预算创建 |
| 创建分类预算 | 验证特定分类预算创建 |
| 列出预算 | 验证预算列表获取 |
| 更新预算 | 验证预算修改 |
| 删除预算 | 验证预算删除 |
| 创建开支目标 | 验证消费目标创建 |
| 开支目标汇总 | 验证目标进度统计 |
| 月度统计 | 验证月度收支统计 |
| 分类统计 | 验证分类占比统计 |
| 趋势统计 | 验证趋势数据获取 |
| 年度报告 | 验证年度报告生成 |
| 净资产计算 | 验证资产计算功能 |

### 5. AI 功能模块 (test_ai_features.py)
| 测试用例 | 描述 |
|---------|------|
| 图片识别记账 | 验证小票图片解析 |
| 语音文本解析 | 验证语音输入解析 |
| 复杂语音解析 | 验证复杂描述解析 |
| 收入语音识别 | 验证收入类语音解析 |
| 智能分类建议 | 验证分类推荐功能 |
| 账单邮件解析 | 验证信用卡账单解析 |
| 邮箱绑定管理 | 验证邮箱绑定CRUD |

### 6. 债务和储蓄目标模块 (test_debts_and_goals.py)
| 测试用例 | 描述 |
|---------|------|
| 创建信用卡债务 | 验证信用卡类型债务创建 |
| 创建房贷债务 | 验证房贷类型债务创建 |
| 创建车贷债务 | 验证车贷类型债务创建 |
| 创建个人贷款 | 验证个人贷款债务创建 |
| 创建学生贷款 | 验证学生贷款债务创建 |
| 列出债务 | 验证债务列表获取 |
| 更新债务 | 验证债务信息修改 |
| 删除债务 | 验证债务删除功能 |
| 记录债务还款 | 验证还款记录创建 |
| 还款历史查询 | 验证还款历史获取 |
| 雪球还款策略 | 验证最小余额优先还款计划 |
| 雪崩还款策略 | 验证最高利率优先还款计划 |
| 策略对比 | 验证两种策略的对比分析 |
| 还款模拟器 | 验证自定义还款金额模拟 |
| 创建储蓄目标 | 验证储蓄目标创建 |
| 列出储蓄目标 | 验证目标列表获取 |
| 更新储蓄目标 | 验证目标修改功能 |
| 删除储蓄目标 | 验证目标删除功能 |
| 储蓄目标存款 | 验证目标存款记录 |
| 存款历史查询 | 验证存款历史获取 |
| 目标进度统计 | 验证目标完成度统计 |
| 创建账单提醒 | 验证账单提醒创建 |
| 列出账单提醒 | 验证提醒列表获取 |
| 更新账单提醒 | 验证提醒修改功能 |
| 删除账单提醒 | 验证提醒删除功能 |
| 标记提醒已付 | 验证标记已付功能 |
| 创建周期交易 | 验证周期性交易创建 |
| 列出周期交易 | 验证周期交易列表 |

### 7. 成员协作模块 (test_collaboration.py)
| 测试用例 | 描述 |
|---------|------|
| 创建共享账本 | 验证家庭/团队账本创建 |
| 生成邀请码 | 验证账本邀请码生成 |
| 列出账本成员 | 验证成员列表获取 |
| 更新成员角色 | 验证成员权限修改 |
| 移除成员 | 验证成员移除功能 |
| 设置成员预算 | 验证成员个人预算设置 |
| 成员预算状态 | 验证成员预算使用状态 |
| 启用审批流程 | 验证交易审批功能开启 |
| 待审批列表 | 验证待审批交易列表 |
| 审批交易 | 验证交易审批通过 |
| 拒绝交易 | 验证交易审批拒绝 |
| 成员消费对比 | 验证成员消费比较报告 |
| 成员分类明细 | 验证成员分类消费明细 |
| 成员预算执行 | 验证成员预算执行报告 |
| 创建备份 | 验证数据备份创建 |
| 列出备份 | 验证备份列表获取 |
| 备份详情 | 验证备份详细信息 |
| 删除备份 | 验证备份删除功能 |
| 同步状态 | 验证数据同步状态获取 |
| 触发同步 | 验证手动同步触发 |
| 同步历史 | 验证同步历史记录 |
| 同步设置 | 验证同步配置修改 |
| 同步冲突 | 验证冲突检测和列表 |
| 解决冲突 | 验证冲突解决功能 |
| 导出 CSV | 验证 CSV 格式导出 |
| 导出 Excel | 验证 Excel 格式导出 |
| WebDAV 配置 | 验证 WebDAV 服务配置 |
| WebDAV 测试 | 验证 WebDAV 连接测试 |
| WebDAV 上传 | 验证 WebDAV 数据上传 |
| WebDAV 下载 | 验证 WebDAV 数据下载 |

### 8. 端到端场景测试 (test_e2e_scenarios.py)
| 测试场景 | 描述 |
|---------|------|
| 新用户完整设置 | 注册→创建账本→添加账户→首笔记账 |
| 月度预算周期 | 创建预算→多笔消费→查看预算状态 |
| 多账户转账 | 创建账户→转账→验证余额 |
| 月度报告生成 | 收入支出记录→生成统计报告 |
| 开支目标追踪 | 创建目标→消费→检查进度 |
| 删除交易恢复余额 | 记账→删除→验证余额恢复 |

### 9. 前端单元测试 (widget_test.dart)
| 测试用例 | 描述 |
|---------|------|
| 邮箱验证 | 验证邮箱格式正则表达式 |
| 手机号验证 | 验证中国手机号格式 |
| CNY 货币格式 | 验证人民币格式化（¥1,234.56） |
| USD 货币格式 | 验证美元格式化（$1,234.56） |
| JPY 货币格式 | 验证日元格式化（无小数） |
| EUR 货币格式 | 验证欧元格式化 |
| GBP 货币格式 | 验证英镑格式化 |
| KRW 货币格式 | 验证韩元格式化（无小数） |
| HKD 货币格式 | 验证港币格式化（HK$） |
| TWD 货币格式 | 验证台币格式化（NT$） |
| 大数字压缩显示 | 验证万/M/K 压缩显示 |
| 货币符号 | 验证8种货币符号正确 |
| 货币小数位 | 验证货币小数位数（JPY/KRW 为0，其他为2） |
| 手动汇率转换 | 验证汇率转换计算 |
| 汇率验证 | 验证汇率有效性检查（>0） |
| 中文日期格式 | 验证日期中文显示 |
| 交易类型标签 | 验证收入/支出/转账标签 |
| 交易类型颜色 | 验证交易类型颜色 |
| 预算百分比计算 | 验证预算使用百分比 |
| 预算状态判断 | 验证正常/警告/超支状态 |
| 账户类型标签 | 验证现金/银行卡等标签 |
| 账户类型图标 | 验证账户类型图标 |

### 10. 前端数据模型测试 (models_test.dart)
| 测试用例 | 描述 |
|---------|------|
| Transaction 序列化 | 验证交易记录 JSON 序列化/反序列化 |
| Transaction 默认值 | 验证交易记录默认字段值 |
| Transaction 类型判断 | 验证收入/支出/转账类型判断 |
| Account 序列化 | 验证账户 JSON 序列化/反序列化 |
| Account 类型枚举 | 验证账户类型枚举转换 |
| Account 余额计算 | 验证账户余额相关方法 |
| Category 序列化 | 验证分类 JSON 序列化/反序列化 |
| Category 层级关系 | 验证父子分类关系 |
| Category 类型判断 | 验证收入/支出分类判断 |
| Budget 序列化 | 验证预算 JSON 序列化/反序列化 |
| Budget 周期类型 | 验证周/月/年预算周期 |
| Budget 状态计算 | 验证预算使用状态计算 |
| Debt 序列化 | 验证债务 JSON 序列化/反序列化 |
| Debt 类型枚举 | 验证债务类型（信用卡/房贷/车贷等） |
| Debt 还款计算 | 验证剩余金额和进度计算 |
| SavingsGoal 序列化 | 验证储蓄目标 JSON 序列化/反序列化 |
| SavingsGoal 进度计算 | 验证目标完成度计算 |
| SavingsGoal 日期验证 | 验证目标日期有效性 |
| BillReminder 序列化 | 验证账单提醒 JSON 序列化/反序列化 |
| BillReminder 状态 | 验证提醒状态（待付/已付/逾期） |
| BillReminder 周期 | 验证提醒周期设置 |
| Book 序列化 | 验证账本 JSON 序列化/反序列化 |
| Book 类型枚举 | 验证账本类型（个人/家庭/商业） |
| Book 成员角色 | 验证成员角色枚举 |
| Sync 模型序列化 | 验证同步相关模型序列化 |
| Sync 状态枚举 | 验证同步状态（成功/失败/冲突） |
| Sync 配置验证 | 验证同步配置有效性 |

## 测试配置

### 测试数据库

测试使用独立的测试数据库，配置在 `conftest.py`:

```python
TEST_DATABASE_URL = "postgresql+asyncpg://ai_bookkeeping:password@localhost:5432/ai_bookkeeping_test"
```

### 创建测试数据库

```sql
CREATE DATABASE ai_bookkeeping_test;
GRANT ALL PRIVILEGES ON DATABASE ai_bookkeeping_test TO ai_bookkeeping;
```

### 环境变量

```bash
# 设置测试数据库 URL
export TEST_DATABASE_URL="postgresql+asyncpg://user:pass@localhost:5432/ai_bookkeeping_test"
```

## 测试 Fixtures

主要的测试 fixtures:

| Fixture | 描述 |
|---------|------|
| `client` | HTTP 测试客户端 |
| `db_session` | 数据库会话 |
| `test_user` | 测试用户 |
| `test_user_token` | 用户认证令牌 |
| `authenticated_client` | 已认证的 HTTP 客户端 |
| `test_book` | 测试账本 |
| `test_account` | 测试账户 |
| `test_category` | 测试分类 |
| `expense_category` | 支出分类 |
| `income_category` | 收入分类 |
| `data_factory` | 测试数据生成工厂 |

## 测试最佳实践

1. **隔离性**: 每个测试独立运行，使用事务回滚保证数据隔离
2. **可重复性**: 测试可以多次运行，结果一致
3. **描述性**: 测试名称清晰描述测试内容
4. **覆盖完整**: 覆盖正常流程和异常情况
5. **快速执行**: 单个测试执行时间控制在合理范围

## CI/CD 集成

### GitHub Actions 示例

```yaml
name: Tests

on: [push, pull_request]

jobs:
  backend-tests:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_USER: ai_bookkeeping
          POSTGRES_PASSWORD: testpass
          POSTGRES_DB: ai_bookkeeping_test
        ports:
          - 5432:5432

    steps:
      - uses: actions/checkout@v3
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      - name: Install dependencies
        run: |
          cd server
          pip install -r requirements.txt
      - name: Run tests
        run: |
          cd server
          pytest tests/ -v --cov=app

  frontend-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - name: Run tests
        run: |
          cd app
          flutter test
```

## 故障排除

### 常见问题

1. **数据库连接失败**
   - 检查 PostgreSQL 服务是否运行
   - 检查测试数据库是否存在
   - 检查连接字符串是否正确

2. **测试超时**
   - 增加 pytest 超时设置
   - 检查网络连接（AI 功能测试）

3. **依赖缺失**
   - 运行 `pip install -r requirements.txt`
   - 确保测试依赖已安装

---

*文档版本: 1.2*
*更新日期: 2025-12-30*
