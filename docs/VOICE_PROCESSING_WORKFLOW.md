# 语音处理工作流程

## 概述

AI记账应用支持多种语音记账方式，本文档详细说明从语音输入到生成交易记录的完整工作流程。

## 系统架构

```
┌─────────────┐
│  移动端APP  │
└──────┬──────┘
       │
       ├──────────────┐
       │              │
       v              v
┌──────────────┐  ┌──────────────┐
│ 客户端语音识别│  │ 服务端音频识别│
│  (阿里云ASR)  │  │(Qwen-Omni)    │
└──────┬───────┘  └──────┬───────┘
       │                 │
       └────────┬────────┘
                │
                v
        ┌───────────────┐
        │  AI文本解析   │
        │  (Qwen/Zhipu) │
        └───────┬───────┘
                │
                v
        ┌───────────────┐
        │   交易记录    │
        └───────────────┘
```

## 方案对比

### 方案1: 客户端语音识别（推荐）

**优点**:
- 实时流式识别，用户体验好
- 支持离线语音识别（Picovoice）
- 降低服务器压力
- 识别速度快

**缺点**:
- 需要配置阿里云NLS服务
- 客户端集成复杂度高

### 方案2: 服务端音频识别

**优点**:
- 客户端实现简单
- 统一管理AI服务
- 便于监控和优化

**缺点**:
- 需要上传音频文件（增加流量）
- 识别延迟较高
- 服务器压力大

## 详细工作流程

### 流程1: 客户端语音识别（主要方案）

#### 第一步：获取语音服务Token

**客户端请求**:
```http
GET /api/v1/voice/token
Authorization: Bearer <user_token>
```

**服务端处理**:
1. 验证用户身份（app/api/v1/voice_token.py:186-208）
2. 检查Token缓存，如果缓存未过期直接返回
3. 向阿里云NLS Meta服务请求临时Token
   - API: `https://nls-meta.cn-shanghai.aliyuncs.com/`
   - 方法: CreateToken
   - 使用HMAC-SHA1签名认证

**缓存机制**:
```python
# Token缓存，预留5分钟刷新窗口
if datetime.utcnow() < expires_at - timedelta(minutes=5):
    return cached_token
```

**限流保护**:
- 失败后限流60秒，防止频繁请求
- 客户端建议每小时刷新一次Token

**响应数据**:
```json
{
  "token": "临时访问token",
  "expires_at": "2026-01-15T10:00:00Z",
  "app_key": "阿里云NLS AppKey",
  "asr_url": "wss://nls-gateway-cn-shanghai.aliyuncs.com/ws/v1",
  "asr_rest_url": "https://nls-gateway-cn-shanghai.aliyuncs.com/stream/v1/asr",
  "tts_url": "https://nls-gateway-cn-shanghai.aliyuncs.com/stream/v1/tts",
  "picovoice_access_key": "唤醒词检测密钥(可选)"
}
```

#### 第二步：客户端语音识别

**客户端实现**:
1. 使用获取的Token和AppKey初始化阿里云ASR SDK
2. 选择识别模式：
   - **实时流式识别**（推荐）：边说边显示
   - **一句话识别**：说完后识别
3. 可选：使用Picovoice实现唤醒词检测（如"嗨小白"）

**阿里云ASR配置**:
```javascript
// 示例配置
{
  appkey: "<从服务器获取>",
  token: "<从服务器获取>",
  url: "wss://nls-gateway-cn-shanghai.aliyuncs.com/ws/v1",
  format: "pcm",  // 音频格式
  sample_rate: 16000,  // 采样率
  enable_intermediate_result: true,  // 显示中间结果
  enable_punctuation_prediction: true,  // 自动添加标点
  enable_inverse_text_normalization: true  // 数字规范化
}
```

**识别结果示例**:
```
"今天在星巴克买咖啡花了38块钱"
```

#### 第三步：发送文本到服务器解析

**客户端请求**:
```http
POST /api/v1/ai/recognize-voice
Content-Type: application/x-www-form-urlencoded

text=今天在星巴克买咖啡花了38块钱
```

