import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'http_service.dart';
import 'database_service.dart';
import 'offline_capability_service.dart';

/// 云端校验自动纠错服务
///
/// 功能：
/// 1. 记录离线期间使用本地模型识别的结果
/// 2. 联网后自动将这些结果发送到云端校验
/// 3. 如果云端结果更准确，自动或提示用户进行纠错
class CloudVerificationService {
  static final CloudVerificationService _instance = CloudVerificationService._internal();
  factory CloudVerificationService() => _instance;
  CloudVerificationService._internal();

  final HttpService _http = HttpService();
  final DatabaseService _db = DatabaseService();
  final OfflineCapabilityService _offlineService = OfflineCapabilityService();

  final _verificationController = StreamController<VerificationResult>.broadcast();

  /// 校验结果流
  Stream<VerificationResult> get verificationStream => _verificationController.stream;

  /// 待校验记录缓存键
  static const String _pendingVerificationKey = 'pending_cloud_verification';

  /// 初始化服务
  Future<void> initialize() async {
    // 监听网络状态变化
    _offlineService.statusStream.listen((status) {
      if (status.isOnline) {
        // 网络恢复时，处理待校验记录
        processPendingVerifications();
      }
    });

    // 如果当前在线，立即处理待校验记录
    if (_offlineService.isOnline) {
      processPendingVerifications();
    }
  }

  /// 添加待校验的识别结果
  ///
  /// 当使用本地模型识别时调用此方法
  Future<void> addPendingVerification(PendingVerification verification) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingJson = prefs.getString(_pendingVerificationKey);

      List<Map<String, dynamic>> pending;
      if (existingJson != null) {
        pending = (jsonDecode(existingJson) as List)
            .cast<Map<String, dynamic>>();
      } else {
        pending = [];
      }

      pending.add(verification.toJson());

      await prefs.setString(_pendingVerificationKey, jsonEncode(pending));

      debugPrint('Added pending verification: ${verification.type}');

