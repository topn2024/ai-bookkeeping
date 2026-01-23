# 专利-代码映射表

生成时间: 2026-01-19
用途: 验证专利技术方案与代码实现的对应关系

## 映射总览

| 专利编号 | 专利名称 | 代码实现状态 | 核心代码文件 |
|----------|----------|--------------|--------------|
| P01 | FIFO钱龄计算 | ✅ 已实现 | resource_pool_manager.dart, money_age_calculator.dart |
| P02 | 多模态融合记账 | ✅ 已实现 | multimodal_input_service.dart |
| P03 | 差分隐私学习 | ✅ 已实现 | differential_privacy_service.dart, unified_learning_framework.dart |
| P04 | 自适应预算 | ✅ 已实现 | adaptive_budget_service.dart |
| P05 | LLM语音交互 | ✅ 已实现 | voice_service_coordinator.dart, intelligence_engine.dart |
| P06 | 位置增强管理 | ✅ 已实现 | geofence_background_service.dart |
| P07 | 交易去重 | ✅ 已实现 | duplicate_detection_service.dart |
| P08 | 智能可视化 | ✅ 已实现 | optimized_charts.dart |
| P09 | 财务健康评分 | ✅ 已实现 | financial_health_score_service.dart |
| P10 | 账单解析导入 | ✅ 已实现 | bill_parser.dart |
| P11 | 离线增量同步 | ✅ 已实现 | crdt_sync_service.dart |
| P12 | 游戏化激励 | ✅ 已实现 | gamification_service.dart |
| P13 | 家庭协作记账 | ✅ 已实现 | family_budget_service.dart |
| P14 | 冷静期控制 | ✅ 已实现 | cooling_off_service.dart |
| P15 | 可变收入适配 | ✅ 已实现 | variable_income_adapter.dart |
| P16 | 订阅追踪检测 | ✅ 已实现 | subscription_tracking_service.dart |
| P17 | 债务健康管理 | ✅ 已实现 | debt_health_service.dart |
| P18 | 消费趋势预测 | ✅ 已实现 | trend_prediction_service.dart |

---

## 详细映射

### P01-FIFO钱龄计算

**核心代码文件:**
- `app/lib/services/resource_pool_manager.dart` - FIFO资源池管理
- `app/lib/services/money_age_calculator.dart` - 钱龄计算引擎
- `app/lib/models/resource_pool.dart` - 资源池数据模型
- `app/lib/services/smart_money_age_service.dart` - 智能钱龄服务
- `app/lib/services/money_age_progression_service.dart` - 钱龄进度追踪
- `app/lib/services/money_age_trend_service.dart` - 钱龄趋势分析

**UI页面:**
- `app/lib/pages/money_age_page.dart`
- `app/lib/pages/money_age_resource_pool_page.dart`

**待验证数据:**
- [ ] "钱龄计算精度达到毫秒级" - 需验证代码实现
- [ ] "资源池操作平均响应时间小于10ms" - 需性能测试

---

### P02-多模态融合记账

**核心代码文件:**
- `app/lib/services/multimodal_input_service.dart` - 多模态统一入口
- `app/lib/services/multimodal_wakeup_service.dart` - 多模态唤醒
- `app/lib/services/ai/image_recognition_service.dart` - 图像识别
- `app/lib/services/ai/text_parsing_service.dart` - 文本解析
- `app/lib/services/voice_recognition_engine.dart` - 语音识别

**UI页面:**
- `app/lib/pages/multimodal_input_page.dart`

**待验证数据:**
- [ ] 多模态融合的具体实现逻辑
- [ ] 各模态输入的处理流程

---

### P03-差分隐私学习

**核心代码文件:**
- `app/lib/services/security/data_masking_service.dart` - 数据脱敏
- `app/lib/services/security/sensitive_data_encryption_service.dart` - 敏感数据加密
- `app/lib/services/family_privacy_service.dart` - 家庭隐私管理
- `app/lib/services/location_privacy_guard.dart` - 位置隐私保护

**⚠️ 重要发现:**
当前代码实现的是**数据脱敏和加密**，而非专利声称的**差分隐私**机制。
差分隐私需要在数据上添加校准噪声，这在当前代码中**未找到实现**。

