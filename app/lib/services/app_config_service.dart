import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/logger.dart';

/// 应用配置服务
/// 从服务器获取配置，支持本地缓存和离线回退
class AppConfigService {
  static final AppConfigService _instance = AppConfigService._internal();
  factory AppConfigService() => _instance;
  AppConfigService._internal();

  static const String _cacheKey = 'app_settings_cache';
  static const String _cacheTimeKey = 'app_settings_cache_time';
  static const Duration _cacheExpiry = Duration(hours: 24);

  // 默认配置（硬编码回退值）
  static const String _defaultApiBaseUrl = 'https://160.202.238.29/api/v1';
  // 默认跳过证书验证（开发环境自签名证书）
  static const bool _defaultSkipCertVerification = true;

  // 缓存的配置
  AppSettingsConfig? _cachedConfig;
  bool _initialized = false;

  /// 获取当前配置
  AppSettingsConfig get config => _cachedConfig ?? AppSettingsConfig.defaults();

  /// 是否已初始化
  bool get isInitialized => _initialized;

  /// 初始化配置服务
  /// 首先尝试从服务器获取，失败则使用缓存，最后使用默认值
  Future<void> initialize() async {
    if (_initialized) return;

    final logger = Logger();

    // 1. 尝试从本地缓存加载
    await _loadFromCache();

    // 2. 尝试从服务器获取最新配置
    try {
      await fetchFromServer();
      logger.info('App config loaded from server');
    } catch (e) {
      logger.warning('Failed to fetch config from server, using cached/default: $e');
    }

    _initialized = true;
  }

  /// 从服务器获取配置
  Future<void> fetchFromServer() async {
    final dio = Dio(BaseOptions(
      baseUrl: _cachedConfig?.apiBaseUrl ?? _defaultApiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));

    // 配置 SSL 证书验证
    final skipCert = _cachedConfig?.skipCertificateVerification ?? _defaultSkipCertVerification;
    if (skipCert) {
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.badCertificateCallback = (cert, host, port) => true;
          return client;
        },
      );
    }

    final response = await dio.get('/config/app-settings');

    if (response.statusCode == 200) {
      _cachedConfig = AppSettingsConfig.fromJson(response.data);
      await _saveToCache();
    }
  }

  /// 从本地缓存加载配置
  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheTime = prefs.getInt(_cacheTimeKey);
      final cacheData = prefs.getString(_cacheKey);

      if (cacheTime != null && cacheData != null) {
        final cacheAge = DateTime.now().millisecondsSinceEpoch - cacheTime;
        if (cacheAge < _cacheExpiry.inMilliseconds) {
          _cachedConfig = AppSettingsConfig.fromJson(jsonDecode(cacheData));
        }
      }
    } catch (e) {
      // 缓存加载失败，使用默认值
    }
  }

  /// 保存配置到本地缓存
  Future<void> _saveToCache() async {
    if (_cachedConfig == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(_cachedConfig!.toJson()));
      await prefs.setInt(_cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      // 缓存保存失败，忽略
    }
  }

  /// 强制刷新配置
  Future<void> refresh() async {
    await fetchFromServer();
  }

  /// 清除缓存
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_cacheTimeKey);
    _cachedConfig = null;
  }
}

/// 应用设置配置模型
class AppSettingsConfig {
  final String configVersion;
  final String minAppVersion;
  final String apiBaseUrl;
  final bool skipCertificateVerification;
  final AIModelConfig aiModels;
  final NetworkConfig network;
  final DuplicateDetectionConfig duplicateDetection;
  final CategoryMapping categories;
  final FeatureFlags features;

  AppSettingsConfig({
    required this.configVersion,
    required this.minAppVersion,
    required this.apiBaseUrl,
    required this.skipCertificateVerification,
    required this.aiModels,
    required this.network,
    required this.duplicateDetection,
    required this.categories,
    required this.features,
  });

