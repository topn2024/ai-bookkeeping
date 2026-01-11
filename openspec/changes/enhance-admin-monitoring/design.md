# 设计文档：增强管理控制台监控能力

## 概述
本文档描述增强管理控制台监控能力的技术设计，包括架构决策、数据模型、API设计、前端界面设计和实施策略。

## 架构设计

### 整体架构

```
┌─────────────────────────────────────────────────────────────┐
│                    移动端 (Flutter App)                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ 千人千面功能  │  │ 数据分析功能  │  │  其他功能     │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
│         │ 埋点             │ 埋点             │ 埋点         │
└─────────┼──────────────────┼──────────────────┼─────────────┘
          │                  │                  │
          ▼                  ▼                  ▼
┌─────────────────────────────────────────────────────────────┐
│                    后端服务 (FastAPI)                        │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              事件收集API (/api/v1/events)             │  │
│  │  - 异步接收埋点数据                                   │  │
│  │  - 数据验证和清洗                                     │  │
│  │  - 写入Redis队列                                      │  │
│  └────────────────────────┬─────────────────────────────┘  │
│                           │                                 │
│  ┌────────────────────────▼─────────────────────────────┐  │
│  │            Celery后台任务 (事件处理器)                │  │
│  │  - 批量消费Redis队列                                  │  │
│  │  - 数据聚合和统计                                     │  │
│  │  - 写入PostgreSQL                                     │  │
│  │  - 数据质量检查                                       │  │
│  │  - 告警触发                                           │  │
│  └────────────────────────┬─────────────────────────────┘  │
│                           │                                 │
│  ┌────────────────────────▼─────────────────────────────┐  │
│  │          管理监控API (/admin/monitoring/*)            │  │
│  │  - 千人千面监控                                       │  │
│  │  - 数据质量监控                                       │  │
│  │  - 分析功能监控                                       │  │
│  │  - AI成本监控                                         │  │
│  └────────────────────────┬─────────────────────────────┘  │
└───────────────────────────┼───────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              管理控制台前端 (Vue 3 + Element Plus)           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │千人千面监控页 │  │数据质量监控页 │  │ AI成本监控页  │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│  ┌──────────────┐  ┌──────────────┐                        │
│  │分析功能监控页 │  │  告警管理页   │                        │
│  └──────────────┘  └──────────────┘                        │
└─────────────────────────────────────────────────────────────┘
```

### 数据流

1. **事件收集流程**
   ```
   移动端 → 埋点 → HTTP POST → 事件收集API → Redis队列 → Celery任务 → PostgreSQL
   ```

2. **数据查询流程**
   ```
   管理前端 → HTTP GET → 监控API → PostgreSQL/Redis → 返回数据 → 图表展示
   ```

3. **告警流程**
   ```
   Celery任务 → 数据检查 → 触发告警 → 告警表 → 通知服务 → Email/SMS/Webhook
   ```

## 数据模型设计

### 新增数据表

#### 1. personalized_content_events（千人千面事件表）
记录千人千面功能的使用事件

```sql
CREATE TABLE personalized_content_events (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL,
    event_type VARCHAR(50) NOT NULL,  -- 'view', 'refresh', 'interact'
    content_type VARCHAR(50) NOT NULL, -- 'greeting', 'balance_growth', 'streak', 'money_age'
    content_variant VARCHAR(100),      -- 具体文案的变体标识
    seed_value VARCHAR(200),           -- 生成种子（用于追溯）
    session_id VARCHAR(100),
    timestamp TIMESTAMP NOT NULL DEFAULT NOW(),
    metadata JSONB,                    -- 额外信息（如用户反馈、停留时间等）

    INDEX idx_user_id (user_id),
    INDEX idx_event_type (event_type),
    INDEX idx_timestamp (timestamp),
    INDEX idx_content_type (content_type)
);
```

#### 2. personalized_content_stats（千人千面统计表）
聚合统计数据，按小时/天聚合

