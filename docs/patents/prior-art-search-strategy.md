# 现有技术检索策略

生成时间: 2026-01-19
用途: 专利申请前的现有技术检索

## 检索数据库

| 数据库 | 用途 | URL |
|--------|------|-----|
| 国家知识产权局 | 中国专利 | http://pss-system.cnipa.gov.cn/ |
| Google Patents | 全球专利 | https://patents.google.com/ |
| 中国知网 | 学术论文 | https://www.cnki.net/ |
| IEEE Xplore | 技术论文 | https://ieeexplore.ieee.org/ |

## 竞争对手清单

| 公司 | 主要产品 | 重点关注领域 |
|------|----------|--------------|
| 蚂蚁集团 | 支付宝 | 记账、预算、理财 |
| 腾讯 | 微信支付 | 账单、消费分析 |
| 随手科技 | 随手记 | 记账、预算、报表 |
| 挖财 | 挖财记账 | 智能记账、分析 |
| 鲨鱼记账 | 鲨鱼记账 | 语音记账、图表 |
| 网易 | 网易有钱 | 多账户、同步 |

---

## 各专利检索策略

### P01-FIFO钱龄计算

**核心技术关键词：**
- 中文：FIFO、先进先出、资金追踪、钱龄、资金年龄、资源池、资金流向
- 英文：FIFO, First-In-First-Out, money age, fund tracking, resource pool, cash flow tracking

**IPC分类号：**
- G06Q 40/00 - 金融；保险；税务策略
- G06Q 40/06 - 资产管理
- G06F 16/00 - 信息检索；数据库结构

**检索式：**
```
CN: (FIFO OR 先进先出) AND (资金 OR 钱) AND (追踪 OR 计算 OR 管理)
EN: FIFO AND (money OR fund OR cash) AND (age OR tracking OR management)
```

**潜在相似技术：**
- 库存管理中的FIFO方法
- 会计软件中的成本计算
- 投资组合的先进先出计算

---

### P02-多模态融合记账

**核心技术关键词：**
- 中文：多模态、语音识别、图像识别、OCR、智能记账、融合处理、票据识别
- 英文：multimodal, voice recognition, image recognition, OCR, intelligent bookkeeping, fusion

**IPC分类号：**
- G06F 40/00 - 自然语言处理
- G06V 30/00 - 字符识别；文档识别
- G10L 15/00 - 语音识别
- G06Q 40/00 - 金融

**检索式：**
```
CN: (多模态 OR 语音 OR 图像) AND (记账 OR 账单 OR 财务) AND (识别 OR 融合)
EN: (multimodal OR voice OR image) AND (bookkeeping OR accounting) AND recognition
```

**潜在相似技术：**
- 银行票据识别系统
- 智能语音助手
- 发票OCR识别

---

### P03-差分隐私学习（搁置）

*用户表示差分隐私代码正在完善，暂不检索*

---

### P04-自适应预算

**核心技术关键词：**
- 中文：自适应预算、动态预算、智能预算、预算调整、零基预算、预算分配
- 英文：adaptive budget, dynamic budget, intelligent budget, budget adjustment, zero-based budget

**IPC分类号：**
- G06Q 40/00 - 金融
- G06Q 10/06 - 资源、工作流程、人员或项目管理
- G06N 20/00 - 机器学习

**检索式：**
```
CN: (自适应 OR 动态 OR 智能) AND 预算 AND (调整 OR 分配 OR 管理)
EN: (adaptive OR dynamic OR intelligent) AND budget AND (adjustment OR allocation)
```

**潜在相似技术：**
- 企业预算管理系统
- 个人理财软件的预算功能
- 自动化财务规划

---

### P05-LLM语音交互

**核心技术关键词：**
- 中文：大语言模型、语音交互、意图识别、多轮对话、语音记账、自然语言理解
- 英文：LLM, large language model, voice interaction, intent recognition, multi-turn dialogue

**IPC分类号：**
- G10L 15/00 - 语音识别
- G06F 40/30 - 语义分析
- G06N 3/00 - 基于生物学模型的计算机系统（神经网络）
- G06Q 40/00 - 金融

**检索式：**
```
CN: (大语言模型 OR LLM OR 语音) AND (记账 OR 财务) AND (意图 OR 识别 OR 交互)
EN: (LLM OR "large language model" OR voice) AND (bookkeeping OR financial) AND intent
```

**潜在相似技术：**
- 智能语音助手（Siri、小爱、天猫精灵）
- 对话式AI系统
- 语音银行服务

---

### P06-位置增强管理

**核心技术关键词：**
- 中文：地理围栏、位置服务、位置触发、场景识别、位置记账、商户识别
- 英文：geofence, location service, location trigger, scene recognition, merchant recognition

**IPC分类号：**
- G06Q 40/00 - 金融
- G01C 21/00 - 导航
- H04W 4/02 - 位置服务
- G06F 16/29 - 地理信息检索