  factory AppSettingsConfig.defaults() {
    return AppSettingsConfig(
      configVersion: '1.0.0',
      minAppVersion: '1.0.0',
      apiBaseUrl: 'https://160.202.238.29/api/v1',
      skipCertificateVerification: true,  // 开发环境自签名证书
      aiModels: AIModelConfig.defaults(),
      network: NetworkConfig.defaults(),
      duplicateDetection: DuplicateDetectionConfig.defaults(),
      categories: CategoryMapping.defaults(),
      features: FeatureFlags.defaults(),
    );
  }

  factory AppSettingsConfig.fromJson(Map<String, dynamic> json) {
    return AppSettingsConfig(
      configVersion: json['config_version'] ?? '1.0.0',
      minAppVersion: json['min_app_version'] ?? '1.0.0',
      apiBaseUrl: json['api_base_url'] ?? 'https://160.202.238.29/api/v1',
      skipCertificateVerification: json['skip_certificate_verification'] ?? false,
      aiModels: json['ai_models'] != null
          ? AIModelConfig.fromJson(json['ai_models'])
          : AIModelConfig.defaults(),
      network: json['network'] != null
          ? NetworkConfig.fromJson(json['network'])
          : NetworkConfig.defaults(),
      duplicateDetection: json['duplicate_detection'] != null
          ? DuplicateDetectionConfig.fromJson(json['duplicate_detection'])
          : DuplicateDetectionConfig.defaults(),
      categories: json['categories'] != null
          ? CategoryMapping.fromJson(json['categories'])
          : CategoryMapping.defaults(),
      features: json['features'] != null
          ? FeatureFlags.fromJson(json['features'])
          : FeatureFlags.defaults(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'config_version': configVersion,
      'min_app_version': minAppVersion,
      'api_base_url': apiBaseUrl,
      'skip_certificate_verification': skipCertificateVerification,
      'ai_models': aiModels.toJson(),
      'network': network.toJson(),
      'duplicate_detection': duplicateDetection.toJson(),
      'categories': categories.toJson(),
      'features': features.toJson(),
    };
  }
}

/// AI 模型配置
class AIModelConfig {
  final String visionModel;
  final String textModel;
  final String audioModel;
  final String categoryModel;
  final String billModel;

  AIModelConfig({
    required this.visionModel,
    required this.textModel,
    required this.audioModel,
    required this.categoryModel,
    required this.billModel,
  });

  factory AIModelConfig.defaults() {
    return AIModelConfig(
      visionModel: 'qwen-vl-plus',
      textModel: 'qwen-turbo',
      audioModel: 'qwen-omni-turbo',
      categoryModel: 'qwen-turbo',
      billModel: 'qwen-plus',
    );
  }

  factory AIModelConfig.fromJson(Map<String, dynamic> json) {
    return AIModelConfig(
      visionModel: json['vision_model'] ?? 'qwen-vl-plus',
      textModel: json['text_model'] ?? 'qwen-turbo',
      audioModel: json['audio_model'] ?? 'qwen-omni-turbo',
      categoryModel: json['category_model'] ?? 'qwen-turbo',
      billModel: json['bill_model'] ?? 'qwen-plus',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vision_model': visionModel,
      'text_model': textModel,
      'audio_model': audioModel,
      'category_model': categoryModel,
      'bill_model': billModel,
    };
  }
}

/// 网络配置
class NetworkConfig {
  final int connectTimeoutSeconds;
  final int receiveTimeoutSeconds;
  final int aiReceiveTimeoutSeconds;
  final int maxRetries;
  final int retryBaseDelaySeconds;
  final double retryBackoffMultiplier;

  NetworkConfig({
    required this.connectTimeoutSeconds,
    required this.receiveTimeoutSeconds,
    required this.aiReceiveTimeoutSeconds,
    required this.maxRetries,
    required this.retryBaseDelaySeconds,
    required this.retryBackoffMultiplier,
  });

