# 语音处理流程图

本文档使用Mermaid语法提供可视化的流程图。您可以在支持Mermaid的Markdown查看器中查看这些图表。

## 1. 系统架构总览

```mermaid
graph TB
    A[移动端APP] --> B{语音识别方案}
    B -->|方案1| C[客户端ASR识别]
    B -->|方案2| D[服务端音频识别]

    C --> E[获取阿里云Token]
    C --> F[阿里云ASR实时识别]
    F --> G[语音转文本]

    D --> H[上传音频文件]
    H --> I[Qwen-Omni识别]
    I --> G

    G --> J[AI文本解析]
    J --> K[Qwen文本解析]
    J --> L[Zhipu备用解析]
    J --> M[正则表达式兜底]

    K --> N[交易信息提取]
    L --> N
    M --> N

    N --> O[返回结构化数据]
    O --> P[用户确认/修改]
    P --> Q[创建交易记录]

    style A fill:#e1f5ff
    style J fill:#fff4e6
    style N fill:#e8f5e9
    style Q fill:#f3e5f5
```

## 2. 方案1：客户端语音识别流程

```mermaid
sequenceDiagram
    participant U as 用户
    participant C as 客户端APP
    participant S as 后端服务器
    participant A as 阿里云NLS
    participant Q as Qwen AI

    Note over U,Q: 第一步：获取语音服务Token
    U->>C: 启动语音记账
    C->>S: GET /api/v1/voice/token
    S->>S: 检查Token缓存
    alt Token已缓存且未过期
        S-->>C: 返回缓存的Token
    else Token过期或不存在
        S->>A: CreateToken请求
        A-->>S: 返回Token (有效期24h)
        S->>S: 缓存Token
        S-->>C: 返回Token和配置
    end

    Note over U,Q: 第二步：客户端语音识别
    C->>C: 初始化阿里云ASR SDK
    U->>C: 开始说话
    C->>A: 建立WebSocket连接
    C->>A: 流式发送音频数据
    A-->>C: 实时返回识别结果
    C->>C: 显示中间结果
    A-->>C: 返回最终文本
    C->>U: 显示完整识别文本

    Note over U,Q: 第三步：AI解析文本
    C->>S: POST /ai/recognize-voice<br/>text="今天买咖啡38元"
    S->>Q: 调用Qwen API
    Q-->>S: 返回JSON结果
    S->>S: 解析AI响应
    S-->>C: 返回交易信息

    Note over U,Q: 第四步：创建交易
    C->>U: 显示解析结果
    U->>C: 确认/修改
    C->>S: POST /api/v1/transactions
    S-->>C: 返回创建的交易
    C->>U: 记账成功
```

## 3. 方案2：服务端音频识别流程

```mermaid
sequenceDiagram
    participant U as 用户
    participant C as 客户端APP
    participant S as 后端服务器
    participant Q as Qwen-Omni

    Note over U,Q: 录制和上传音频
    U->>C: 开始语音记账
    C->>C: 录制音频
    U->>C: 结束录制
    C->>C: 压缩音频文件
    C->>S: POST /ai/recognize-audio<br/>multipart/form-data

    Note over U,Q: 服务端处理
    S->>S: 验证文件类型和大小
    S->>S: 编码为Base64
    S->>Q: 调用Qwen-Omni-Turbo<br/>发送音频+提示词
    Q->>Q: 音频理解和信息提取
    Q-->>S: 返回转写文本+交易信息
    S->>S: 解析JSON响应
    S-->>C: 返回结构化数据

    Note over U,Q: 用户确认
    C->>U: 显示识别结果
    U->>C: 确认/修改
    C->>S: POST /api/v1/transactions
    S-->>C: 创建成功
    C->>U: 记账完成
```

## 4. Token获取详细流程

```mermaid
flowchart TD
    A[客户端请求Token] --> B{检查缓存}
    B -->|已缓存| C{检查过期时间}
    C -->|未过期<br/>距离过期>5分钟| D[返回缓存Token]
    C -->|即将过期或已过期| E{检查限流状态}

    B -->|未缓存| E

    E -->|限流中| F[返回429错误<br/>Too Many Requests]
    E -->|未限流| G[构建请求参数]

    G --> H[生成签名<br/>HMAC-SHA1]
    H --> I[调用阿里云Meta服务<br/>CreateToken]

    I --> J{请求成功?}
    J -->|成功| K[缓存Token<br/>设置过期时间为1小时]
    K --> L[返回Token和配置]

    J -->|失败| M[设置限流60秒]
    M --> N[返回502错误<br/>Bad Gateway]

    style D fill:#c8e6c9
    style L fill:#c8e6c9
    style F fill:#ffcdd2
    style N fill:#ffcdd2
```

## 5. AI文本解析流程