```sql
CREATE TABLE personalized_content_stats (
    id BIGSERIAL PRIMARY KEY,
    period_start TIMESTAMP NOT NULL,
    period_end TIMESTAMP NOT NULL,
    granularity VARCHAR(20) NOT NULL,  -- 'hourly', 'daily'
    content_type VARCHAR(50) NOT NULL,
    total_views INT NOT NULL DEFAULT 0,
    total_refreshes INT NOT NULL DEFAULT 0,
    unique_users INT NOT NULL DEFAULT 0,
    avg_session_duration FLOAT,        -- 平均停留时间（秒）
    variant_distribution JSONB,        -- 各变体的分布

    UNIQUE (period_start, granularity, content_type),
    INDEX idx_period (period_start, period_end),
    INDEX idx_content_type (content_type)
);
```

#### 3. data_quality_checks（数据质量检查记录表）

```sql
CREATE TABLE data_quality_checks (
    id BIGSERIAL PRIMARY KEY,
    check_time TIMESTAMP NOT NULL DEFAULT NOW(),
    check_type VARCHAR(50) NOT NULL,   -- 'null_check', 'range_check', 'consistency_check'
    target_table VARCHAR(100) NOT NULL,
    target_column VARCHAR(100),
    severity VARCHAR(20) NOT NULL,     -- 'low', 'medium', 'high', 'critical'

    -- 检查结果
    total_records INT NOT NULL,
    affected_records INT NOT NULL,
    issue_details JSONB,               -- 具体问题详情

    -- 状态
    status VARCHAR(20) NOT NULL DEFAULT 'detected', -- 'detected', 'investigating', 'fixed', 'ignored'
    assigned_to VARCHAR(100),
    resolved_at TIMESTAMP,
    resolution_notes TEXT,

    INDEX idx_check_time (check_time),
    INDEX idx_status (status),
    INDEX idx_severity (severity)
);
```

#### 4. analysis_feature_usage（分析功能使用统计表）

```sql
CREATE TABLE analysis_feature_usage (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL,
    feature_name VARCHAR(100) NOT NULL, -- 'trend_analysis', 'category_pie', 'comparison', etc.
    feature_params JSONB,               -- 功能参数（如时间范围、分类等）

    -- 性能指标
    query_time_ms INT NOT NULL,         -- 查询耗时（毫秒）
    data_points INT,                    -- 数据点数量
    result_size_kb INT,                 -- 结果大小（KB）

    -- 时间信息
    accessed_at TIMESTAMP NOT NULL DEFAULT NOW(),
    session_id VARCHAR(100),

    INDEX idx_user_id (user_id),
    INDEX idx_feature_name (feature_name),
    INDEX idx_accessed_at (accessed_at),
    INDEX idx_query_time (query_time_ms)
);
```

#### 5. ai_service_costs（AI服务成本记录表）
扩展现有AI监控，增加成本维度

```sql
CREATE TABLE ai_service_costs (
    id BIGSERIAL PRIMARY KEY,
    service_name VARCHAR(50) NOT NULL,  -- 'qwen', 'glm'
    feature_name VARCHAR(100) NOT NULL, -- 功能名称
    call_type VARCHAR(50) NOT NULL,     -- 'text', 'ocr', 'voice', 'embedding'

    -- 调用统计
    total_calls INT NOT NULL DEFAULT 0,
    successful_calls INT NOT NULL DEFAULT 0,
    failed_calls INT NOT NULL DEFAULT 0,

    -- Token统计
    total_tokens INT NOT NULL DEFAULT 0,
    prompt_tokens INT NOT NULL DEFAULT 0,
    completion_tokens INT NOT NULL DEFAULT 0,

    -- 成本统计（单位：元）
    estimated_cost DECIMAL(10, 4) NOT NULL DEFAULT 0,

    -- 时间统计
    avg_latency_ms INT,
    period_start TIMESTAMP NOT NULL,
    period_end TIMESTAMP NOT NULL,
    granularity VARCHAR(20) NOT NULL,   -- 'hourly', 'daily'

    UNIQUE (period_start, granularity, service_name, feature_name, call_type),
    INDEX idx_period (period_start, period_end),
    INDEX idx_feature (feature_name)
);
```

