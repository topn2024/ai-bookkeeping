import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {

  /// App Group 标识符（需要与 Share Extension 一致）
  private let appGroupId = "group.com.example.ai_bookkeeping"

  /// Flutter MethodChannel
  private var shareChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // 设置分享处理的 MethodChannel
    setupShareChannel()

    // 检查是否有来自 Share Extension 的待处理图片
    checkPendingSharedImages()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// 处理 URL Scheme 打开
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    // 处理来自 Share Extension 的 URL
    if url.scheme == "aibookkeeping" && url.host == "share" {
      checkPendingSharedImages()
      return true
    }
    return super.application(app, open: url, options: options)
  }

  /// 设置分享 MethodChannel
  private func setupShareChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }

    shareChannel = FlutterMethodChannel(
      name: "com.example.ai_bookkeeping/share",
      binaryMessenger: controller.binaryMessenger
    )

    shareChannel?.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "getSharedImages":
        let images = self?.getPendingSharedImages() ?? []
        result(images)

      case "clearSharedImages":
        self?.clearPendingSharedImages()
        result(true)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// 检查待处理的分享图片
  private func checkPendingSharedImages() {
    let images = getPendingSharedImages()
    if !images.isEmpty {
      // 通知 Flutter 有新的分享内容
      shareChannel?.invokeMethod("onSharedImages", arguments: [
        "type": "images",
        "paths": images
      ])
    }
  }

  /// 获取待处理的分享图片路径
  private func getPendingSharedImages() -> [String] {
    guard let userDefaults = UserDefaults(suiteName: appGroupId) else {
      return []
    }
    return userDefaults.stringArray(forKey: "pendingSharedImages") ?? []
  }

  /// 清除待处理的分享图片
  private func clearPendingSharedImages() {
    guard let userDefaults = UserDefaults(suiteName: appGroupId) else {
      return
    }

    // 删除图片文件
    let images = getPendingSharedImages()
    for path in images {
      try? FileManager.default.removeItem(atPath: path)
    }

    // 清除 UserDefaults
    userDefaults.removeObject(forKey: "pendingSharedImages")
    userDefaults.removeObject(forKey: "lastShareTimestamp")
    userDefaults.synchronize()
  }
}