**建议:**
1. 如果未实现差分隐私，需修改专利名称和技术方案描述
2. 或者补充差分隐私的代码实现

---

### P04-自适应预算

**核心代码文件:**
- `app/lib/services/adaptive_budget_service.dart` - 自适应预算
- `app/lib/services/budget/budget_suggestion_engine.dart` - 预算建议
- `app/lib/services/self_learning_budget_service.dart` - 自学习预算
- `app/lib/services/budget_planning_coordinator.dart` - 预算规划
- `app/lib/services/budget_distribution_engine.dart` - 预算分配
- `app/lib/services/budget_alert_service.dart` - 预算告警

**UI页面:**
- `app/lib/pages/budget_center_page.dart`
- `app/lib/pages/budget_management_page.dart`

**待验证数据:**
- [ ] 自适应算法的具体实现
- [ ] 预算调整的触发条件和幅度

---

### P05-LLM语音交互

**核心代码文件:**
- `app/lib/services/global_voice_assistant_manager.dart` - 全局语音助手
- `app/lib/services/voice_service_coordinator.dart` - 语音服务协调
- `app/lib/services/voice/intelligence_engine/intelligence_engine.dart` - 智能引擎
- `app/lib/services/voice/smart_intent_recognizer.dart` - 智能意图识别
- `app/lib/services/voice/agent/llm_intent_classifier.dart` - LLM意图分类
- `app/lib/services/voice/client_llm_service.dart` - 端侧LLM
- `app/lib/services/qwen_service.dart` - 通义千问集成
- `app/lib/services/voice/conversation_context.dart` - 会话上下文
- `app/lib/services/voice/voice_session_state_machine.dart` - 会话状态机

**UI页面:**
- `app/lib/pages/voice_assistant_page.dart`
- `app/lib/pages/enhanced_voice_assistant_page.dart`

**待验证数据:**
- [ ] "纯规则引擎准确率仅70-75%" - 需测试数据
- [ ] "纯LLM方案延迟1-2秒" - 需性能测试
- [ ] "四维交互"定义与代码实现的一致性

---

### P06-位置增强管理

**核心代码文件:**
- `app/lib/services/geofence_background_service.dart` - 地理围栏后台
- `app/lib/services/location_service.dart` - 位置服务
- `app/lib/services/location_trigger_service.dart` - 位置触发器
- `app/lib/services/location_enhanced_budget_service.dart` - 位置增强预算
- `app/lib/services/location_budget_reminder.dart` - 位置预算提醒

**UI页面:**
- `app/lib/pages/geofence_management_page.dart`
- `app/lib/pages/location_analysis_page.dart`

---

### P07-交易去重

**核心代码文件:**
- `app/lib/services/duplicate_detection_service.dart` - 重复检测
- `app/lib/services/import/duplicate_scorer.dart` - 重复评分
- `app/lib/services/import/enhanced_duplicate_scorer.dart` - 增强重复评分
- `app/lib/services/import/batch_import_service.dart` - 批量导入

**UI页面:**
- `app/lib/pages/import/duplicate_detection_page.dart`
- `app/lib/pages/import/deduplication_page.dart`

---

### P08-智能可视化

**核心代码文件:**
- `app/lib/widgets/charts/optimized_charts.dart` - 优化图表
- `app/lib/widgets/interactive_trend_chart.dart` - 交互趋势图
- `app/lib/widgets/interactive_pie_chart.dart` - 交互饼图
- `app/lib/widgets/location_spending_heatmap.dart` - 位置消费热力图
- `app/lib/services/chart_capture_service.dart` - 图表截图

**UI页面:**
- `app/lib/pages/statistics_page.dart`
- `app/lib/pages/analysis_center_page.dart`

---

### P09-财务健康评分

**核心代码文件:**
- `app/lib/services/financial_health_score_service.dart` - 财务健康评分
- `app/lib/services/debt_health_service.dart` - 债务健康

**UI页面:**
- `app/lib/pages/financial_health_dashboard_page.dart`

**待验证数据:**
- [ ] 评分算法的具体公式
- [ ] 评分维度和权重

---

### P10-账单解析导入