```mermaid
flowchart TD
    A[接收语音文本] --> B[构建Prompt]
    B --> C[调用Qwen API]

    C --> D{Qwen成功?}
    D -->|成功| E[解析JSON响应]
    E --> F{解析成功?}
    F -->|成功| G[返回结构化数据<br/>confidence=0.85]

    D -->|失败| H[调用Zhipu API]
    H --> I{Zhipu成功?}
    I -->|成功| J[解析JSON响应]
    J --> K{解析成功?}
    K -->|成功| L[返回结构化数据<br/>confidence=0.80]

    F -->|失败| M[正则表达式解析]
    I -->|失败| M
    K -->|失败| M

    M --> N[提取金额]
    N --> O[检测收入/支出]
    O --> P[匹配分类关键词]
    P --> Q[返回结构化数据<br/>confidence=0.60]

    style G fill:#c8e6c9
    style L fill:#fff9c4
    style Q fill:#ffccbc
```

## 6. 正则表达式解析逻辑

```mermaid
flowchart LR
    A[输入文本] --> B[提取金额<br/>正则匹配数字]
    B --> C[检测收入关键词<br/>工资/收入/到账等]

    C --> D{是否收入?}
    D -->|是| E[category_type=2<br/>收入]
    D -->|否| F[category_type=1<br/>支出]

    E --> G[匹配收入分类<br/>工资/奖金/兼职/理财]
    F --> H[匹配支出分类<br/>餐饮/交通/购物等]

    G --> I[设置分类]
    H --> I

    I --> J{找到匹配?}
    J -->|是| K[使用匹配的分类]
    J -->|否| L[使用默认分类<br/>其他]

    K --> M[构建结果<br/>confidence=0.60]
    L --> M

    style M fill:#e1bee7
```

## 7. 错误处理流程

```mermaid
flowchart TD
    A[API请求] --> B{验证用户}
    B -->|失败| C1[401 Unauthorized]
    B -->|成功| C{验证输入}

    C -->|失败| D1[400 Bad Request]
    C -->|成功| D{检查配置}

    D -->|未配置| E1[503 Service Unavailable<br/>语音服务未配置]
    D -->|已配置| E{检查限流}

    E -->|限流中| F1[429 Too Many Requests]
    E -->|正常| F{调用AI服务}

    F -->|Qwen失败| G{调用Zhipu}
    G -->|Zhipu失败| H[使用正则解析]

    F -->|成功| I[解析响应]
    G -->|成功| I
    H --> I

    I --> J{解析结果}
    J -->|有效数据| K[200 OK<br/>返回结果]
    J -->|无效数据| L[200 OK<br/>返回空结果]

    style K fill:#c8e6c9
    style C1 fill:#ffcdd2
    style D1 fill:#ffcdd2
    style E1 fill:#ffcdd2
    style F1 fill:#ffcdd2
    style L fill:#fff9c4
```

## 8. 分类系统决策树

```mermaid
flowchart TD
    A[输入文本] --> B{检测收入关键词}

    B -->|包含工资| C1[分类: 工资<br/>type: income]
    B -->|包含奖金| C2[分类: 奖金<br/>type: income]
    B -->|包含兼职| C3[分类: 兼职<br/>type: income]
    B -->|包含理财| C4[分类: 理财<br/>type: income]

    B -->|无收入关键词| D{检测支出关键词}

    D -->|包含餐饮词| E1[分类: 餐饮<br/>type: expense]
    D -->|包含交通词| E2[分类: 交通<br/>type: expense]
    D -->|包含购物词| E3[分类: 购物<br/>type: expense]
    D -->|包含娱乐词| E4[分类: 娱乐<br/>type: expense]
    D -->|包含住房词| E5[分类: 住房<br/>type: expense]
    D -->|包含医疗词| E6[分类: 医疗<br/>type: expense]
    D -->|包含教育词| E7[分类: 教育<br/>type: expense]

    D -->|无匹配| F[分类: 其他<br/>type: expense]

    style C1 fill:#c8e6c9
    style C2 fill:#c8e6c9
    style C3 fill:#c8e6c9
    style C4 fill:#c8e6c9
    style E1 fill:#fff9c4
    style E2 fill:#fff9c4
    style E3 fill:#fff9c4
    style E4 fill:#fff9c4
    style E5 fill:#fff9c4
    style E6 fill:#fff9c4
    style E7 fill:#fff9c4
    style F fill:#ffccbc
```

## 9. 音频识别详细流程（Qwen-Omni）

```mermaid
sequenceDiagram
    participant C as 客户端
    participant S as 服务器
    participant Q as Qwen-Omni API

    Note over C,Q: 上传和验证
    C->>S: POST /ai/recognize-audio<br/>file: audio.mp3
    S->>S: 验证文件类型<br/>mp3/wav/aac/m4a等
    S->>S: 检查文件大小<br/>最大10MB

    alt 验证失败
        S-->>C: 400 Bad Request<br/>不支持的格式或文件过大
    else 验证成功
        Note over C,Q: 编码和发送
        S->>S: 读取文件内容
        S->>S: Base64编码
        S->>S: 构建多模态请求<br/>audio + text prompt

        S->>Q: POST multimodal API<br/>model: qwen-omni-turbo

        Note over C,Q: AI处理
        Q->>Q: 音频理解<br/>语音转写
        Q->>Q: 信息提取<br/>金额/分类/备注
        Q->>Q: 结构化输出<br/>生成JSON

        Q-->>S: 返回结果JSON

        Note over C,Q: 解析和返回
        S->>S: 提取transcription<br/>语音转写文本
        S->>S: 提取交易信息<br/>amount/category/note
        S->>S: 计算置信度

        S-->>C: 200 OK<br/>AudioRecognitionResult
    end
```