### 数据保留策略

- **原始事件数据**：保留30天后归档到对象存储
- **聚合统计数据**：
  - 小时级数据：保留90天
  - 天级数据：保留1年
  - 月级数据：永久保留
- **数据质量检查记录**：已解决的保留90天，未解决的永久保留
- **分析功能使用记录**：保留30天详细数据，保留90天聚合数据

## API设计

### 1. 事件收集API

#### POST /api/v1/events/batch
批量上传事件数据（移动端调用）

**请求**：
```json
{
  "events": [
    {
      "type": "personalized_content_view",
      "userId": "uuid",
      "data": {
        "contentType": "greeting",
        "contentVariant": "early_morning_1",
        "seedValue": "user123_20260111_08_greeting",
        "sessionId": "session_abc"
      },
      "timestamp": "2026-01-11T08:00:00Z"
    },
    {
      "type": "analysis_feature_usage",
      "userId": "uuid",
      "data": {
        "featureName": "trend_analysis",
        "queryTimeMs": 156,
        "dataPoints": 30
      },
      "timestamp": "2026-01-11T08:05:00Z"
    }
  ]
}
```

**响应**：
```json
{
  "success": true,
  "accepted": 2,
  "rejected": 0,
  "message": "Events queued for processing"
}
```

### 2. 千人千面监控API

#### GET /admin/monitoring/personalized-content/overview
获取千人千面功能概览

**查询参数**：
- `startDate`: 开始日期
- `endDate`: 结束日期
- `granularity`: 粒度（hourly/daily）

**响应**：
```json
{
  "summary": {
    "totalViews": 125000,
    "totalRefreshes": 45000,
    "uniqueUsers": 8500,
    "avgViewsPerUser": 14.7,
    "avgRefreshRate": 0.36
  },
  "byContentType": {
    "greeting": {
      "views": 50000,
      "uniqueUsers": 8000,
      "topVariants": [
        {"variant": "early_morning_1", "count": 12000, "percentage": 24},
        {"variant": "early_morning_2", "count": 10000, "percentage": 20}
      ]
    },
    "balance_growth": {...},
    "streak": {...},
    "money_age": {...}
  },
  "timeSeries": [
    {
      "timestamp": "2026-01-11T00:00:00Z",
      "views": 5200,
      "refreshes": 1800,
      "uniqueUsers": 450
    }
  ]
}
```

#### GET /admin/monitoring/personalized-content/variants
获取文案变体表现

**响应**：
```json
{
  "contentType": "greeting",
  "variants": [
    {
      "variant": "early_morning_1",
      "viewCount": 12000,
      "avgSessionDuration": 5.2,
      "interactionRate": 0.15,
      "userFeedback": {
        "positive": 180,
        "negative": 15
      }
    }
  ]
}
```

### 3. 数据质量监控API

#### GET /admin/monitoring/data-quality/overview
获取数据质量概览

**响应**：
```json
{
  "overallScore": 95.8,
  "recentIssues": {
    "critical": 2,
    "high": 5,
    "medium": 12,
    "low": 30
  },
  "byTable": {
    "transactions": {
      "score": 98.5,
      "totalRecords": 1500000,
      "issueCount": 15
    },
    "categories": {...}
  },
  "recentChecks": [
    {
      "checkTime": "2026-01-11T08:00:00Z",
      "checkType": "null_check",
      "targetTable": "transactions",
      "targetColumn": "amount",
      "severity": "high",
      "affectedRecords": 5,
      "status": "investigating"
    }
  ]
}
```