**服务端处理流程**:

1. **接收文本**（app/api/v1/ai.py:119-142）
   ```python
   @router.post("/recognize-voice")
   async def recognize_voice(
       text: str = Form(...),
       current_user: User = Depends(get_current_user),
   ):
   ```

2. **AI解析** - 主要使用Qwen（app/services/ai_service.py:181-222）

   **2.1 调用Qwen API**（主要方案）
   ```python
   # 构建prompt
   prompt = f"""请分析以下记账语音/文字，提取交易信息：

   "{text}"

   请提取：
   1. 金额（数字）
   2. 消费类型（餐饮/交通/购物/娱乐/住房/医疗/教育/工资/奖金/兼职/理财/其他）
   3. 是支出还是收入（expense/income）
   4. 备注描述

   请以JSON格式返回：
   {{
       "amount": 金额数字,
       "category": "消费类型",
       "type": "expense或income",
       "note": "备注"
   }}"""

   # 调用Qwen Plus模型
   response = await client.post(
       "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions",
       json={
           "model": "qwen-plus",
           "messages": [{"role": "user", "content": prompt}]
       }
   )
   ```

   **2.2 回退到Zhipu API**（备用方案）
   ```python
   # 如果Qwen失败，使用Zhipu GLM-4-Flash
   response = await client.post(
       "https://open.bigmodel.cn/api/paas/v4/chat/completions",
       json={
           "model": "glm-4-flash",
           "messages": [{"role": "user", "content": prompt}]
       }
   )
   ```

   **2.3 正则表达式解析**（最后备选）
   ```python
   # 提取金额
   amount_match = re.search(r'(\d+(?:\.\d{1,2})?)\s*(?:元|块|￥)?', text)

   # 检测收入关键词
   income_keywords = ["工资", "收入", "到账", "进账", "收到", "赚"]

   # 分类检测
   category_map = {
       "餐": "餐饮", "车": "交通", "买": "购物",
       "电影": "娱乐", "房租": "住房", ...
   }
   ```

3. **解析AI响应**（app/services/ai_service.py:334-356）
   ```python
   # 从AI响应中提取JSON
   json_match = re.search(r'\{[^{}]*\}', text, re.DOTALL)
   data = json.loads(json_match.group())

   result = {
       "amount": Decimal(str(data.get("amount"))),
       "category_name": data.get("category"),
       "category_type": 2 if data.get("type") == "income" else 1,
       "note": data.get("note"),
       "confidence": 0.85,
   }
   ```

**响应数据**:
```json
{
  "amount": 38.00,
  "category_name": "餐饮",
  "category_type": 1,
  "note": "今天在星巴克买咖啡",
  "merchant": "星巴克",
  "date": null,
  "confidence": 0.85,
  "raw_text": "AI原始响应"
}
```

#### 第四步：客户端创建交易记录

客户端收到解析结果后，可以：
1. 展示给用户确认/修改
2. 调用 `POST /api/v1/transactions` 创建交易记录

---

### 流程2: 服务端音频识别（备选方案）

#### 第一步：录制音频

客户端录制音频文件，支持格式：
- MP3（推荐）
- WAV
- AAC
- M4A
- OGG
- FLAC

**限制**:
- 最大文件大小：10MB
- 建议时长：< 60秒

#### 第二步：上传音频到服务器

**客户端请求**:
```http
POST /api/v1/ai/recognize-audio
Content-Type: multipart/form-data

file: <audio_file>
```

#### 第三步：服务端直接识别音频

**处理流程**（app/api/v1/ai.py:184-251）:

1. **验证文件**
   - 检查文件类型和扩展名
   - 验证文件大小（最大10MB）

