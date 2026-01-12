# 语音助手覆盖度增强 - 任务清单

## 1. P0 - 语音配置项扩展（用户体验核心）

### 1.1 预算高级配置（12项）
- [x] 1.1.1 添加零基预算配置
  - 文件：`app/lib/services/voice_config_service.dart`
  - 配置项：budget.zero_based.enabled, budget.zero_based.period
  - 语音示例："开启零基预算"、"每周重新分配预算"

- [x] 1.1.2 添加预算模板配置
  - 配置项：budget.template.save, budget.template.apply
  - 语音示例："保存当前预算为模板"、"应用节俭模式预算"

- [x] 1.1.3 添加预算结转规则配置
  - 配置项：budget.carryover.mode, budget.carryover.limit
  - 语音示例："剩余预算只结转一半"、"设置结转上限500"

- [x] 1.1.4 添加分类预算比例配置
  - 配置项：budget.category.ratio.*
  - 语音示例："餐饮预算占比调整到30%"

### 1.2 信用卡详细配置（8项）
- [x] 1.2.1 添加信用卡额度配置
  - 配置项：creditcard.limit, creditcard.temp_limit
  - 语音示例："信用卡额度改成5万"、"申请临时额度3万"

- [x] 1.2.2 添加还款策略配置
  - 配置项：creditcard.payment.min_ratio, creditcard.payment.auto
  - 语音示例："最低还款比例10%"、"开启自动全额还款"

- [x] 1.2.3 添加免息期配置
  - 配置项：creditcard.interest_free_days
  - 语音示例："免息期改成50天"

### 1.3 家庭账本配置（10项）
- [x] 1.3.1 添加成员权限配置
  - 配置项：family.member.permission.*
  - 语音示例："老婆可以编辑记录"、"孩子只能查看"

- [x] 1.3.2 添加审批规则配置
  - 配置项：family.approval.threshold, family.approval.required
  - 语音示例："超过500需要审批"、"开启消费审批"

- [x] 1.3.3 添加家庭预算分配配置
  - 配置项：family.budget.allocation.*
  - 语音示例："我的预算占60%"

### 1.4 AI智能配置（10项）
- [x] 1.4.1 添加分类置信度配置
  - 配置项：ai.category.confidence_threshold
  - 语音示例："分类置信度阈值调到80%"

- [x] 1.4.2 添加异常检测参数配置
  - 配置项：ai.anomaly.sensitivity, ai.anomaly.amount_threshold
  - 语音示例："异常检测灵敏度调高"、"超过1000才算异常"

- [x] 1.4.3 添加智能建议配置
  - 配置项：ai.suggestion.frequency, ai.suggestion.types
  - 语音示例："每周给我一次消费建议"

### 1.5 习惯培养配置（8项）
- [x] 1.5.1 添加打卡提醒配置
  - 配置项：habit.checkin.reminder_time, habit.checkin.streak_notify
  - 语音示例："每天晚上9点提醒打卡"

- [x] 1.5.2 添加挑战配置
  - 配置项：habit.challenge.difficulty, habit.challenge.duration
  - 语音示例："开始一个省钱挑战"

- [x] 1.5.3 添加奖励配置
  - 配置项：habit.reward.auto_redeem
  - 语音示例："自动兑换奖励"

### 1.6 钱龄配置（6项）
- [x] 1.6.1 添加钱龄计算配置
  - 配置项：money_age.calculation.method, money_age.display.unit
  - 语音示例："钱龄用天数显示"

- [x] 1.6.2 添加钱龄预警配置
  - 配置项：money_age.alert.threshold
  - 语音示例："钱龄低于30天提醒我"

### 1.7 其他配置扩展（32项）
- [x] 1.7.1 添加数据保留配置
  - 配置项：data.retention.*, data.export.format

- [x] 1.7.2 添加隐私保护配置
  - 配置项：privacy.blur.level, privacy.sensitive.categories

- [x] 1.7.3 添加通知偏好配置
  - 配置项：notification.channels.*, notification.quiet_hours

- [x] 1.7.4 添加导入导出配置
  - 配置项：import.duplicate.strategy, export.include.images

## 2. P0 - 直接操作扩展（用户体验核心）

### 2.1 钱龄操作（6项）
- [x] 2.1.1 实现查看钱龄操作
  - 文件：`app/lib/services/voice_service_coordinator.dart`
  - 添加：_handleMoneyAgeIntent()
  - 语音示例："查看钱龄"、"我的资金健康度"

- [x] 2.1.2 实现钱龄优化建议操作
  - 语音示例："钱龄优化建议"、"怎么提高钱龄"

- [x] 2.1.3 实现资源池查看操作
  - 语音示例："查看资金池"、"FIFO详情"

### 2.2 习惯操作（6项）
- [x] 2.2.1 实现打卡操作
  - 添加：_handleHabitIntent()
  - 语音示例："打卡"、"今日打卡"

- [x] 2.2.2 实现挑战操作
  - 语音示例："完成挑战"、"查看挑战进度"

- [x] 2.2.3 实现奖励操作
  - 语音示例："兑换奖励"、"查看可用积分"

### 2.3 小金库操作（6项）
- [x] 2.3.1 实现资金分配操作
  - 添加：_handleVaultIntent()
  - 语音示例："分配1000到旅游"、"把餐饮的200调到购物"

- [x] 2.3.2 实现小金库查询操作
  - 语音示例："旅游小金库还有多少"、"各小金库余额"

### 2.4 数据操作（6项）
- [x] 2.4.1 实现备份操作
  - 添加：_handleDataIntent()
  - 语音示例："立即备份"、"备份到云端"

- [x] 2.4.2 实现导出操作
  - 语音示例："导出本月数据"、"导出年度报告"