**检索式：**
```
CN: (地理围栏 OR 位置 OR 定位) AND (记账 OR 消费 OR 财务) AND (触发 OR 识别)
EN: (geofence OR location) AND (expense OR spending OR financial) AND (trigger OR recognition)
```

**潜在相似技术：**
- 基于位置的营销系统
- 签到类应用
- 商户定位服务

---

### P07-交易去重

**核心技术关键词：**
- 中文：交易去重、重复检测、多因子评分、账单导入、数据清洗、相似度匹配
- 英文：transaction deduplication, duplicate detection, multi-factor scoring, similarity matching

**IPC分类号：**
- G06Q 40/00 - 金融
- G06F 16/00 - 信息检索；数据库结构
- G06F 18/00 - 模式识别

**检索式：**
```
CN: (交易 OR 账单) AND (去重 OR 重复 OR 检测) AND (多因子 OR 相似度)
EN: transaction AND (deduplication OR duplicate) AND (detection OR matching)
```

**潜在相似技术：**
- 银行对账系统
- 数据清洗工具
- 账单合并软件

---

### P08-智能可视化

**核心技术关键词：**
- 中文：智能可视化、自适应图表、数据展示、财务报表、渐进式披露、用户画像
- 英文：intelligent visualization, adaptive chart, data presentation, progressive disclosure

**IPC分类号：**
- G06T 11/00 - 2D图像生成
- G06F 16/00 - 信息检索
- G06Q 40/00 - 金融

**检索式：**
```
CN: (智能 OR 自适应) AND (可视化 OR 图表) AND (财务 OR 数据)
EN: (intelligent OR adaptive) AND visualization AND (financial OR data)
```

**潜在相似技术：**
- BI工具（Tableau、Power BI）
- 财务仪表板
- 数据分析平台

---

### P09-财务健康评分

**核心技术关键词：**
- 中文：财务健康、健康评分、财务指标、收支分析、预警系统、财务评估
- 英文：financial health, health score, financial indicator, income-expense analysis

**IPC分类号：**
- G06Q 40/00 - 金融
- G06Q 40/08 - 保险（风险评估）
- G06N 20/00 - 机器学习

**检索式：**
```
CN: (财务健康 OR 财务评分) AND (评估 OR 指标 OR 分析)
EN: "financial health" AND (score OR assessment OR indicator)
```

**潜在相似技术：**
- 信用评分系统
- 理财规划工具
- 财务诊断服务

---

### P10-账单解析导入

**核心技术关键词：**
- 中文：账单解析、账单导入、格式识别、数据提取、智能解析、CSV解析
- 英文：bill parsing, bill import, format detection, data extraction

**IPC分类号：**
- G06F 40/00 - 自然语言处理
- G06Q 40/00 - 金融
- G06F 16/00 - 信息检索

**检索式：**
```
CN: (账单 OR 对账单) AND (解析 OR 导入 OR 识别) AND (智能 OR 自动)
EN: (bill OR statement) AND (parsing OR import) AND (intelligent OR automatic)
```

**潜在相似技术：**
- 银行对账单解析
- 电子发票识别
- 数据导入工具

---

### P11-离线增量同步

**核心技术关键词：**
- 中文：离线同步、增量同步、CRDT、冲突解决、离线优先、数据一致性
- 英文：offline sync, incremental sync, CRDT, conflict resolution, offline-first

**IPC分类号：**
- G06F 16/00 - 信息检索；数据库结构
- G06F 16/27 - 复制；分布式数据库
- H04L 67/10 - 同步协议

**检索式：**
```
CN: (离线 OR 增量) AND 同步 AND (冲突 OR 一致性 OR CRDT)
EN: (offline OR incremental) AND sync AND (conflict OR consistency OR CRDT)
```

**潜在相似技术：**
- 分布式数据库同步
- 云存储同步
- 协作编辑工具

---

### P12-游戏化激励

**核心技术关键词：**
- 中文：游戏化、成就系统、积分激励、用户留存、行为激励、徽章系统
- 英文：gamification, achievement system, points reward, user retention, behavioral incentive

**IPC分类号：**
- G06Q 30/00 - 商业
- A63F 13/00 - 视频游戏
- G06Q 40/00 - 金融

**检索式：**
```
CN: 游戏化 AND (记账 OR 财务 OR 理财) AND (激励 OR 成就 OR 积分)
EN: gamification AND (bookkeeping OR financial) AND (incentive OR achievement)
```

**潜在相似技术：**
- 健身APP的激励系统
- 学习APP的成就系统
- 会员积分系统

---

### P13-家庭协作记账

**核心技术关键词：**
- 中文：家庭记账、协作记账、多用户、权限控制、共享账本、分摊计算
- 英文：family accounting, collaborative bookkeeping, multi-user, permission control

**IPC分类号：**
- G06Q 40/00 - 金融
- G06Q 10/10 - 办公自动化（协作）
- G06F 21/00 - 安全（访问控制）