  factory NetworkConfig.defaults() {
    return NetworkConfig(
      connectTimeoutSeconds: 30,
      receiveTimeoutSeconds: 30,
      aiReceiveTimeoutSeconds: 60,
      maxRetries: 3,
      retryBaseDelaySeconds: 2,
      retryBackoffMultiplier: 2.0,
    );
  }

  factory NetworkConfig.fromJson(Map<String, dynamic> json) {
    return NetworkConfig(
      connectTimeoutSeconds: json['connect_timeout_seconds'] ?? 30,
      receiveTimeoutSeconds: json['receive_timeout_seconds'] ?? 30,
      aiReceiveTimeoutSeconds: json['ai_receive_timeout_seconds'] ?? 60,
      maxRetries: json['max_retries'] ?? 3,
      retryBaseDelaySeconds: json['retry_base_delay_seconds'] ?? 2,
      retryBackoffMultiplier: (json['retry_backoff_multiplier'] ?? 2.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'connect_timeout_seconds': connectTimeoutSeconds,
      'receive_timeout_seconds': receiveTimeoutSeconds,
      'ai_receive_timeout_seconds': aiReceiveTimeoutSeconds,
      'max_retries': maxRetries,
      'retry_base_delay_seconds': retryBaseDelaySeconds,
      'retry_backoff_multiplier': retryBackoffMultiplier,
    };
  }

  Duration get connectTimeout => Duration(seconds: connectTimeoutSeconds);
  Duration get receiveTimeout => Duration(seconds: receiveTimeoutSeconds);
  Duration get aiReceiveTimeout => Duration(seconds: aiReceiveTimeoutSeconds);
  Duration get retryBaseDelay => Duration(seconds: retryBaseDelaySeconds);
}

/// 重复检测配置
class DuplicateDetectionConfig {
  final int strictTimeMinutes;
  final int looseTimeMinutes;
  final int maxTimeMinutes;
  final double amountTolerance;

  DuplicateDetectionConfig({
    required this.strictTimeMinutes,
    required this.looseTimeMinutes,
    required this.maxTimeMinutes,
    required this.amountTolerance,
  });

  factory DuplicateDetectionConfig.defaults() {
    return DuplicateDetectionConfig(
      strictTimeMinutes: 10,
      looseTimeMinutes: 60,
      maxTimeMinutes: 120,
      amountTolerance: 0.01,
    );
  }

  factory DuplicateDetectionConfig.fromJson(Map<String, dynamic> json) {
    return DuplicateDetectionConfig(
      strictTimeMinutes: json['strict_time_minutes'] ?? 10,
      looseTimeMinutes: json['loose_time_minutes'] ?? 60,
      maxTimeMinutes: json['max_time_minutes'] ?? 120,
      amountTolerance: (json['amount_tolerance'] ?? 0.01).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'strict_time_minutes': strictTimeMinutes,
      'loose_time_minutes': looseTimeMinutes,
      'max_time_minutes': maxTimeMinutes,
      'amount_tolerance': amountTolerance,
    };
  }
}

/// 分类映射配置
class CategoryMapping {
  final List<String> validIds;
  final Map<String, String> exactMap;
  final Map<String, List<String>> keywords;

  CategoryMapping({
    required this.validIds,
    required this.exactMap,
    required this.keywords,
  });