      // 如果在线，立即处理
      if (_offlineService.isOnline) {
        processPendingVerifications();
      }
    } catch (e) {
      debugPrint('Failed to add pending verification: $e');
    }
  }

  /// 处理所有待校验记录
  Future<void> processPendingVerifications() async {
    if (!_offlineService.isOnline) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final existingJson = prefs.getString(_pendingVerificationKey);

      if (existingJson == null) return;

      final pending = (jsonDecode(existingJson) as List)
          .map((e) => PendingVerification.fromJson(e as Map<String, dynamic>))
          .toList();

      if (pending.isEmpty) return;

      debugPrint('Processing ${pending.length} pending verifications...');

      final results = <VerificationResult>[];
      final remaining = <PendingVerification>[];

      for (final item in pending) {
        try {
          final result = await _verifyWithCloud(item);
          results.add(result);

          if (result.needsCorrection) {
            // 发送纠错通知
            _verificationController.add(result);
          }
        } catch (e) {
          debugPrint('Verification failed for ${item.id}: $e');
          // 保留失败的项目以便重试
          remaining.add(item);
        }
      }

      // 更新待校验列表
      if (remaining.isEmpty) {
        await prefs.remove(_pendingVerificationKey);
      } else {
        await prefs.setString(
          _pendingVerificationKey,
          jsonEncode(remaining.map((e) => e.toJson()).toList()),
        );
      }

      debugPrint('Verification completed: ${results.length} processed, ${remaining.length} remaining');
    } catch (e) {
      debugPrint('Failed to process pending verifications: $e');
    }
  }

  /// 与云端进行校验
  Future<VerificationResult> _verifyWithCloud(PendingVerification item) async {
    switch (item.type) {
      case VerificationType.voiceRecognition:
        return await _verifyVoiceRecognition(item);
      case VerificationType.ocrRecognition:
        return await _verifyOcrRecognition(item);
      case VerificationType.categoryClassification:
        return await _verifyCategoryClassification(item);
      case VerificationType.smartCompletion:
        return await _verifySmartCompletion(item);
    }
  }

  /// 校验语音识别结果
  Future<VerificationResult> _verifyVoiceRecognition(PendingVerification item) async {
    try {
      // 如果有原始音频数据，发送到云端重新识别
      if (item.rawData != null) {
        final response = await _http.post('/ai/verify/voice', data: {
          'audio_base64': item.rawData,
          'local_result': item.localResult,
        });

        if (response.statusCode == 200) {
          final cloudResult = response.data['text'] as String;
          final cloudConfidence = (response.data['confidence'] as num).toDouble();

          // 比较本地和云端结果
          final localText = item.localResult['text'] as String;
          final localConfidence = (item.localResult['confidence'] as num?)?.toDouble() ?? 0;

          // 如果云端结果置信度明显更高，建议纠错
          if (cloudConfidence > localConfidence + 0.1 && cloudResult != localText) {
            return VerificationResult(
              id: item.id,
              type: item.type,
              needsCorrection: true,
              localResult: localText,
              cloudResult: cloudResult,
              localConfidence: localConfidence,
              cloudConfidence: cloudConfidence,
              correctionApplied: false,
              entityId: item.entityId,
              fieldPath: item.fieldPath,
            );
          }
        }
      }

      return VerificationResult(
        id: item.id,
        type: item.type,
        needsCorrection: false,
        localResult: item.localResult['text'] as String,
        localConfidence: (item.localResult['confidence'] as num?)?.toDouble() ?? 0,
      );
    } catch (e) {
      debugPrint('Voice verification failed: $e');
      rethrow;
    }
  }

  /// 校验OCR识别结果
  Future<VerificationResult> _verifyOcrRecognition(PendingVerification item) async {
    try {
      if (item.rawData != null) {
        final response = await _http.post('/ai/verify/ocr', data: {
          'image_base64': item.rawData,
          'local_result': item.localResult,
        });

        if (response.statusCode == 200) {
          final cloudResult = response.data as Map<String, dynamic>;
          final cloudAmount = cloudResult['amount'] as double?;
          final cloudMerchant = cloudResult['merchant'] as String?;
          final cloudConfidence = (cloudResult['confidence'] as num?)?.toDouble() ?? 0;

          final localAmount = item.localResult['amount'] as double?;
          final localMerchant = item.localResult['merchant'] as String?;
          final localConfidence = (item.localResult['confidence'] as num?)?.toDouble() ?? 0;

          // 检查金额差异（金额识别错误比较严重）
          final amountDiff = cloudAmount != null && localAmount != null
              ? (cloudAmount - localAmount).abs()
              : 0.0;

          if (amountDiff > 0.01 || // 金额有差异
              (cloudMerchant != localMerchant && cloudConfidence > localConfidence + 0.15)) {
            return VerificationResult(
              id: item.id,
              type: item.type,
              needsCorrection: true,
              localResult: '金额: $localAmount, 商户: $localMerchant',
              cloudResult: '金额: $cloudAmount, 商户: $cloudMerchant',
              localConfidence: localConfidence,
              cloudConfidence: cloudConfidence,
              correctionApplied: false,
              entityId: item.entityId,
              fieldPath: item.fieldPath,
              correctionData: {
                'amount': cloudAmount,
                'merchant': cloudMerchant,
              },
            );
          }
        }
      }

      return VerificationResult(
        id: item.id,
        type: item.type,
        needsCorrection: false,
        localResult: item.localResult.toString(),
        localConfidence: (item.localResult['confidence'] as num?)?.toDouble() ?? 0,
      );
    } catch (e) {
      debugPrint('OCR verification failed: $e');
      rethrow;
    }
  }

  /// 校验分类结果
  Future<VerificationResult> _verifyCategoryClassification(PendingVerification item) async {
    try {
      final response = await _http.post('/ai/verify/category', data: {
        'description': item.localResult['description'],
        'amount': item.localResult['amount'],
        'merchant': item.localResult['merchant'],
        'local_category_id': item.localResult['categoryId'],
      });

      if (response.statusCode == 200) {
        final cloudCategoryId = response.data['category_id'] as String;
        final cloudCategoryName = response.data['category_name'] as String;
        final cloudConfidence = (response.data['confidence'] as num).toDouble();

        final localCategoryId = item.localResult['categoryId'] as String;
        final localCategoryName = item.localResult['categoryName'] as String?;
        final localConfidence = (item.localResult['confidence'] as num?)?.toDouble() ?? 0;

        // 如果分类不同且云端置信度更高
        if (cloudCategoryId != localCategoryId && cloudConfidence > localConfidence + 0.1) {
          return VerificationResult(
            id: item.id,
            type: item.type,
            needsCorrection: true,
            localResult: localCategoryName ?? localCategoryId,
            cloudResult: cloudCategoryName,
            localConfidence: localConfidence,
            cloudConfidence: cloudConfidence,
            correctionApplied: false,
            entityId: item.entityId,
            fieldPath: 'category_id',
            correctionData: {
              'categoryId': cloudCategoryId,
              'categoryName': cloudCategoryName,
            },
          );
        }
      }

      return VerificationResult(
        id: item.id,
        type: item.type,
        needsCorrection: false,
        localResult: item.localResult['categoryName'] as String? ?? '',
        localConfidence: (item.localResult['confidence'] as num?)?.toDouble() ?? 0,
      );
    } catch (e) {
      debugPrint('Category verification failed: $e');
      rethrow;
    }
  }

  /// 校验智能补全结果
  Future<VerificationResult> _verifySmartCompletion(PendingVerification item) async {
    // 智能补全通常不需要校验，因为已经被用户确认
    return VerificationResult(
      id: item.id,
      type: item.type,
      needsCorrection: false,
      localResult: item.localResult.toString(),
      localConfidence: 1.0,
    );
  }

  /// 应用纠错
  Future<bool> applyCorrection(VerificationResult result) async {
    if (!result.needsCorrection || result.correctionApplied) {
      return false;
    }

    if (result.entityId == null || result.correctionData == null) {
      return false;
    }

    try {
      final db = await _db.database;

      // 根据纠错类型更新数据
      switch (result.type) {
        case VerificationType.voiceRecognition:
          // 更新交易备注
          await db.update(
            'transactions',
            {'note': result.cloudResult},
            where: 'id = ?',
            whereArgs: [result.entityId],
          );
          break;

        case VerificationType.ocrRecognition:
          // 更新交易金额和商户
          final updateData = <String, dynamic>{};
          if (result.correctionData!['amount'] != null) {
            updateData['amount'] = result.correctionData!['amount'];
          }
          if (result.correctionData!['merchant'] != null) {
            updateData['merchant'] = result.correctionData!['merchant'];
          }
          if (updateData.isNotEmpty) {
            await db.update(
              'transactions',
              updateData,
              where: 'id = ?',
              whereArgs: [result.entityId],
            );
          }
          break;

        case VerificationType.categoryClassification:
          // 更新分类
          await db.update(
            'transactions',
            {'category_id': result.correctionData!['categoryId']},
            where: 'id = ?',
            whereArgs: [result.entityId],
          );
          break;

        case VerificationType.smartCompletion:
          // 智能补全通常不需要纠错
          break;
      }

      debugPrint('Correction applied for ${result.entityId}');
      return true;
    } catch (e) {
      debugPrint('Failed to apply correction: $e');
      return false;
    }
  }

  /// 忽略纠错建议
  Future<void> ignoreCorrection(String resultId) async {
    // 记录用户忽略的纠错，用于学习
    debugPrint('Correction ignored: $resultId');
  }

  /// 获取待校验数量
  Future<int> getPendingCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingJson = prefs.getString(_pendingVerificationKey);

      if (existingJson == null) return 0;

      final pending = jsonDecode(existingJson) as List;
      return pending.length;
    } catch (e) {
      return 0;
    }
  }

  /// 清除所有待校验记录
  Future<void> clearPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingVerificationKey);
  }

  /// 释放资源
  void dispose() {
    _verificationController.close();
  }
}

