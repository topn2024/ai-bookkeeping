package com.example.ai_bookkeeping

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * 安全密钥存储
 *
 * 通过 JNI 从 Native 层获取密钥，避免在 Dart/Kotlin 代码中明文存储。
 */
class SecureKeyStore {
    companion object {
        private const val CHANNEL = "com.example.ai_bookkeeping/secure_keys"

        init {
            System.loadLibrary("secure_keys")
        }

        /**
         * 注册 Flutter MethodChannel
         */
        fun registerWith(flutterEngine: FlutterEngine) {
            val keyStore = SecureKeyStore()

            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
                when (call.method) {
                    "getAliyunAccessKeyId" -> {
                        result.success(keyStore.getAliyunAccessKeyId())
                    }
                    "getAliyunAccessKeySecret" -> {
                        result.success(keyStore.getAliyunAccessKeySecret())
                    }
                    "getAliyunAppKey" -> {
                        result.success(keyStore.getAliyunAppKey())
                    }
                    "getQwenApiKey" -> {
                        result.success(keyStore.getQwenApiKey())
                    }
                    "getAsrUrl" -> {
                        result.success(keyStore.getAsrUrl())
                    }
                    "getAsrRestUrl" -> {
                        result.success(keyStore.getAsrRestUrl())
                    }
                    "getTtsUrl" -> {
                        result.success(keyStore.getTtsUrl())
                    }
                    "getAllKeys" -> {
                        result.success(mapOf(
                            "accessKeyId" to keyStore.getAliyunAccessKeyId(),
                            "accessKeySecret" to keyStore.getAliyunAccessKeySecret(),
                            "appKey" to keyStore.getAliyunAppKey(),
                            "qwenApiKey" to keyStore.getQwenApiKey(),
                            "asrUrl" to keyStore.getAsrUrl(),
                            "asrRestUrl" to keyStore.getAsrRestUrl(),
                            "ttsUrl" to keyStore.getTtsUrl()
                        ))
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
        }
    }

    // Native 方法声明
    external fun getAliyunAccessKeyId(): String
    external fun getAliyunAccessKeySecret(): String
    external fun getAliyunAppKey(): String
    external fun getQwenApiKey(): String
    external fun getAsrUrl(): String
    external fun getAsrRestUrl(): String
    external fun getTtsUrl(): String
}