2. **调用Qwen-Omni-Turbo识别**（app/services/ai_service.py:224-295）
   ```python
   # 编码音频为base64
   audio_base64 = base64.b64encode(audio_content).decode("utf-8")

   # 调用Qwen全模态模型
   response = await client.post(
       "https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation",
       json={
           "model": "qwen-omni-turbo",  # 支持音频理解的全模态模型
           "input": {
               "messages": [{
                   "role": "user",
                   "content": [
                       {"audio": f"data:audio/{audio_format};base64,{audio_base64}"},
                       {"text": prompt}
                   ]
               }]
           }
       }
   )
   ```

   **Prompt**:
   ```
   请分析这段语音，提取记账信息。

   请识别语音内容，并提取：
   1. 金额（数字）
   2. 消费类型
   3. 是支出还是收入
   4. 备注描述

   请以JSON格式返回：
   {
       "transcription": "语音转写文本",
       "amount": 金额数字,
       "category": "消费类型",
       "type": "expense或income",
       "note": "备注"
   }
   ```

3. **解析识别结果**（app/services/ai_service.py:297-318）
   - 提取语音转写文本
   - 提取交易信息
   - 计算置信度

**响应数据**:
```json
{
  "transcription": "今天在星巴克买咖啡花了38块钱",
  "amount": 38.00,
  "category_name": "餐饮",
  "category_type": 1,
  "note": "今天在星巴克买咖啡",
  "confidence": 0.9,
  "success": true,
  "error": null
}
```

---

## AI服务架构

### 服务选择策略

```
┌─────────────────┐
│   请求到达      │
└────────┬────────┘
         │
         v
┌─────────────────┐
│ 尝试 Qwen API   │
│   (通义千问)    │
└────────┬────────┘
         │
    成功? ├─Yes─> 返回结果
         │
        No
         │
         v
┌─────────────────┐
│ 尝试 Zhipu API  │
│   (智谱GLM)     │
└────────┬────────┘
         │
    成功? ├─Yes─> 返回结果
         │
        No
         │
         v
┌─────────────────┐
│  正则表达式解析 │
│   (规则匹配)    │
└────────┬────────┘
         │
         v
     返回结果
```

### Qwen API 配置

**模型选择**:
- **qwen-plus**: 文本解析（语音转文本后解析）
- **qwen-vl-plus**: 图像识别（识别小票/账单）
- **qwen-omni-turbo**: 音频直接识别（实验性）

**API Key配置**:
```python
# app/core/config.py
QWEN_API_KEY = os.getenv("QWEN_API_KEY")
```

**端点**:
- 文本API: `https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions`
- 多模态API: `https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation`

### Zhipu API 配置（备用）

**模型**: glm-4-flash

**API Key配置**:
```python
ZHIPU_API_KEY = os.getenv("ZHIPU_API_KEY")
```

**端点**:
- `https://open.bigmodel.cn/api/paas/v4/chat/completions`

---

## 分类系统

### 支出分类

| 分类 | 关键词 | category_type |
|------|--------|---------------|
| 餐饮 | 餐、饭、吃、外卖、咖啡 | 1 |
| 交通 | 车、地铁、公交、打车、滴滴 | 1 |
| 购物 | 买、购、淘宝、京东 | 1 |
| 娱乐 | 电影、游戏、KTV | 1 |
| 住房 | 房租、水电 | 1 |
| 医疗 | 医、药 | 1 |
| 教育 | 书、课 | 1 |
| 其他 | 默认分类 | 1 |

### 收入分类

| 分类 | 关键词 | category_type |
|------|--------|---------------|
| 工资 | 工资 | 2 |
| 奖金 | 奖金 | 2 |
| 兼职 | 兼职、外快 | 2 |
| 理财 | 理财、利息、分红 | 2 |
| 其他 | 默认分类 | 2 |

**检测逻辑**:
```python
income_keywords = ["工资", "收入", "到账", "进账", "收到", "赚"]
is_income = any(kw in text for kw in income_keywords)
category_type = 2 if is_income else 1
```

---

## 置信度评估

| 解析方式 | 置信度 | 说明 |
|----------|--------|------|
| Qwen AI解析 | 0.85 - 0.95 | AI成功解析并返回完整信息 |
| Zhipu AI解析 | 0.80 - 0.90 | 备用AI解析 |
| Qwen Audio识别 | 0.90 | 直接音频识别 |
| 正则表达式解析 | 0.60 | 简单规则匹配 |
| 无法解析 | null | 返回空结果 |

