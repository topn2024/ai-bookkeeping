package com.example.ai_bookkeeping

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.Parcelable
import android.provider.Settings
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {

    private var gestureWakeHandler: GestureWakeHandler? = null
    companion object {
        private const val CHANNEL = "com.example.ai_bookkeeping/bspatch"
        private const val SHARE_CHANNEL = "com.example.ai_bookkeeping/share"
        private const val SHARE_EVENT_CHANNEL = "com.example.ai_bookkeeping/share_events"
        private const val SCREEN_READER_CHANNEL = "com.example.ai_bookkeeping/screen_reader"
        private const val DEEP_LINK_CHANNEL = "com.example.ai_bookkeeping/deep_link"
        private const val DEEP_LINK_EVENT_CHANNEL = "com.example.ai_bookkeeping/deep_link_events"
    }

    private var sharedImages: ArrayList<String>? = null
    private var eventSink: EventChannel.EventSink? = null
    private var deepLinkEventSink: EventChannel.EventSink? = null
    private var pendingDeepLink: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 初始化手势唤醒处理器
        gestureWakeHandler = GestureWakeHandler(this)
        gestureWakeHandler?.registerWith(flutterEngine)

        // 注册安全密钥存储
        SecureKeyStore.registerWith(flutterEngine)

        // 处理分享接收的MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHARE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSharedImages" -> {
                    result.success(sharedImages ?: emptyList<String>())
                    // 清除已处理的分享内容
                    sharedImages = null
                }
                "clearSharedImages" -> {
                    sharedImages = null
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // EventChannel用于实时通知分享事件
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SHARE_EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    // 如果已经有待处理的分享内容，立即通知
                    sharedImages?.let { images ->
                        if (images.isNotEmpty()) {
                            eventSink?.success(mapOf(
                                "type" to "images",
                                "paths" to images
                            ))
                        }
                    }
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )

        // 屏幕阅读器 MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCREEN_READER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAccessibilityEnabled" -> {
                    result.success(ScreenReaderService.isServiceEnabled)
                }
                "openAccessibilitySettings" -> {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    startActivity(intent)
                    result.success(true)
                }
                "readScreen" -> {
                    val service = ScreenReaderService.instance
                    if (service == null) {
                        result.error("SERVICE_NOT_ENABLED", "无障碍服务未启用", null)
                        return@setMethodCallHandler
                    }

                    val content = service.readScreenContent()
                    result.success(mapOf(
                        "packageName" to content.packageName,
                        "texts" to content.texts,
                        "timestamp" to content.timestamp
                    ))
                }
                "parseBillInfo" -> {
                    val service = ScreenReaderService.instance
                    if (service == null) {
                        result.error("SERVICE_NOT_ENABLED", "无障碍服务未启用", null)
                        return@setMethodCallHandler
                    }

                    val content = service.readScreenContent()
                    val billInfo = service.parseBillInfo(content)

                    if (billInfo != null) {
                        result.success(billInfo.toMap())
                    } else {
                        result.success(null)
                    }
                }
                "parseMultipleBills" -> {
                    val service = ScreenReaderService.instance
                    if (service == null) {
                        result.error("SERVICE_NOT_ENABLED", "无障碍服务未启用", null)
                        return@setMethodCallHandler
                    }

                    val content = service.readScreenContent()
                    val bills = service.parseMultipleBills(content)

                    result.success(bills.map { it.toMap() })
                }
                "takeScreenshot" -> {
                    val service = ScreenReaderService.instance
                    if (service == null) {
                        result.error("SERVICE_NOT_ENABLED", "无障碍服务未启用", null)
                        return@setMethodCallHandler
                    }

                    service.takeScreenshot { path ->
                        runOnUiThread {
                            result.success(path)
                        }
                    }
                }
                // ==================== 自动化功能 ====================
                "launchApp" -> {
                    val service = ScreenReaderService.instance
                    if (service == null) {
                        result.error("SERVICE_NOT_ENABLED", "无障碍服务未启用", null)
                        return@setMethodCallHandler
                    }

                    val packageName = call.argument<String>("packageName")
                    if (packageName.isNullOrEmpty()) {
                        result.error("INVALID_ARGS", "packageName is required", null)
                        return@setMethodCallHandler
                    }

                    val success = service.launchApp(packageName)
                    result.success(success)
                }
                "getCurrentPackageName" -> {
                    val service = ScreenReaderService.instance
                    if (service == null) {
                        result.error("SERVICE_NOT_ENABLED", "无障碍服务未启用", null)
                        return@setMethodCallHandler
                    }

                    result.success(service.getCurrentPackageName())
                }
                "clickElement" -> {
                    val service = ScreenReaderService.instance
                    if (service == null) {
                        result.error("SERVICE_NOT_ENABLED", "无障碍服务未启用", null)
                        return@setMethodCallHandler
                    }

                    val text = call.argument<String>("text")
                    if (text.isNullOrEmpty()) {
                        result.error("INVALID_ARGS", "text is required", null)
                        return@setMethodCallHandler
                    }

                    Thread {
                        val success = service.clickElementByText(text)
                        runOnUiThread {
                            result.success(success)
                        }
                    }.start()
                }
                "clickElementById" -> {
                    val service = ScreenReaderService.instance
                    if (service == null) {
                        result.error("SERVICE_NOT_ENABLED", "无障碍服务未启用", null)
                        return@setMethodCallHandler
                    }

                    val viewId = call.argument<String>("viewId")
                    if (viewId.isNullOrEmpty()) {
                        result.error("INVALID_ARGS", "viewId is required", null)
                        return@setMethodCallHandler
                    }

                    Thread {
                        val success = service.clickElementById(viewId)
                        runOnUiThread {
                            result.success(success)
                        }
                    }.start()
                }
                "performClick" -> {
                    val service = ScreenReaderService.instance
                    if (service == null) {
                        result.error("SERVICE_NOT_ENABLED", "无障碍服务未启用", null)
                        return@setMethodCallHandler
                    }

                    val x = call.argument<Double>("x")?.toFloat()
                    val y = call.argument<Double>("y")?.toFloat()
                    if (x == null || y == null) {
                        result.error("INVALID_ARGS", "x and y are required", null)
                        return@setMethodCallHandler
                    }

                    Thread {
                        val success = service.performClick(x, y)
                        runOnUiThread {
                            result.success(success)
                        }
                    }.start()
                }
                "performSwipe" -> {
                    val service = ScreenReaderService.instance
                    if (service == null) {
                        result.error("SERVICE_NOT_ENABLED", "无障碍服务未启用", null)
                        return@setMethodCallHandler
                    }

                    val startX = call.argument<Double>("startX")?.toFloat()
                    val startY = call.argument<Double>("startY")?.toFloat()
                    val endX = call.argument<Double>("endX")?.toFloat()
                    val endY = call.argument<Double>("endY")?.toFloat()
                    val duration = call.argument<Int>("duration")?.toLong() ?: 300L

                    if (startX == null || startY == null || endX == null || endY == null) {
                        result.error("INVALID_ARGS", "startX, startY, endX, endY are required", null)
                        return@setMethodCallHandler
                    }

                    Thread {
                        val success = service.performSwipe(startX, startY, endX, endY, duration)
                        runOnUiThread {
                            result.success(success)
                        }
                    }.start()
                }
                "scrollDown" -> {
                    val service = ScreenReaderService.instance
                    if (service == null) {
                        result.error("SERVICE_NOT_ENABLED", "无障碍服务未启用", null)
                        return@setMethodCallHandler
                    }

                    val screenHeight = call.argument<Int>("screenHeight") ?: 2000

                    Thread {
                        val success = service.scrollDown(screenHeight)
                        runOnUiThread {
                            result.success(success)
                        }
                    }.start()
                }
                "scrollUp" -> {
                    val service = ScreenReaderService.instance
                    if (service == null) {
                        result.error("SERVICE_NOT_ENABLED", "无障碍服务未启用", null)
                        return@setMethodCallHandler
                    }

                    val screenHeight = call.argument<Int>("screenHeight") ?: 2000

                    Thread {
                        val success = service.scrollUp(screenHeight)
                        runOnUiThread {
                            result.success(success)
                        }
                    }.start()
                }
                "waitForElement" -> {
                    val service = ScreenReaderService.instance
                    if (service == null) {
                        result.error("SERVICE_NOT_ENABLED", "无障碍服务未启用", null)
                        return@setMethodCallHandler
                    }

                    val text = call.argument<String>("text")
                    val timeout = call.argument<Int>("timeout")?.toLong() ?: 5000L

                    if (text.isNullOrEmpty()) {
                        result.error("INVALID_ARGS", "text is required", null)
                        return@setMethodCallHandler
                    }

                    Thread {
                        val found = service.waitForElement(text, timeout)
                        runOnUiThread {
                            result.success(found)
                        }
                    }.start()
                }
                "waitForApp" -> {
                    val service = ScreenReaderService.instance
                    if (service == null) {
                        result.error("SERVICE_NOT_ENABLED", "无障碍服务未启用", null)
                        return@setMethodCallHandler
                    }

                    val packageName = call.argument<String>("packageName")
                    val timeout = call.argument<Int>("timeout")?.toLong() ?: 5000L

                    if (packageName.isNullOrEmpty()) {
                        result.error("INVALID_ARGS", "packageName is required", null)
                        return@setMethodCallHandler
                    }

                    Thread {
                        val found = service.waitForApp(packageName, timeout)
                        runOnUiThread {
                            result.success(found)
                        }
                    }.start()
                }
                "elementExists" -> {
                    val service = ScreenReaderService.instance
                    if (service == null) {
                        result.error("SERVICE_NOT_ENABLED", "无障碍服务未启用", null)
                        return@setMethodCallHandler
                    }

                    val text = call.argument<String>("text")
                    if (text.isNullOrEmpty()) {
                        result.error("INVALID_ARGS", "text is required", null)
                        return@setMethodCallHandler
                    }

                    result.success(service.elementExists(text))
                }
                "performBack" -> {
                    val service = ScreenReaderService.instance
                    if (service == null) {
                        result.error("SERVICE_NOT_ENABLED", "无障碍服务未启用", null)
                        return@setMethodCallHandler
                    }

                    result.success(service.performBack())
                }
                "performHome" -> {
                    val service = ScreenReaderService.instance
                    if (service == null) {
                        result.error("SERVICE_NOT_ENABLED", "无障碍服务未启用", null)
                        return@setMethodCallHandler
                    }

                    result.success(service.performHome())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // 深度链接 MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEEP_LINK_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialLink" -> {
                    result.success(pendingDeepLink)
                    pendingDeepLink = null
                }
                "clearPendingLink" -> {
                    pendingDeepLink = null
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // 深度链接 EventChannel
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, DEEP_LINK_EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    deepLinkEventSink = events
                    // 如果有待处理的深度链接，立即发送
                    pendingDeepLink?.let { link ->
                        deepLinkEventSink?.success(link)
                    }
                }

                override fun onCancel(arguments: Any?) {
                    deepLinkEventSink = null
                }
            }
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "applyPatch" -> {
                    val patchPath = call.argument<String>("patch")
                    val outputPath = call.argument<String>("output")
                    val expectedMd5 = call.argument<String>("expectedMd5")

                    if (patchPath == null || outputPath == null) {
                        result.error("INVALID_ARGS", "patch and output paths are required", null)
                        return@setMethodCallHandler
                    }

                    // Run patch in background thread
                    Thread {
                        val patchResult = BsPatchHelper.applyPatchWithVerification(
                            context = applicationContext,
                            patchPath = patchPath,
                            outputPath = outputPath,
                            expectedMd5 = expectedMd5
                        )

                        runOnUiThread {
                            if (patchResult.success) {
                                result.success(mapOf(
                                    "success" to true,
                                    "outputPath" to patchResult.outputPath
                                ))
                            } else {
                                result.success(mapOf(
                                    "success" to false,
                                    "error" to patchResult.errorMessage
                                ))
                            }
                        }
                    }.start()
                }

                "getCurrentApkPath" -> {
                    val apkPath = BsPatchHelper.getCurrentApkPath(applicationContext)
                    result.success(apkPath)
                }

                "calculateMd5" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath == null) {
                        result.error("INVALID_ARGS", "filePath is required", null)
                        return@setMethodCallHandler
                    }

                    // Run MD5 calculation in background
                    Thread {
                        val md5 = BsPatchHelper.calculateMd5(filePath)
                        runOnUiThread {
                            result.success(md5)
                        }
                    }.start()
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleShareIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleShareIntent(intent)
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        gestureWakeHandler?.onKeyDown(keyCode, event)
        return super.onKeyDown(keyCode, event)
    }

    override fun onKeyUp(keyCode: Int, event: KeyEvent?): Boolean {
        gestureWakeHandler?.onKeyUp(keyCode, event)
        return super.onKeyUp(keyCode, event)
    }

    override fun onDestroy() {
        gestureWakeHandler?.dispose()
        super.onDestroy()
    }

    private fun handleShareIntent(intent: Intent?) {
        if (intent == null) return

        when (intent.action) {
            Intent.ACTION_SEND -> {
                if (intent.type?.startsWith("image/") == true) {
                    handleSendImage(intent)
                }
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                if (intent.type?.startsWith("image/") == true) {
                    handleSendMultipleImages(intent)
                }
            }
            Intent.ACTION_VIEW -> {
                handleDeepLink(intent)
            }
        }
    }

    /**
     * 处理深度链接
     */
    private fun handleDeepLink(intent: Intent) {
        val uri = intent.data ?: return

        // 检查是否是我们的深度链接
        if (uri.scheme == "aibook") {
            val deepLink = uri.toString()

            // 如果 Flutter 已经就绪，直接发送事件
            if (deepLinkEventSink != null) {
                deepLinkEventSink?.success(deepLink)
            } else {
                // 否则保存待处理的深度链接
                pendingDeepLink = deepLink
            }
        }
    }

    private fun handleSendImage(intent: Intent) {
        (intent.getParcelableExtra<Parcelable>(Intent.EXTRA_STREAM) as? Uri)?.let { imageUri ->
            val imagePath = copyUriToCache(imageUri)
            if (imagePath != null) {
                sharedImages = arrayListOf(imagePath)
                notifyFlutter()
            }
        }
    }

    private fun handleSendMultipleImages(intent: Intent) {
        intent.getParcelableArrayListExtra<Parcelable>(Intent.EXTRA_STREAM)?.let { imageUris ->
            val paths = arrayListOf<String>()
            for (uri in imageUris) {
                if (uri is Uri) {
                    val imagePath = copyUriToCache(uri)
                    if (imagePath != null) {
                        paths.add(imagePath)
                    }
                }
            }
            if (paths.isNotEmpty()) {
                sharedImages = paths
                notifyFlutter()
            }
        }
    }

    /**
     * 将Uri内容复制到应用缓存目录
     * 这样Flutter可以直接访问文件
     */
    private fun copyUriToCache(uri: Uri): String? {
        return try {
            val inputStream = contentResolver.openInputStream(uri) ?: return null
            val fileName = "shared_image_${System.currentTimeMillis()}.jpg"
            val cacheDir = File(cacheDir, "shared_images")
            if (!cacheDir.exists()) {
                cacheDir.mkdirs()
            }
            val outputFile = File(cacheDir, fileName)
            FileOutputStream(outputFile).use { outputStream ->
                inputStream.copyTo(outputStream)
            }
            inputStream.close()
            outputFile.absolutePath
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    /**
     * 通知Flutter有新的分享内容
     */
    private fun notifyFlutter() {
        sharedImages?.let { images ->
            eventSink?.success(mapOf(
                "type" to "images",
                "paths" to images
            ))
        }
    }
}