**核心代码文件:**
- `app/lib/services/import/bill_parser.dart` - 通用账单解析
- `app/lib/services/import/bill_format_detector.dart` - 账单格式检测
- `app/lib/services/import/alipay_bill_parser.dart` - 支付宝账单
- `app/lib/services/import/wechat_bill_parser.dart` - 微信账单
- `app/lib/services/import/generic_bank_parser.dart` - 通用银行账单
- `app/lib/services/learning/ocr_learning_service.dart` - OCR自学习

**UI页面:**
- `app/lib/pages/import/smart_import_page.dart`
- `app/lib/pages/image_recognition_page.dart`

---

### P11-离线增量同步

**核心代码文件:**
- `app/lib/services/crdt_sync_service.dart` - CRDT同步
- `app/lib/services/sync_service.dart` - 通用同步
- `app/lib/services/realtime_data_sync_service.dart` - 实时同步
- `app/lib/services/family_offline_sync_service.dart` - 家庭离线同步
- `app/lib/services/offline_queue_service.dart` - 离线队列

**UI页面:**
- `app/lib/pages/sync_settings_page.dart`

---

### P12-游戏化激励

**核心代码文件:**
- `app/lib/services/gamification_service.dart` - 游戏化服务
- `app/lib/services/goal_achievement_service.dart` - 目标成就
- `app/lib/models/achievement.dart` - 成就模型

**UI页面:**
- `app/lib/pages/goal_achievement_dashboard_page.dart`
- `app/lib/pages/growth/achievement_share_page.dart`

---

### P13-家庭协作记账

**核心代码文件:**
- `app/lib/services/family_budget_service.dart` - 家庭预算
- `app/lib/services/family_dashboard_service.dart` - 家庭仪表板
- `app/lib/services/family_report_service.dart` - 家庭报告
- `app/lib/services/family_leaderboard_service.dart` - 家庭排行榜
- `app/lib/services/family_savings_goal_service.dart` - 家庭储蓄目标

**UI页面:**
- `app/lib/pages/family_leaderboard_page.dart`
- `app/lib/pages/family_savings_goal_page.dart`
- `app/lib/pages/member_comparison_page.dart`

---

### P14-冷静期控制

**核心代码文件:**
- `app/lib/services/cooling_off_service.dart` - 冷静期服务
- `app/lib/services/impulse_spending_interceptor.dart` - 冲动消费拦截

---

### P15-可变收入适配

**核心代码文件:**
- `app/lib/services/variable_income_adapter.dart` - 可变收入适配器

---

### P16-订阅追踪检测

**核心代码文件:**
- `app/lib/services/subscription_tracking_service.dart` - 订阅追踪

**UI页面:**
- `app/lib/pages/subscription_waste_page.dart`
- `app/lib/pages/recurring_management_page.dart`

---

### P17-债务健康管理

**核心代码文件:**
- `app/lib/services/debt_health_service.dart` - 债务健康
- `app/lib/services/allocation_service.dart` - 分配服务
- `app/lib/models/debt.dart` - 债务模型

**UI页面:**
- `app/lib/pages/debt_management_page.dart`
- `app/lib/pages/debt_simulator_page.dart`

---

### P18-消费趋势预测

**核心代码文件:**
- `app/lib/services/trend_prediction_service.dart` - 趋势预测
- `app/lib/services/latte_factor_analyzer.dart` - 拿铁因子分析
- `app/lib/services/spending_planning_service.dart` - 消费规划
- `app/lib/services/anomaly_detection_service.dart` - 异常检测

**UI页面:**
- `app/lib/pages/ai/spending_prediction_page.dart`
- `app/lib/pages/trends_page.dart`

---

## 风险标记

### 高风险项 🔴

| 专利 | 问题 | 建议 |
|------|------|------|
| P03 | 声称"差分隐私"但代码实现的是数据脱敏 | 修改专利名称或补充实现 |

### 中风险项 🟡

| 专利 | 问题 | 建议 |
|------|------|------|
| P01 | 性能数据无测试依据 | 补充性能测试或删除数据 |
| P05 | 准确率数据无测试依据 | 补充测试或改为定性描述 |

### 待验证项 🟠

所有专利中的具体性能数据、准确率数据、对比数据需要进一步核查。
