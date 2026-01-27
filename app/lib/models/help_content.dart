/// 帮助内容数据模型
class HelpContent {
  /// 页面标识（对应route）
  final String pageId;

  /// 页面标题
  final String title;

  /// 所属模块
  final String module;

  /// 功能描述（1-2句话）
  final String description;

  /// 使用场景列表
  final List<String> useCases;

  /// 操作步骤
  final List<HelpStep> steps;

  /// 注意事项/小贴士
  final List<String> tips;

  /// 相关页面
  final List<String> relatedPages;

  /// 搜索关键词（可选）
  final List<String> keywords;

  HelpContent({
    required this.pageId,
    required this.title,
    required this.module,
    required this.description,
    this.useCases = const [],
    this.steps = const [],
    this.tips = const [],
    this.relatedPages = const [],
    this.keywords = const [],
  });

  /// 从JSON创建HelpContent对象
  factory HelpContent.fromJson(Map<String, dynamic> json) {
    return HelpContent(
      pageId: json['pageId'] as String,
      title: json['title'] as String,
      module: json['module'] as String,
      description: json['description'] as String,
      useCases: (json['useCases'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      steps: (json['steps'] as List<dynamic>?)
              ?.map((e) => HelpStep.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      tips: (json['tips'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      relatedPages: (json['relatedPages'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      keywords: (json['keywords'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'pageId': pageId,
      'title': title,
      'module': module,
      'description': description,
      'useCases': useCases,
      'steps': steps.map((e) => e.toJson()).toList(),
      'tips': tips,
      'relatedPages': relatedPages,
      'keywords': keywords,
    };
  }
}

/// 帮助步骤数据模型
class HelpStep {
  /// 步骤标题
  final String title;

  /// 步骤详情
  final String description;

  /// 可选：配图路径
  final String? imageAsset;

  HelpStep({
    required this.title,
    required this.description,
    this.imageAsset,
  });

  /// 从JSON创建HelpStep对象
  factory HelpStep.fromJson(Map<String, dynamic> json) {
    return HelpStep(
      title: json['title'] as String,
      description: json['description'] as String,
      imageAsset: json['imageAsset'] as String?,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      if (imageAsset != null) 'imageAsset': imageAsset,
    };
  }
}
