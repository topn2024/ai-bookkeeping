import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// 网络检测器
///
/// 检测网络状态和变化
class NetworkChecker {
  final Connectivity _connectivity = Connectivity();

  /// 检查是否在线
  Future<bool> isOnline() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.isNotEmpty && !results.contains(ConnectivityResult.none);
    } catch (e) {
      debugPrint('Network check failed: $e');
      return false;
    }
  }

  /// 检查是否有WiFi连接
  Future<bool> hasWifi() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.contains(ConnectivityResult.wifi);
    } catch (e) {
      debugPrint('WiFi check failed: $e');
      return false;
    }
  }

  /// 检查是否有移动网络连接
  Future<bool> hasMobile() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.contains(ConnectivityResult.mobile);
    } catch (e) {
      debugPrint('Mobile network check failed: $e');
      return false;
    }
  }

  /// 监听网络状态变化
  Stream<bool> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged.map((results) {
      return results.isNotEmpty && !results.contains(ConnectivityResult.none);
    });
  }

  /// 获取详细的连接类型
  Future<List<ConnectivityResult>> getConnectivityTypes() async {
    try {
      return await _connectivity.checkConnectivity();
    } catch (e) {
      debugPrint('Get connectivity types failed: $e');
      return [ConnectivityResult.none];
    }
  }
}