**置信度用途**:
- 低于0.7时建议用户确认
- 高于0.85可自动记账（需用户启用）
- 用于数据质量监控

---

## 错误处理

### 常见错误

1. **语音服务未配置**
   ```json
   {
     "status_code": 503,
     "detail": "语音服务未配置"
   }
   ```
   **解决方案**: 配置阿里云AccessKey和NLS AppKey

2. **Token获取失败**
   ```json
   {
     "status_code": 502,
     "detail": "阿里云服务请求失败"
   }
   ```
   **解决方案**: 检查网络、密钥是否正确、是否欠费

3. **请求过于频繁**
   ```json
   {
     "status_code": 429,
     "detail": "请求过于频繁，请稍后重试"
   }
   ```
   **解决方案**: 客户端缓存Token，每小时刷新

4. **音频文件过大**
   ```json
   {
     "status_code": 400,
     "detail": "Audio file too large. Max size: 10MB"
   }
   ```
   **解决方案**: 客户端压缩音频或使用流式识别

5. **AI解析失败**
   ```json
   {
     "amount": null,
     "confidence": 0.6,
     "note": "原始文本"
   }
   ```
   **解决方案**: 使用正则表达式兜底解析

### 重试策略

```python
# Token获取失败后限流
TokenCache.set_rate_limit(60)  # 60秒后重试

# AI API失败自动降级
try:
    result = await _call_qwen_text(prompt)
except:
    result = await _call_zhipu_text(prompt)
except:
    result = _simple_parse(text)
```

---

## 性能优化

### 1. Token缓存

```python
# 缓存Token，有效期1小时，预留5分钟刷新窗口
class TokenCache:
    _token: Optional[str] = None
    _expires_at: Optional[datetime] = None
```

**收益**: 减少99%的Token请求，降低延迟

### 2. 客户端识别

使用阿里云ASR在客户端识别，只传输文本到服务器。

**收益**:
- 节省音频传输流量（约90%）
- 识别延迟降低（<1秒 vs 3-5秒）
- 服务器负载降低

### 3. AI模型选择

| 场景 | 模型 | 响应时间 | 准确度 |
|------|------|----------|--------|
| 文本解析 | qwen-plus | ~1秒 | 高 |
| 图像识别 | qwen-vl-plus | ~2-3秒 | 高 |
| 音频识别 | qwen-omni-turbo | ~3-5秒 | 中 |
| 正则兜底 | 无 | <0.1秒 | 低 |

### 4. 超时控制

```python
# 文本解析超时
timeout=30.0

# 图像识别超时
timeout=30.0

# 音频识别超时
timeout=60.0

# 批量识别超时
timeout=60.0
```

---

## 日志和监控

### 日志记录

**关键节点日志**:

1. **语音识别开始**
   ```python
   logger.info(f"Voice text parsing started | user_id={user_id} | text_len={len(text)}")
   ```

2. **AI调用**
   ```python
   logger.warning(f"Qwen text parsing failed: {e}")
   logger.warning(f"Zhipu text parsing failed: {e}")
   ```

3. **识别完成**
   ```python
   logger.info(
       f"Voice text parsing completed | user_id={user_id} | "
       f"success={has_amount} | confidence={confidence} | "
       f"elapsed={elapsed:.2f}s"
   )
   ```

### 监控指标

建议监控：
- Token获取成功率
- AI API响应时间和成功率
- 各分类的识别准确率
- 平均置信度
- 用户修改率（间接反映准确度）

---

## 配置清单

### 必需配置

```bash
# .env文件

# Qwen AI (必需 - 用于文本和图像识别)
QWEN_API_KEY=sk-xxxxxxxxxxxx

# 阿里云NLS (可选 - 用于客户端语音识别)
ALIBABA_ACCESS_KEY_ID=LTAI5txxxxxxxxxxxx
ALIBABA_ACCESS_KEY_SECRET=xxxxxxxxxxxxxxxxxx
ALIBABA_NLS_APP_KEY=xxxxxxxxxxxxxxxxxx

# Zhipu AI (可选 - 作为备用)
ZHIPU_API_KEY=xxxxxxxxxxxxxxxxxxxx

# Picovoice (可选 - 用于唤醒词检测)
PICOVOICE_ACCESS_KEY=xxxxxxxxxxxxxxxxxxxx
```