#### GET /admin/monitoring/data-quality/checks
获取数据质量检查列表

**查询参数**：
- `severity`: 严重程度筛选
- `status`: 状态筛选
- `startDate`, `endDate`: 时间范围
- `page`, `pageSize`: 分页

#### POST /admin/monitoring/data-quality/checks/{checkId}/resolve
标记问题已解决

### 4. 分析功能监控API

#### GET /admin/monitoring/analysis-features/overview
获取分析功能使用概览

**响应**：
```json
{
  "summary": {
    "totalUsage": 85000,
    "uniqueUsers": 6500,
    "avgQueryTime": 245,
    "p95QueryTime": 850,
    "p99QueryTime": 1500
  },
  "byFeature": {
    "trend_analysis": {
      "usageCount": 25000,
      "uniqueUsers": 5000,
      "avgQueryTime": 180,
      "popularParams": [
        {"params": {"period": "month"}, "count": 15000}
      ]
    },
    "category_pie": {...}
  },
  "slowQueries": [
    {
      "feature": "trend_analysis",
      "queryTime": 2500,
      "dataPoints": 365,
      "userId": "uuid",
      "timestamp": "2026-01-11T08:00:00Z"
    }
  ]
}
```

### 5. AI成本监控API

#### GET /admin/monitoring/ai-costs/overview
获取AI成本概览

**响应**：
```json
{
  "summary": {
    "totalCost": 2850.50,
    "totalCalls": 125000,
    "avgCostPerCall": 0.0228,
    "period": {
      "start": "2026-01-01T00:00:00Z",
      "end": "2026-01-11T23:59:59Z"
    }
  },
  "byService": {
    "qwen": {
      "cost": 2100.30,
      "calls": 95000,
      "tokens": 15000000
    },
    "glm": {...}
  },
  "byFeature": {
    "ocr_recognition": {
      "cost": 1200.00,
      "calls": 45000,
      "avgCostPerCall": 0.0267
    },
    "text_parsing": {...},
    "personalized_content": {
      "cost": 0,
      "calls": 0,
      "note": "客户端本地生成，无AI调用"
    }
  },
  "costTrend": [
    {
      "date": "2026-01-01",
      "cost": 250.50,
      "calls": 11000
    }
  ],
  "optimizationSuggestions": [
    {
      "type": "caching",
      "description": "OCR识别重复率高达15%，建议增加缓存",
      "estimatedSavings": 180.00
    }
  ]
}
```

## 前端界面设计

### 1. 千人千面监控页面（PersonalizedContent.vue）

**布局**：
```
┌─────────────────────────────────────────────────────┐
│ 千人千面监控                        [日期选择器]     │
├─────────────────────────────────────────────────────┤
│ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐   │
│ │总浏览量  │ │刷新次数  │ │活跃用户  │ │刷新率   │   │
│ │ 125K    │ │ 45K     │ │ 8.5K    │ │ 36%    │   │
│ └─────────┘ └─────────┘ └─────────┘ └─────────┘   │
├─────────────────────────────────────────────────────┤
│ 使用趋势图表（折线图）                              │
│ ┌───────────────────────────────────────────────┐ │
│ │                                               │ │
│ │   [折线图：浏览量、刷新次数、活跃用户趋势]       │ │
│ │                                               │ │
│ └───────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────┤
│ 内容类型分布（标签页）                              │
│ [问候语] [结余趋势] [连续记账] [钱龄趋势]           │
│ ┌───────────────────────────────────────────────┐ │
│ │ 文案变体表现（表格）                           │ │
│ │ ┌────────┬────────┬──────────┬────────────┐ │ │
│ │ │ 变体   │ 浏览量  │ 停留时间  │ 交互率      │ │ │
│ │ ├────────┼────────┼──────────┼────────────┤ │ │
│ │ │ 早安1  │ 12K    │ 5.2s     │ 15%        │ │ │
│ │ │ 早安2  │ 10K    │ 4.8s     │ 12%        │ │ │
│ │ └────────┴────────┴──────────┴────────────┘ │ │
│ └───────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────┘
```