  factory CategoryMapping.defaults() {
    return CategoryMapping(
      validIds: [
        'food', 'transport', 'shopping', 'entertainment', 'housing',
        'medical', 'education', 'other_expense', 'other_income',
        'salary', 'bonus', 'parttime', 'investment',
      ],
      exactMap: {
        '餐饮': 'food', '食品': 'food', '饮食': 'food', '吃饭': 'food', '美食': 'food',
        '交通': 'transport', '出行': 'transport', '打车': 'transport',
        '购物': 'shopping', '网购': 'shopping',
        '娱乐': 'entertainment', '休闲': 'entertainment',
        '住房': 'housing', '房租': 'housing', '居住': 'housing',
        '医疗': 'medical', '健康': 'medical', '看病': 'medical',
        '教育': 'education', '学习': 'education', '培训': 'education',
        '其他': 'other_expense',
        '工资': 'salary', '薪水': 'salary', '薪资': 'salary',
        '奖金': 'bonus', '年终奖': 'bonus',
        '兼职': 'parttime', '副业': 'parttime',
        '理财': 'investment', '投资': 'investment', '收益': 'investment',
      },
      keywords: {
        'food': ['餐', '饭', '食', '吃', '喝', '咖啡', '奶茶', '外卖', '星巴克', '肯德基', '麦当劳'],
        'transport': ['车', '交通', '打车', '地铁', '公交', '滴滴', '加油', '高铁', '飞机'],
        'shopping': ['购', '买', '超市', '商场', '淘宝', '京东', '天猫'],
        'entertainment': ['娱乐', '电影', '游戏', 'KTV', '旅游', '健身'],
        'housing': ['房', '租', '水电', '物业', '宽带'],
        'medical': ['医', '药', '病', '体检', '医院'],
        'education': ['教育', '学', '书', '课', '培训'],
        'salary': ['工资', '薪', '月薪'],
        'bonus': ['奖金', '年终', '提成'],
        'parttime': ['兼职', '副业', '外快'],
        'investment': ['理财', '投资', '收益', '利息', '基金'],
      },
    );
  }

  factory CategoryMapping.fromJson(Map<String, dynamic> json) {
    return CategoryMapping(
      validIds: List<String>.from(json['valid_ids'] ?? []),
      exactMap: Map<String, String>.from(json['exact_map'] ?? {}),
      keywords: (json['keywords'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(key, List<String>.from(value)),
      ) ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'valid_ids': validIds,
      'exact_map': exactMap,
      'keywords': keywords,
    };
  }

  /// 映射分类
  String mapCategory(String? category, String? type) {
    if (category == null || category.isEmpty) {
      return _getOtherCategory(type);
    }

    // 精确匹配
    if (exactMap.containsKey(category)) {
      return exactMap[category]!;
    }

    // 已是有效ID
    final lower = category.toLowerCase().trim();
    if (lower == 'other') {
      return _getOtherCategory(type);
    }
    if (validIds.contains(lower)) {
      return lower;
    }

    // 关键词匹配
    for (final entry in keywords.entries) {
      for (final keyword in entry.value) {
        if (category.contains(keyword)) {
          return entry.key;
        }
      }
    }

    return _getOtherCategory(type);
  }

  String _getOtherCategory(String? type) {
    return type == 'income' ? 'other_income' : 'other_expense';
  }
}

/// 功能开关
class FeatureFlags {
  final bool enableVoiceRecognition;
  final bool enableImageRecognition;
  final bool enableAiCategorization;
  final bool enableDuplicateDetection;
  final bool enableOfflineMode;

  FeatureFlags({
    required this.enableVoiceRecognition,
    required this.enableImageRecognition,
    required this.enableAiCategorization,
    required this.enableDuplicateDetection,
    required this.enableOfflineMode,
  });

  factory FeatureFlags.defaults() {
    return FeatureFlags(
      enableVoiceRecognition: true,
      enableImageRecognition: true,
      enableAiCategorization: true,
      enableDuplicateDetection: true,
      enableOfflineMode: true,
    );
  }

  factory FeatureFlags.fromJson(Map<String, dynamic> json) {
    return FeatureFlags(
      enableVoiceRecognition: json['enable_voice_recognition'] ?? true,
      enableImageRecognition: json['enable_image_recognition'] ?? true,
      enableAiCategorization: json['enable_ai_categorization'] ?? true,
      enableDuplicateDetection: json['enable_duplicate_detection'] ?? true,
      enableOfflineMode: json['enable_offline_mode'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enable_voice_recognition': enableVoiceRecognition,
      'enable_image_recognition': enableImageRecognition,
      'enable_ai_categorization': enableAiCategorization,
      'enable_duplicate_detection': enableDuplicateDetection,
      'enable_offline_mode': enableOfflineMode,
    };
  }
}