### API端点

| 端点 | 方法 | 说明 | 权限 |
|------|------|------|------|
| `/api/v1/voice/token` | GET | 获取语音服务Token | 需要认证 |
| `/api/v1/voice/token/status` | GET | 检查语音服务状态 | 需要认证 |
| `/api/v1/ai/recognize-voice` | POST | 解析语音文本 | 需要认证 |
| `/api/v1/ai/recognize-audio` | POST | 识别音频文件 | 需要认证 |
| `/api/v1/ai/parse-text` | POST | 解析文本输入 | 需要认证 |

---

## 最佳实践

### 客户端开发建议

1. **Token管理**
   - 启动时获取Token并缓存
   - Token过期前5分钟刷新
   - 失败时重试，最多3次

2. **语音识别**
   - 优先使用流式识别（实时反馈）
   - 支持离线识别作为备选（Picovoice）
   - 显示中间结果提升体验

3. **用户体验**
   - 识别完成后显示结果供用户确认
   - 提供修改按钮（金额、分类、备注）
   - 低置信度结果提示用户检查
   - 支持撤销功能

4. **错误处理**
   - 网络错误时提示用户
   - 识别失败时允许手动输入
   - 记录用户修改用于改进模型

### 服务端开发建议

1. **降级策略**
   - Qwen -> Zhipu -> 正则表达式
   - 确保任何情况下都有返回

2. **成本控制**
   - 使用Token缓存减少请求
   - 优先客户端识别方案
   - 监控API调用量和费用

3. **质量监控**
   - 记录所有AI调用和结果
   - 统计各分类的准确率
   - 收集用户修改数据

4. **安全考虑**
   - API Key保存在服务端
   - Token代理模式避免密钥泄露
   - 限流防止滥用

---

## 未来优化方向

### 短期优化（1-3个月）

1. **智能分类优化**
   - 基于用户历史记录智能推荐分类
   - 学习用户的商户-分类映射
   - 支持自定义分类和关键词

2. **多轮对话**
   - 信息不完整时追问用户
   - 支持修正和补充
   - 上下文理解（"还有一笔"）

3. **语音优化**
   - 支持方言识别
   - 降噪处理
   - 语速自适应

### 中期优化（3-6个月）

1. **本地AI模型**
   - 部署轻量级本地模型
   - 减少API依赖和成本
   - 提升响应速度

2. **批量识别**
   - 识别账单截图中的多条交易
   - 自动拆分和分类
   - 智能去重

3. **主动提醒**
   - 识别定期支出（房租、订阅）
   - 异常消费提醒
   - 预算超支提醒

### 长期优化（6-12个月）

1. **智能助手**
   - 对话式记账
   - 财务建议
   - 消费分析

2. **多模态融合**
   - 语音 + 图像识别
   - 位置信息辅助分类
   - 日历事件关联

3. **模型微调**
   - 基于用户数据微调分类模型
   - 个性化识别引擎
   - 持续学习优化

---

## 相关文档

- [阿里云NLS文档](https://help.aliyun.com/product/30413.html)
- [Qwen API文档](https://help.aliyun.com/zh/dashscope/)
- [Zhipu API文档](https://open.bigmodel.cn/dev/api)
- [Picovoice文档](https://picovoice.ai/docs/)

## 代码位置

| 功能 | 文件路径 |
|------|----------|
| Token管理 | `server/app/api/v1/voice_token.py` |
| AI识别API | `server/app/api/v1/ai.py` |
| AI服务 | `server/app/services/ai_service.py` |
| 配置 | `server/app/core/config.py` |

---

**文档版本**: 1.0
**最后更新**: 2026-01-15
**维护者**: AI记账开发团队
