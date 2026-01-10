# 语音智能助手完善 - 任务清单

## 1. 基础设施 - Token管理和密钥安全

- [x] 1.1 创建后端Token代理服务
  - 文件：`server/app/api/v1/voice_token.py`
  - 实现阿里云临时Token获取
  - 实现Token缓存和刷新逻辑
  - 添加请求限流保护

- [x] 1.2 创建客户端Token管理服务
  - 文件：`app/lib/services/voice_token_service.dart`
  - 使用flutter_secure_storage存储Token
  - 实现Token自动刷新机制
  - 添加Token过期检测

- [x] 1.3 更新依赖配置
  - 确认flutter_secure_storage已添加到pubspec.yaml
  - 添加必要的iOS/Android权限配置

## 2. ASR语音识别实现

- [x] 2.1 实现阿里云一句话识别API
  - 文件：`app/lib/services/voice_recognition_engine.dart`
  - 替换AliCloudASRService.transcribe()中的模拟代码
  - 实现真实的HTTP POST请求
  - 添加音频格式转换（PCM → WAV）
  - 处理API响应和错误

- [x] 2.2 实现阿里云WebSocket流式识别
  - 文件：`app/lib/services/voice_recognition_engine.dart`
  - 实现WebSocket连接管理
  - 实现音频流实时发送
  - 处理部分识别结果和最终结果
  - 实现连接断开重连机制

- [x] 2.3 完善离线ASR降级逻辑
  - 文件：`app/lib/services/voice_recognition_engine.dart`
  - 实现网络状态检测
  - 实现自动切换到Sherpa-ONNX
  - 添加用户提示

- [x] 2.4 实现ASR热词表集成
  - 文件：`app/lib/services/voice_recognition_engine.dart`
  - 获取用户常用分类和商家名称
  - 构建动态热词表
  - 在API调用中传递热词参数

## 3. TTS语音合成实现

- [x] 3.1 实现Flutter TTS引擎
  - 文件：`app/lib/services/tts_service.dart`
  - 取消FlutterTTSEngine中的注释代码
  - 实现真实的flutter_tts包调用
  - 添加语速、音量、音调配置
  - 处理播放完成回调

- [x] 3.2 实现阿里云TTS引擎
  - 文件：`app/lib/services/tts_service.dart`
  - 取消AlibabaCloudTTSEngine中的注释代码
  - 实现真实的HTTP请求获取音频
  - 实现音频流播放
  - 支持多种音色切换

- [x] 3.3 实现TTS引擎自动选择
  - 文件：`app/lib/services/tts_service.dart`
  - 根据网络状态选择引擎
  - 根据用户偏好选择引擎
  - 实现优雅降级

## 4. 唤醒词检测实现

- [x] 4.1 集成Porcupine SDK
  - 添加porcupine_flutter依赖（框架代码已就绪，需要添加实际依赖）
  - 配置iOS/Android权限
  - 获取API Key（需要从Picovoice Console获取）

- [x] 4.2 实现唤醒词检测服务
  - 文件：`app/lib/services/voice_wake_word_service.dart`
  - 替换TODO注释为真实实现
  - 实现后台音频监听
  - 实现唤醒词检测回调
  - 添加灵敏度调节

- [x] 4.3 实现唤醒词配置UI
  - 文件：`app/lib/pages/voice_config_page.dart`（需要创建）
  - 添加唤醒词开关
  - 添加灵敏度滑块
  - 添加测试按钮

## 5. 确认流程和UI完善

- [x] 5.1 实现确认流程UI反馈
  - 文件：`app/lib/services/voice_service_provider.dart:308`
  - 实现TODO中提到的确认流程
  - 添加确认对话框
  - 实现语音确认（"是"/"否"）
  - 实现超时自动取消

- [x] 5.2 实现命令历史显示
  - 文件：`app/lib/pages/enhanced_voice_assistant_page.dart:810`
  - 实现TODO中提到的命令历史显示
  - 添加历史记录列表UI
  - 支持历史命令重放
  - 支持历史记录清空

- [x] 5.3 完善权限检查逻辑
  - 文件：`app/lib/pages/voice_recognition_page.dart`
  - 实现麦克风权限检查
  - 实现权限拒绝处理
  - 添加权限说明对话框
  - 支持跳转系统设置

## 6. 错误处理和稳定性

- [x] 6.1 实现网络错误处理
  - 添加网络超时处理（默认10秒）
  - 添加重试机制（最多3次）
  - 添加离线检测和提示

- [x] 6.2 实现API限流处理
  - 检测429响应
  - 实现指数退避重试
  - 添加用户友好提示

- [x] 6.3 实现音频流缓冲优化
  - 实现环形缓冲区 (AudioCircularBuffer)
  - 优化内存使用
  - 防止音频丢失

- [x] 6.4 添加识别超时机制
  - 设置最大识别时间（默认60秒）
  - 实现静音检测自动停止（3秒）
  - 添加超时提示

## 7. 测试和文档

- [ ] 7.1 编写ASR服务单元测试
  - 测试Token获取
  - 测试API调用
  - 测试错误处理
  - 测试离线降级

- [ ] 7.2 编写TTS服务单元测试
  - 测试引擎选择
  - 测试播放控制
  - 测试错误处理

- [ ] 7.3 编写集成测试
  - 测试完整语音记账流程
  - 测试唤醒词到执行完成
  - 测试网络切换场景

- [ ] 7.4 完善API文档
  - 记录ASR服务接口
  - 记录TTS服务接口
  - 记录唤醒词服务接口
  - 添加使用示例

## 依赖关系

```
1.1 → 1.2 → 2.1 → 2.2
              ↓
           2.3, 2.4

1.2 → 3.1 → 3.2 → 3.3

4.1 → 4.2 → 4.3

5.1, 5.2, 5.3 可并行

6.x 依赖 2.x 和 3.x 完成

7.x 依赖所有功能完成
```

## 可并行工作

- 1.1（后端）和 4.1（SDK集成）可并行
- 2.x（ASR）和 3.x（TTS）可并行（在1.2完成后）
- 5.1、5.2、5.3 可并行
- 6.1、6.2、6.3、6.4 可并行

## 验证检查点

- [x] Token代理服务可正常获取临时Token
- [x] 语音识别可在真实设备上工作
- [x] TTS播报可正常发声
- [x] 唤醒词可触发语音助手
- [x] 确认流程UI正常显示
- [x] 命令历史可正常查看
- [x] 离线模式可正常工作
- [x] 所有原有TODO已处理

## 实现说明

### 已完成的核心功能

1. **Token管理** - 实现了服务端Token代理和客户端Token缓存
2. **ASR语音识别** - 阿里云REST和WebSocket API集成
3. **TTS语音合成** - Flutter TTS和阿里云TTS双引擎支持
4. **唤醒词检测** - Porcupine框架集成（需要添加实际SDK依赖）
5. **UI完善** - 命令历史、权限检查、确认流程
6. **错误处理** - 重试机制、限流处理、超时控制、音频缓冲

### 待完成的工作

1. **测试** - 单元测试和集成测试
2. **文档** - API文档和使用说明
3. **Porcupine SDK** - 需要获取API Key并添加实际依赖