- [x] 2.4.3 实现同步操作
  - 语音示例："同步数据"、"强制刷新"

### 2.5 分享操作（4项）
- [x] 2.5.1 实现报告分享操作
  - 添加：_handleShareIntent()
  - 语音示例："分享月报"、"生成年度总结"

- [x] 2.5.2 实现邀请操作
  - 语音示例："邀请好友"、"生成邀请链接"

### 2.6 系统操作（6项）
- [x] 2.6.1 实现检查更新操作
  - 添加：_handleSystemIntent()
  - 语音示例："检查更新"、"当前版本"

- [x] 2.6.2 实现反馈操作
  - 语音示例："提交反馈"、"联系客服"

- [x] 2.6.3 实现清理操作
  - 语音示例："清理缓存"、"释放空间"

## 3. P1 - 自学习系统激活

### 3.1 反馈采集层
- [x] 3.1.1 实现用户反馈采集服务
  - 文件：`app/lib/services/voice/self_learning_service.dart`（新建）
  - 功能：采集确认/修改/取消信号
  - 接入点：VoiceServiceCoordinator确认流程

- [x] 3.1.2 实现样本存储
  - 使用现有SampleStore
  - 添加：采集时间、上下文、结果标签

- [x] 3.1.3 实现样本质量评分
  - 规则：用户确认=正样本，修改=弱负样本，取消=负样本

### 3.2 模式挖掘层
- [x] 3.2.1 实现高频模式提取
  - 使用现有PatternMiner
  - 添加：频率统计、模式聚类

- [x] 3.2.2 实现同义词发现
  - 基于用户修改记录提取同义表达
  - 输出：更新SmartIntentRecognizer同义词库

- [x] 3.2.3 实现模板优化
  - 分析识别失败案例
  - 生成新的模板规则

### 3.3 规则生成层
- [x] 3.3.1 实现个性化规则生成
  - 集成到：`app/lib/services/voice/self_learning_service.dart`
  - 基于用户习惯生成专属规则

- [x] 3.3.2 实现规则优先级管理
  - 个性化规则 > 全局规则

- [x] 3.3.3 实现规则置信度更新
  - 基于命中率和准确率动态调整

### 3.4 效果评估层
- [x] 3.4.1 实现学习效果评估
  - 集成到：`app/lib/services/voice/self_learning_service.dart`
  - 指标：规则命中率、准确率变化、LLM调用减少

- [x] 3.4.2 实现评估仪表盘UI
  - 位置：设置 > 语音 > 学习报告
  - 展示：学习进度、效果曲线
  - 实现：`app/lib/pages/voice_learning_report_page.dart`

### 3.5 学习触发机制
- [x] 3.5.1 实现定时学习任务
  - 触发时间：凌晨2:00（用户低活跃期）
  - 条件：样本数 > 100

- [x] 3.5.2 实现手动触发入口
  - 位置：设置 > 语音 > 立即优化

## 4. P1 - 意图识别增强

### 4.1 规则库扩展
- [x] 4.1.1 扩展记账规则（+50条）
  - 文件：`app/lib/services/voice/smart_intent_recognizer.dart`
  - 覆盖更多口语表达

- [x] 4.1.2 扩展查询规则（+30条）
  - 覆盖钱龄、习惯、小金库查询

- [x] 4.1.3 扩展配置规则（+40条）
  - 覆盖新增的86项配置

### 4.2 同义词库扩展
- [x] 4.2.1 添加地域表达差异
  - 如："块钱" vs "元" vs "刀"

- [x] 4.2.2 添加行业术语映射
  - 如："花呗" → "蚂蚁花呗"

### 4.3 模板匹配增强
- [x] 4.3.1 优化槽位提取
  - 更灵活的金额、时间、分类提取

- [x] 4.3.2 添加复合模板
  - 支持"先...再..."等复合句式

## 5. P2 - 知识库系统

### 5.1 FAQ知识库
- [x] 5.1.1 创建FAQ数据仓库
  - 文件：`app/lib/services/voice/knowledge_base_service.dart`（新建）
  - 初始100+问答对

- [x] 5.1.2 实现FAQ匹配服务
  - 关键词匹配 + 相似度计算
  - 返回最相关答案

### 5.2 帮助引导
- [x] 5.2.1 创建功能说明库
  - 每个功能的使用说明
  - 支持语音播报

- [x] 5.2.2 实现操作指引生成
  - 根据用户问题生成步骤指引

### 5.3 问题收集
- [x] 5.3.1 实现问题分类
  - 自动分类用户反馈

- [x] 5.3.2 实现问题上报
  - 复杂问题自动上报

## 6. P2 - 情绪识别增强

### 6.1 情绪应对策略
- [x] 6.1.1 完善情绪话术库
  - 文件：`app/lib/services/voice/emotional_response_service.dart`（新建）
  - 不同情绪对应不同话术风格

- [x] 6.1.2 实现话术动态选择
  - 基于情绪强度调整语气

### 6.2 情感化TTS
- [x] 6.2.1 实现TTS参数动态调节
  - 成功确认：轻快语调
  - 错误提示：关切语调

## 依赖关系

```
1.x 配置扩展 → 4.1.3 配置规则扩展
2.x 操作扩展 → 4.1.2 查询规则扩展

3.1 反馈采集 → 3.2 模式挖掘 → 3.3 规则生成 → 3.4 效果评估

5.1 FAQ → VoiceOtherIntentService 集成

6.x 可独立进行
```

## 验证检查点

- [x] 语音配置项达到200项
- [x] 直接操作覆盖率达到85%+
- [x] 自学习系统可正常触发
- [x] 学习效果仪表盘可查看
- [x] FAQ问答可正常响应
- [x] 情绪应对话术生效
