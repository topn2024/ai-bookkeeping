# 实时对话系统升级任务清单

## 第一批：P0 核心对话体验

### 1. 实时对话会话控制器
- [x] 创建 `lib/services/voice/realtime_conversation_session.dart`
- [x] 实现 RealtimeSessionState 状态枚举
- [x] 实现状态流转逻辑
- [x] 集成VAD语音活动检测
- [x] 实现轮次结束停顿机制（1.5秒）
- [x] 实现等待超时逻辑（5秒）

### 2. 对话与执行桥接器
- [x] 创建 `lib/services/voice/conversation_action_bridge.dart`
- [x] 实现异步操作提交接口
- [x] 实现执行结果流
- [x] 实现结果注入对话上下文

### 3. 后台操作执行器
- [x] 创建 `lib/services/voice/background_operation_executor.dart`
- [x] 实现操作队列管理
- [x] 复用ActionRouter进行操作分发
- [x] 实现异步执行不阻塞调用方
- [x] 实现执行结果通知机制

### 4. VAD参数优化
- [x] 创建 `lib/services/voice/realtime_vad_config.dart`
- [x] 调整语音开始阈值为200ms
- [x] 调整语音结束阈值为500ms
- [x] 实现背景噪音自适应

### 5. 层次化状态机
- [x] 创建 `lib/services/voice/voice_state_machine.dart`
- [x] 实现SessionState (active, paused, ended)
- [x] 实现SpeakingState (idle, speaking, fading)
- [x] 实现ListeningState (idle, listening, processing)
- [x] 支持并发状态（speaking + listening）

### 6. 流式TTS服务
- [x] 创建 `lib/services/streaming_tts_service.dart`
- [x] 实现WebSocket长连接（或分句策略）
- [x] 实现分块接收音频数据
- [x] 实现边接收边播放
- [x] 实现中途取消支持
- [x] 创建 `lib/services/audio_stream_player.dart`
- [x] 实现音频分块缓冲
- [x] 实现智能预缓冲策略
- [x] 实现即时停止功能
- [x] 实现音频淡出效果

### 7. 集成到悬浮球
- [x] 创建 `lib/services/voice/realtime_voice_integration.dart` （集成服务）
- [x] 创建 `lib/providers/realtime_voice_provider.dart` （Riverpod状态管理）
- [x] 创建 `lib/widgets/realtime_floating_ball.dart` （新悬浮球组件）
- [x] 实现RealtimeVoiceController控制器
- [x] 实现状态到UI颜色的映射

## 第二批：P1 个性化体验

### 8. 会话级短期记忆
- [x] 创建 `lib/services/voice/memory/conversation_memory.dart`
- [x] 实现对话历史管理（3-5轮）
- [x] 实现操作指代解析（"改成50"、"删掉它"）
- [x] 实现上下文摘要生成（供LLM使用）

### 9. 扩展操作指代
- [x] 在ConversationMemory中实现操作指代解析
- [x] 实现ActionReferenceType枚举（modifyAmount, modifyCategory, delete, cancel）
- [x] 实现"改成50"→修改金额
- [x] 实现"删掉它"→删除最近操作
- [x] 记录最近操作上下文（_lastAction）

### 10. 扩展用户画像
- [x] 修改 `lib/services/user_profile_service.dart`
- [x] 新增ConversationPreferences类
- [x] 记录是否喜欢主动发起对话（likesProactiveChat）
- [x] 记录沉默容忍度（silenceToleranceSeconds）
- [x] 记录感兴趣话题（favoriteTopics）
- [x] 新增VoiceDialogStyle枚举和对话风格

### 11. 集成画像驱动对话
- [x] 集成ProfileDrivenDialogService到RealtimeConversationSession
- [x] 在会话初始化时加载用户画像（_loadUserProfile）
- [x] 在生成响应时使用画像+记忆（ConversationMemory集成）

## 第三批：P1 完整交互

### 12. 打断检测
- [x] 创建 `lib/services/voice/barge_in_detector.dart`
- [x] 实现能量阈值检测
- [x] 实现VAD双通道
- [x] 实现关键词检测（"停"、"等等"）
- [x] 实现打断响应流程（淡出+切换）

### 13. 主动话题生成
- [x] 创建 `lib/services/voice/proactive_topic_generator.dart`
- [x] 实现基于画像的话题生成
- [x] 实现执行结果反馈话题
- [x] 实现提醒类话题
- [x] 实现引导类话题

### 14. 对话结束检测
- [x] 创建 `lib/services/voice/conversation_end_detector.dart`
- [x] 实现显式结束检测（"好了"、"谢谢"）
- [x] 实现隐式结束检测（连续两轮无响应）
- [x] 实现优雅结束流程

### 15. 异常处理机制
- [x] 创建 `lib/services/voice/exception_handler.dart`
- [x] 实现ASR异常处理
- [x] 实现NLU异常处理
- [x] 实现操作层异常处理
- [x] 创建 `lib/services/voice/frequency_limiter.dart`
- [x] 实现重复输入检测（3秒内）
- [x] 实现高频请求限制（1分钟20次）
- [x] 实现重复修改检测
- [x] 创建 `lib/services/voice/interrupt_recovery_manager.dart`
- [x] 实现对话放弃恢复
- [x] 实现应用切换恢复
- [x] 实现意图变更恢复
- [x] 创建 `lib/services/voice/input_preprocessor.dart`
- [x] 实现噪声检测与过滤
- [x] 实现输入长度限制
- [x] 实现安全检查（注入攻击检测）
- [x] 实现特殊字符过滤与规范化

### 16. 集成服务
- [x] 创建 `lib/services/voice/realtime_voice_integration.dart`
- [x] 整合所有实时语音组件
- [x] 提供统一API供悬浮球使用
- [x] 实现生命周期事件处理

## 第四批：P2 增强体验

### 16. 语音自然度
- [x] 实现情感化TTS参数
- [x] 实现拟声词和语气词
- [x] 实现响应变化（3-5种变体）

### 17. 画像学习优化
- [x] 从对话中学习用户偏好
- [x] 优化主动话题推荐

### 18. 高频输入优化
- [x] 优化批量记账处理
- [x] 优化频率限制策略

### 19. 中断恢复增强
- [x] 集成应用生命周期监听
- [x] 优化恢复策略

## 验证任务

### 对话体验验证
- [ ] 延迟测试：用户说话结束到听到回复 < 1.5秒
- [ ] 打断测试：TTS播放时说话，停止延迟 < 200ms
- [ ] 并发测试：说话时监听功能正常
- [ ] 自动结束测试：说"好了"后对话自动关闭
- [ ] 后台操作测试：记账期间继续说话不中断
- [ ] 主动发起测试：沉默5秒后智能体主动说话

### 个性化验证
- [ ] 短期记忆测试："记一笔100块"后说"改成50"
- [ ] 长期记忆测试：退出会话后重新开始能记住偏好
- [ ] 用户画像测试：多次交互后画像更新
- [ ] 个性化人设测试：不同画像用户问候语不同

### 异常处理验证
- [ ] 语音识别异常测试：静音/噪音、发音不清、数字歧义
- [ ] 语义理解异常测试：无关话题、模糊意图、矛盾指令
- [ ] 操作异常测试：越权操作、数据溢出、频率异常
- [ ] 高频重复输入测试：快速重复、大量请求、来回修改
- [ ] 中断恢复测试：对话放弃、应用切换、意图变更