**检索式：**
```
CN: (家庭 OR 协作 OR 多用户) AND (记账 OR 账本) AND (权限 OR 分摊)
EN: (family OR collaborative) AND (bookkeeping OR accounting) AND (permission OR sharing)
```

**潜在相似技术：**
- 家庭财务管理软件
- 团队费用分摊应用
- 共享账本工具

---

### P14-冷静期控制

**核心技术关键词：**
- 中文：冷静期、冲动消费、消费控制、延迟购买、消费提醒、行为干预
- 英文：cooling-off period, impulse buying, spending control, delayed purchase

**IPC分类号：**
- G06Q 40/00 - 金融
- G06Q 30/00 - 商业
- G06N 20/00 - 机器学习（行为预测）

**检索式：**
```
CN: (冷静期 OR 冲动消费) AND (控制 OR 提醒 OR 干预)
EN: ("cooling off" OR "impulse buying") AND (control OR reminder OR intervention)
```

**潜在相似技术：**
- 消费者保护法中的冷静期
- 购物提醒应用
- 行为经济学应用

---

### P15-可变收入适配

**核心技术关键词：**
- 中文：可变收入、不稳定收入、收入预测、预算适配、自由职业、收入波动
- 英文：variable income, irregular income, income prediction, budget adaptation, freelance

**IPC分类号：**
- G06Q 40/00 - 金融
- G06Q 10/06 - 资源管理
- G06N 20/00 - 机器学习

**检索式：**
```
CN: (可变收入 OR 不稳定收入 OR 自由职业) AND (预算 OR 理财 OR 规划)
EN: ("variable income" OR "irregular income" OR freelance) AND (budget OR financial planning)
```

**潜在相似技术：**
- 自由职业者财务工具
- 收入预测系统
- 灵活预算管理

---

### P16-订阅追踪检测

**核心技术关键词：**
- 中文：订阅追踪、订阅管理、周期性消费、浪费检测、自动续费、订阅提醒
- 英文：subscription tracking, subscription management, recurring expense, waste detection

**IPC分类号：**
- G06Q 40/00 - 金融
- G06Q 30/00 - 商业（订阅）
- G06F 16/00 - 信息检索

**检索式：**
```
CN: (订阅 OR 周期性消费 OR 自动续费) AND (追踪 OR 管理 OR 检测)
EN: subscription AND (tracking OR management OR detection) AND (recurring OR waste)
```

**潜在相似技术：**
- 订阅管理应用（Truebill、Trim）
- 账单分析工具
- 自动扣款提醒

---

### P17-债务健康管理

**核心技术关键词：**
- 中文：债务管理、还款计划、雪球法、雪崩法、债务健康、还款优化
- 英文：debt management, repayment plan, debt snowball, debt avalanche, debt health

**IPC分类号：**
- G06Q 40/00 - 金融
- G06Q 40/02 - 银行（贷款）
- G06N 20/00 - 机器学习

**检索式：**
```
CN: 债务 AND (管理 OR 还款 OR 优化) AND (雪球 OR 雪崩 OR 计划)
EN: debt AND (management OR repayment OR optimization) AND (snowball OR avalanche OR plan)
```

**潜在相似技术：**
- 债务整合服务
- 信用卡还款工具
- 财务规划软件

---

### P18-消费趋势预测

**核心技术关键词：**
- 中文：消费预测、趋势分析、支出预测、时间序列、季节性分析、消费模式
- 英文：spending prediction, trend analysis, expenditure forecast, time series, seasonal analysis

**IPC分类号：**
- G06Q 40/00 - 金融
- G06N 20/00 - 机器学习
- G06F 18/00 - 模式识别

**检索式：**
```
CN: (消费 OR 支出) AND (预测 OR 趋势) AND (分析 OR 模式)
EN: (spending OR expenditure) AND (prediction OR forecast OR trend) AND analysis
```

**潜在相似技术：**
- 消费行为分析
- 预算预测工具
- 商业智能系统

---

## 检索执行建议

### 检索顺序

建议按以下优先级进行检索：

1. **高优先级**（核心创新）：P01、P05、P11
2. **中优先级**（差异化功能）：P02、P04、P07、P14
3. **低优先级**（常见功能增强）：其他专利

### 检索深度

| 数据库 | 建议检索数量 |
|--------|--------------|
| 国知局 | 前100条 |
| Google Patents | 前50条 |
| 学术论文 | 前20条 |

### 相似度判断

| 相似度 | 判断标准 | 处理建议 |
|--------|----------|----------|
| >80% | 技术方案基本相同 | 考虑放弃或重大修改 |
| 50-80% | 部分技术特征相同 | 调整权利要求，突出差异 |
| 20-50% | 存在一定关联 | 在说明书中引用并说明区别 |
| <20% | 无明显相似 | 正常申请 |

---

## 下一步行动

1. 按优先级顺序进行专利数据库检索
2. 记录检索结果和相似专利
3. 分析技术差异点
4. 生成检索报告
