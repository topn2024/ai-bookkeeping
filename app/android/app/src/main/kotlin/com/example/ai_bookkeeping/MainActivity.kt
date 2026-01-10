package com.example.ai_bookkeeping

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.Parcelable
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.example.ai_bookkeeping/bspatch"
        private const val SHARE_CHANNEL = "com.example.ai_bookkeeping/share"
        private const val SHARE_EVENT_CHANNEL = "com.example.ai_bookkeeping/share_events"
        private const val SCREEN_READER_CHANNEL = "com.example.ai_bookkeeping/screen_reader"
    }

    private var sharedImages: ArrayList<String>? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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
                else -> {
                    result.notImplemented()
                }
            }
        }

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