**关键组件**：
- 统计卡片（ElCard + ElStatistic）
- 趋势图表（ECharts折线图）
- 标签页（ElTabs）
- 数据表格（ElTable）

### 2. 数据质量监控页面（DataQuality.vue）

**布局**：
```
┌─────────────────────────────────────────────────────┐
│ 数据质量监控              [筛选] [刷新] [导出]       │
├─────────────────────────────────────────────────────┤
│ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐   │
│ │综合评分  │ │严重问题  │ │待处理   │ │已解决   │   │
│ │ 95.8    │ │ 2       │ │ 17      │ │ 32     │   │
│ │ [优秀]  │ │ [高]    │ │         │ │        │   │
│ └─────────┘ └─────────┘ └─────────┘ └─────────┘   │
├─────────────────────────────────────────────────────┤
│ 数据表质量评分（横向柱状图）                        │
│ transactions  ████████████████████████ 98.5       │
│ categories    █████████████████████████ 99.2      │
│ accounts      ██████████████████████ 96.8         │
├─────────────────────────────────────────────────────┤
│ 问题列表                                           │
│ ┌───────────────────────────────────────────────┐ │
│ │ 🔴 Critical | transactions.amount | 5条空值   │ │
│ │ 🟠 High     | categories.name | 15条异常字符  │ │
│ │ 🟡 Medium   | accounts.balance | 不一致      │ │
│ │ [查看详情] [标记已解决]                        │ │
│ └───────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────┘
```

### 3. AI成本监控页面（AICosts.vue）

**布局**：
```
┌─────────────────────────────────────────────────────┐
│ AI成本管理                          [月份选择器]     │
├─────────────────────────────────────────────────────┤
│ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐   │
│ │总成本    │ │调用次数  │ │平均成本  │ │节省建议  │   │
│ │ ¥2,850  │ │ 125K    │ │¥0.0228  │ │ 3条     │   │
│ └─────────┘ └─────────┘ └─────────┘ └─────────┘   │
├─────────────────────────────────────────────────────┤
│ 成本趋势（面积图）                                  │
│ ┌───────────────────────────────────────────────┐ │
│ │ [Qwen] [GLM] [总计]                           │ │
│ │                                               │ │
│ └───────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────┤
│ 功能成本分布（饼图 + 表格）                         │
│ ┌──────────┬──────────┬──────────┬──────────┐   │
│ │ 功能     │ 调用次数  │ 成本     │ 占比     │   │
│ ├──────────┼──────────┼──────────┼──────────┤   │
│ │ OCR识别  │ 45K      │ ¥1,200  │ 42%      │   │
│ │ 文本解析  │ 35K      │ ¥950    │ 33%      │   │
│ │ 语音识别  │ 25K      │ ¥700    │ 25%      │   │
│ └──────────┴──────────┴──────────┴──────────┘   │
├─────────────────────────────────────────────────────┤
│ 优化建议                                           │
│ 💡 OCR识别重复率高，建议增加缓存（预计节省¥180）   │
│ 💡 文本解析可考虑批量处理（预计节省¥95）           │
└─────────────────────────────────────────────────────┘
```

## 技术决策

### 1. 为什么使用Redis队列 + Celery？

**决策**：使用Redis作为事件队列，Celery作为异步处理器

**理由**：
- **性能**：移动端埋点不能阻塞主流程，异步写入可以立即返回
- **可靠性**：Redis队列提供持久化，防止数据丢失
- **可扩展**：Celery支持分布式部署，可根据负载扩展worker数量
- **批量处理**：可以批量消费和写入数据库，减少数据库压力

**替代方案**：
- 直接写入数据库：性能差，影响主业务
- Kafka：过于重量级，成本高

