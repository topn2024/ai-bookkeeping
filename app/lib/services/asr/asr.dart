/// ASR插件化架构
///
/// 提供统一的ASR服务接口和插件管理

// 核心模块
export 'core/asr_exception.dart';
export 'core/asr_models.dart';
export 'core/asr_capabilities.dart';
export 'core/asr_config.dart';
export 'core/asr_plugin_interface.dart';

// 工具类
export 'utils/network_checker.dart';
export 'utils/audio_buffer.dart';
export 'utils/retry_policy.dart';
export 'utils/session_manager.dart';

// 注册与调度
export 'registry/asr_plugin_registry.dart';
export 'registry/asr_orchestrator.dart';
export 'postprocess/asr_postprocessor.dart';

// 插件（离线模型管理）
export 'plugins/offline/sherpa_engine_wrapper.dart'
    show
        OfflineModelType,
        ModelInfo,
        ModelDownloadInfo,
        OfflineModelManager,
        VADService,
        VADSegment,
        OfflineModelException,
        OfflineASRInitException;

// 插件实现
export 'plugins/iflytek_iat/iflytek_iat_plugin.dart';
export 'plugins/alicloud/alicloud_asr_plugin.dart';
export 'plugins/offline/offline_asr_plugin.dart';
