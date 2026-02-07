import 'dart:typed_data';

import 'asr_capabilities.dart';
import 'asr_config.dart';
import 'asr_models.dart';

/// ASR插件接口
///
/// 所有ASR插件必须实现此接口

/// 插件状态
enum ASRPluginState {
  /// 未初始化
  uninitialized,

  /// 正在初始化
  initializing,

  /// 空闲
  idle,

  /// 正在识别
  recognizing,

  /// 错误状态
  error,

  /// 已释放
  disposed,
}

/// ASR插件接口
abstract class ASRPluginInterface {
  /// 插件唯一标识符
  String get pluginId;

  /// 显示名称
  String get displayName;

  /// 能力描述
  ASRCapabilities get capabilities;

  /// 当前状态
  ASRPluginState get state;

  /// 优先级（数值越小优先级越高）
  int get priority;

  /// 初始化插件
  ///
  /// [config] 可选配置
  Future<void> initialize({ASRPluginConfig? config});

  /// 检查可用性
  ///
  /// 返回插件当前是否可用
  Future<ASRAvailability> checkAvailability();

  /// 批量识别（完整音频）
  ///
  /// [audio] 处理后的音频数据
  /// 返回识别结果
  Future<ASRResult> transcribe(ProcessedAudio audio);

  /// 流式识别（实时转写）
  ///
  /// [audioStream] 音频数据流
  /// 返回部分结果流
  Stream<ASRPartialResult> transcribeStream(Stream<Uint8List> audioStream);

  /// 取消当前识别
  Future<void> cancelTranscription();

  /// 预热连接（可选）
  ///
  /// 提前建立连接以减少延迟
  Future<void> warmupConnection() async {}

  /// 是否有预热的连接可用
  bool get hasValidWarmup => false;

  /// 设置热词
  void setHotWords(List<HotWord> hotWords) {}

  /// 添加热词
  void addHotWords(List<HotWord> hotWords) {}

  /// 释放资源
  Future<void> dispose();
}

/// ASR插件基类
///
/// 提供一些通用实现
abstract class ASRPluginBase implements ASRPluginInterface {
  ASRPluginState _state = ASRPluginState.uninitialized;
  ASRPluginConfig _config = ASRPluginConfig.defaults();
  List<HotWord> _hotWords = [];

  @override
  ASRPluginState get state => _state;

  ASRPluginConfig get config => _config;

  set state(ASRPluginState value) => _state = value;

  @override
  Future<void> initialize({ASRPluginConfig? config}) async {
    if (_state == ASRPluginState.disposed) {
      throw StateError('Plugin has been disposed');
    }

    _state = ASRPluginState.initializing;
    _config = config ?? ASRPluginConfig.defaults();

    try {
      await doInitialize();
      _state = ASRPluginState.idle;
    } catch (e) {
      _state = ASRPluginState.error;
      rethrow;
    }
  }

  /// 子类实现的初始化逻辑
  Future<void> doInitialize();

  @override
  void setHotWords(List<HotWord> hotWords) {
    _hotWords = List.from(hotWords);
  }

  @override
  void addHotWords(List<HotWord> hotWords) {
    _hotWords.addAll(hotWords);
  }

  List<HotWord> get hotWords => _hotWords;

  @override
  Future<void> warmupConnection() async {}

  @override
  bool get hasValidWarmup => false;

  @override
  Future<void> dispose() async {
    _state = ASRPluginState.disposed;
    await doDispose();
  }

  /// 子类实现的释放逻辑
  Future<void> doDispose();
}