### 2. 为什么区分原始事件表和聚合统计表？

**决策**：原始事件表（如personalized_content_events）+ 聚合统计表（如personalized_content_stats）

**理由**：
- **查询性能**：聚合表预计算好统计数据，查询速度快
- **数据保留**：原始数据可定期归档，聚合数据长期保留
- **灵活性**：原始数据支持多维度重新聚合
- **成本**：聚合表大小远小于原始数据，存储成本低

### 3. 为什么AI成本监控单独设表？

**决策**：独立的ai_service_costs表，而不是复用现有监控表

**理由**：
- **数据结构不同**：成本数据需要token和金额字段
- **查询模式不同**：成本分析需要按功能、时间段聚合
- **保留策略不同**：成本数据需要长期保留用于趋势分析
- **扩展性**：未来可能接入更多AI服务，需要灵活的schema

### 4. 数据质量检查为什么不实时？

**决策**：定时批量检查（每小时），而不是实时检查每条写入

**理由**：
- **性能**：实时检查会严重影响写入性能
- **必要性**：数据质量问题不需要毫秒级响应
- **成本**：批量检查可以优化查询，降低数据库负载
- **准确性**：某些检查（如一致性）需要全表扫描，不适合实时

**例外情况**：
- 关键字段（如amount）可以在应用层做基本验证
- 触发式检查：用户报告问题时可立即检查

## 性能优化

### 1. 数据库索引策略

- **时间字段**：所有timestamp字段都建索引，支持时间范围查询
- **关联字段**：user_id, feature_name等高频查询字段建索引
- **复合索引**：(period_start, granularity, content_type)用于聚合查询
- **分区表**：事件表按月分区，提高查询和归档效率

### 2. 缓存策略

- **Redis缓存**：
  - 概览数据缓存5分钟（高频访问）
  - 聚合统计缓存1小时（变化较慢）
  - 榜单数据缓存15分钟

- **缓存失效**：
  - 定时失效（TTL）
  - 数据更新时主动失效（Celery任务完成后）

### 3. 查询优化

- **分页**：所有列表接口强制分页，默认20条/页
- **只查必要字段**：避免SELECT *
- **预聚合**：复杂统计提前聚合，避免实时计算
- **异步导出**：大数据量导出改为后台任务

### 4. 前端优化

- **虚拟滚动**：长列表使用虚拟滚动（ElTableV2）
- **图表懒加载**：tab切换时才加载图表
- **防抖节流**：搜索、筛选使用防抖
- **数据缓存**：Pinia中缓存接口数据

## 安全考虑

### 1. 权限控制

- 所有监控API需要管理员权限
- 细粒度权限：
  - `monitor:personalized_content:view` - 查看千人千面监控
  - `monitor:data_quality:view` - 查看数据质量
  - `monitor:data_quality:manage` - 管理数据质量问题
  - `monitor:ai_costs:view` - 查看AI成本

### 2. 数据脱敏

- 个人用户ID在前端显示时脱敏（显示前8位）
- 导出数据时可选择是否包含敏感信息

### 3. 审计日志

- 所有数据质量问题的标记/解决操作记录审计日志
- API访问记录（已有功能）

## 告警规则

### 1. 数据质量告警

| 规则 | 阈值 | 严重程度 | 通知方式 |
|------|------|----------|----------|
| 空值率 > X% | 5% | High | Email + SMS |
| 异常值数量 | >100条 | Medium | Email |
| 数据不一致 | 任何 | High | Email + SMS |
| 检查失败 | 连续3次 | Critical | Email + SMS + Webhook |

### 2. 性能告警

| 规则 | 阈值 | 严重程度 | 通知方式 |
|------|------|----------|----------|
| API P95响应时间 | >2s | Medium | Email |
| API P99响应时间 | >5s | High | Email + SMS |
| 慢查询数量 | >10/小时 | Medium | Email |
| 数据库连接池占用 | >80% | High | Email + SMS |