## 10. 性能优化策略

```mermaid
graph TB
    subgraph "Token缓存优化"
        A1[首次请求] --> A2[调用阿里云API]
        A2 --> A3[缓存Token 1小时]
        A3 --> A4[后续请求直接返回缓存]
        A4 --> A5[节省99%的请求]
    end

    subgraph "客户端识别优化"
        B1[传统方案:<br/>上传音频1MB] --> B2[服务器识别]
        B2 --> B3[返回结果]
        B1 --> B4[优化方案:<br/>传输文本100字节]
        B4 --> B5[节省90%流量]
    end

    subgraph "AI降级策略"
        C1[Qwen API<br/>高准确率 慢] --> C2{成功?}
        C2 -->|失败| C3[Zhipu API<br/>中准确率 中]
        C3 --> C4{成功?}
        C4 -->|失败| C5[正则匹配<br/>低准确率 快]
        C2 -->|成功| C6[返回结果]
        C4 -->|成功| C6
        C5 --> C6
    end

    subgraph "超时控制"
        D1[文本解析: 30s]
        D2[图像识别: 30s]
        D3[音频识别: 60s]
        D4[批量识别: 60s]
    end

    style A5 fill:#c8e6c9
    style B5 fill:#c8e6c9
    style C6 fill:#c8e6c9
```

## 11. 数据流转换

```mermaid
flowchart LR
    A[语音信号<br/>PCM 16kHz] --> B[阿里云ASR]
    B --> C[文本<br/>今天买咖啡38元]

    C --> D[Qwen AI]
    D --> E[JSON结构<br/>amount: 38<br/>category: 餐饮]

    E --> F[Pydantic Schema<br/>RecognitionResult]
    F --> G[数据库模型<br/>Transaction]

    G --> H[持久化存储<br/>PostgreSQL]

    style A fill:#e3f2fd
    style C fill:#fff3e0
    style E fill:#f3e5f5
    style H fill:#e8f5e9
```

## 12. 完整用户交互流程

```mermaid
stateDiagram-v2
    [*] --> 空闲状态

    空闲状态 --> 准备中: 用户点击语音记账
    准备中 --> 获取Token: 检查Token缓存
    获取Token --> 录音中: Token获取成功
    获取Token --> 错误提示: Token获取失败

    录音中 --> 识别中: 用户结束录音
    录音中 --> 空闲状态: 用户取消

    识别中 --> 解析中: ASR识别完成
    识别中 --> 错误提示: 识别失败

    解析中 --> 结果展示: AI解析成功
    解析中 --> 错误提示: 解析失败

    结果展示 --> 确认编辑: 用户查看结果

    确认编辑 --> 创建交易: 用户确认
    确认编辑 --> 结果展示: 用户修改
    确认编辑 --> 空闲状态: 用户取消

    创建交易 --> 完成: 保存成功
    创建交易 --> 错误提示: 保存失败

    完成 --> 空闲状态
    错误提示 --> 空闲状态: 用户确认
```

## 13. 置信度评分系统

```mermaid
graph LR
    A[AI响应] --> B{提取成功?}

    B -->|完全提取| C{数据源}
    C -->|Qwen Audio| D1[0.90]
    C -->|Qwen Text| D2[0.85]
    C -->|Zhipu Text| D3[0.80]

    B -->|部分提取| E{关键字段}
    E -->|有金额| F1[0.70]
    E -->|无金额| F2[0.50]

    B -->|正则匹配| G{匹配质量}
    G -->|完整匹配| H1[0.60]
    G -->|部分匹配| H2[0.40]

    B -->|完全失败| I[null]

    D1 --> J[高置信度<br/>可自动记账]
    D2 --> J
    D3 --> K[中置信度<br/>建议确认]
    F1 --> K
    F2 --> L[低置信度<br/>必须确认]
    H1 --> L
    H2 --> L
    I --> M[无法识别<br/>手动输入]

    style J fill:#c8e6c9
    style K fill:#fff9c4
    style L fill:#ffe0b2
    style M fill:#ffcdd2
```

## 使用说明

### 在GitHub/GitLab查看

这些Mermaid图表可以在GitHub、GitLab等平台的Markdown预览中直接渲染显示。

### 在本地查看

1. 使用支持Mermaid的Markdown编辑器：
   - VS Code + Mermaid插件
   - Typora
   - Obsidian

2. 在线预览：
   - [Mermaid Live Editor](https://mermaid.live/)
   - 复制代码块到在线编辑器

### 导出为图片

使用Mermaid CLI工具：
```bash
npm install -g @mermaid-js/mermaid-cli
mmdc -i VOICE_PROCESSING_DIAGRAMS.md -o diagrams.pdf
```

---

**相关文档**: [语音处理工作流程](./VOICE_PROCESSING_WORKFLOW.md)