/// 校验类型
enum VerificationType {
  voiceRecognition,
  ocrRecognition,
  categoryClassification,
  smartCompletion,
}

/// 待校验记录
class PendingVerification {
  final String id;
  final VerificationType type;
  final Map<String, dynamic> localResult;
  final String? rawData; // Base64编码的原始数据（音频/图片）
  final String? entityId; // 关联的实体ID（如交易ID）
  final String? fieldPath; // 需要纠错的字段路径
  final DateTime createdAt;

  const PendingVerification({
    required this.id,
    required this.type,
    required this.localResult,
    this.rawData,
    this.entityId,
    this.fieldPath,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'localResult': localResult,
    'rawData': rawData,
    'entityId': entityId,
    'fieldPath': fieldPath,
    'createdAt': createdAt.toIso8601String(),
  };

  factory PendingVerification.fromJson(Map<String, dynamic> json) {
    return PendingVerification(
      id: json['id'] as String,
      type: VerificationType.values.firstWhere(
        (e) => e.name == json['type'],
      ),
      localResult: json['localResult'] as Map<String, dynamic>,
      rawData: json['rawData'] as String?,
      entityId: json['entityId'] as String?,
      fieldPath: json['fieldPath'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

/// 校验结果
class VerificationResult {
  final String id;
  final VerificationType type;
  final bool needsCorrection;
  final String localResult;
  final String? cloudResult;
  final double localConfidence;
  final double? cloudConfidence;
  final bool correctionApplied;
  final String? entityId;
  final String? fieldPath;
  final Map<String, dynamic>? correctionData;

  const VerificationResult({
    required this.id,
    required this.type,
    required this.needsCorrection,
    required this.localResult,
    this.cloudResult,
    required this.localConfidence,
    this.cloudConfidence,
    this.correctionApplied = false,
    this.entityId,
    this.fieldPath,
    this.correctionData,
  });

  /// 置信度提升百分比
  double get confidenceImprovement {
    if (cloudConfidence == null) return 0;
    return ((cloudConfidence! - localConfidence) * 100);
  }

  /// 是否值得纠错（置信度提升超过10%）
  bool get isWorthCorrecting => confidenceImprovement > 10;
}

/// 纠错建议UI数据模型
class CorrectionSuggestion {
  final VerificationResult result;
  final String title;
  final String description;
  final String localValue;
  final String suggestedValue;

  const CorrectionSuggestion({
    required this.result,
    required this.title,
    required this.description,
    required this.localValue,
    required this.suggestedValue,
  });

  factory CorrectionSuggestion.fromResult(VerificationResult result) {
    String title;
    String description;

    switch (result.type) {
      case VerificationType.voiceRecognition:
        title = '语音识别纠错建议';
        description = '云端识别结果与本地不同，置信度更高';
        break;
      case VerificationType.ocrRecognition:
        title = '图片识别纠错建议';
        description = '云端识别到更准确的金额或商户信息';
        break;
      case VerificationType.categoryClassification:
        title = '分类纠错建议';
        description = '云端建议使用更合适的分类';
        break;
      case VerificationType.smartCompletion:
        title = '补全纠错建议';
        description = '云端建议修改自动补全的内容';
        break;
    }

    return CorrectionSuggestion(
      result: result,
      title: title,
      description: description,
      localValue: result.localResult,
      suggestedValue: result.cloudResult ?? '',
    );
  }
}