### 3. 成本告警

| 规则 | 阈值 | 严重程度 | 通知方式 |
|------|------|----------|----------|
| 日成本同比增长 | >30% | Medium | Email |
| 日成本同比增长 | >50% | High | Email + SMS |
| 单次调用成本异常 | >¥1 | High | Email |
| 月度预算超支 | >预算 | Critical | Email + SMS |

## 实施阶段

### 阶段1：数据质量监控（优先级：Critical）
**工作量**：2-3周

1. 创建数据库表（data_quality_checks）
2. 实现数据质量检查Celery任务
3. 实现后端API（/admin/monitoring/data-quality/*）
4. 实现前端页面（DataQuality.vue）
5. 配置告警规则
6. 测试和上线

**交付物**：
- 数据质量监控页面
- 自动化数据检查
- 告警通知

### 阶段2：千人千面监控（优先级：High）
**工作量**：2周

1. 创建数据库表（personalized_content_events, stats）
2. 移动端埋点集成
3. 实现事件收集API和Celery任务
4. 实现后端监控API
5. 实现前端页面（PersonalizedContent.vue）
6. 测试和上线

### 阶段3：分析功能监控（优先级：Medium）
**工作量**：1.5周

1. 创建数据库表（analysis_feature_usage）
2. 移动端埋点集成
3. 实现后端API
4. 实现前端页面（AnalysisFeatures.vue）
5. 性能分析和优化建议功能
6. 测试和上线

### 阶段4：AI成本监控（优先级：Medium）
**工作量**：1.5周

1. 创建数据库表（ai_service_costs）
2. 扩展现有AI服务调用记录
3. 实现成本计算和聚合
4. 实现后端API
5. 实现前端页面（AICosts.vue）
6. 优化建议算法
7. 测试和上线

## 测试策略

### 1. 单元测试
- 数据质量检查逻辑
- 成本计算逻辑
- API业务逻辑

### 2. 集成测试
- 事件收集 → 队列 → 处理 → 存储流程
- API端到端测试

### 3. 性能测试
- 埋点API压力测试（>1000 QPS）
- 监控查询性能测试
- 数据库查询性能测试

### 4. 用户验收测试
- 管理员验证监控数据准确性
- 告警功能验证
- 前端交互验证

## 运维和监控

### 1. 监控监控系统本身
- Celery任务队列长度告警
- 事件处理延迟监控
- 数据聚合任务失败告警

### 2. 数据归档
- 定期归档原始事件数据到对象存储
- 保留最近30天热数据在数据库

### 3. 备份策略
- 监控数据库每日备份
- 关键配置（告警规则）版本控制

## 风险缓解

| 风险 | 可能性 | 影响 | 缓解措施 |
|------|--------|------|----------|
| 埋点数据量过大 | 中 | 高 | Redis队列 + 批量处理 + 数据保留策略 |
| 查询性能下降 | 中 | 中 | 索引优化 + 缓存 + 预聚合 |
| 告警过多骚扰 | 高 | 低 | 告警阈值优化 + 聚合通知 |
| 开发延期 | 中 | 中 | 分阶段实施 + 优先级管理 |
| 数据隐私泄露 | 低 | 高 | 权限控制 + 数据脱敏 + 审计 |

## 未来扩展

1. **机器学习集成**
   - 异常检测模型（自动识别数据异常）
   - 成本预测模型
   - 用户行为预测

2. **更丰富的可视化**
   - 热力图
   - 桑基图（用户路径）
   - 自定义仪表盘

3. **自动化优化**
   - 自动调整缓存策略
   - 自动优化慢查询
   - 自动化成本优化建议

4. **实时监控**
   - WebSocket实时数据推送
   - 实时告警弹窗

5. **跨平台支持**
   - Web端埋点
   - 后台管理操作埋点
