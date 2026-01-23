package com.anthropic.webrtc_apm

import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * WebRTC APM Flutter Plugin
 *
 * 提供软件级的 AEC/NS/AGC 音频处理
 */
class WebrtcApmPlugin: FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private var audioProcessor: WebrtcAudioProcessor? = null

    companion object {
        private const val TAG = "WebrtcApmPlugin"
    }

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "webrtc_apm")
        channel.setMethodCallHandler(this)
        Log.d(TAG, "Plugin attached to engine")
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        Log.d(TAG, "Method called: ${call.method}")

        when (call.method) {
            "initialize" -> {
                val sampleRate = call.argument<Int>("sampleRate") ?: 16000
                val channels = call.argument<Int>("channels") ?: 1
                handleInitialize(sampleRate, channels, result)
            }
            "dispose" -> {
                handleDispose(result)
            }
            "setAecEnabled" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                handleSetAecEnabled(enabled, result)
            }
            "setAecSuppressionLevel" -> {
                val level = call.argument<Int>("level") ?: 2
                handleSetAecSuppressionLevel(level, result)
            }
            "setNsEnabled" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                handleSetNsEnabled(enabled, result)
            }
            "setNsSuppressionLevel" -> {
                val level = call.argument<Int>("level") ?: 2
                handleSetNsSuppressionLevel(level, result)
            }
            "setAgcEnabled" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                handleSetAgcEnabled(enabled, result)
            }
            "setAgcMode" -> {
                val mode = call.argument<Int>("mode") ?: 1
                handleSetAgcMode(mode, result)
            }
            "setAgcTargetLevel" -> {
                val targetLevelDbfs = call.argument<Int>("targetLevelDbfs") ?: 3
                handleSetAgcTargetLevel(targetLevelDbfs, result)
            }
            "processCaptureFrame" -> {
                val audioData = call.argument<ByteArray>("audioData")
                handleProcessCaptureFrame(audioData, result)
            }
            "processRenderFrame" -> {
                val audioData = call.argument<ByteArray>("audioData")
                handleProcessRenderFrame(audioData, result)
            }
            "getStatus" -> {
                handleGetStatus(result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun handleInitialize(sampleRate: Int, channels: Int, result: Result) {
        try {
            if (audioProcessor != null) {
                Log.d(TAG, "Already initialized, disposing old instance")
                audioProcessor?.dispose()
            }

            audioProcessor = WebrtcAudioProcessor()
            val success = audioProcessor?.initialize(sampleRate, channels) ?: false

            Log.d(TAG, "Initialize result: $success (sampleRate=$sampleRate, channels=$channels)")
            result.success(success)
        } catch (e: Exception) {
            Log.e(TAG, "Initialize failed", e)
            result.error("INIT_ERROR", e.message, null)
        }
    }

    private fun handleDispose(result: Result) {
        try {
            audioProcessor?.dispose()
            audioProcessor = null
            Log.d(TAG, "Disposed")
            result.success(null)
        } catch (e: Exception) {
            Log.e(TAG, "Dispose failed", e)
            result.error("DISPOSE_ERROR", e.message, null)
        }
    }

    private fun handleSetAecEnabled(enabled: Boolean, result: Result) {
        try {
            val success = audioProcessor?.setAecEnabled(enabled) ?: false
            Log.d(TAG, "AEC enabled: $enabled, result: $success")
            result.success(success)
        } catch (e: Exception) {
            Log.e(TAG, "setAecEnabled failed", e)
            result.error("AEC_ERROR", e.message, null)
        }
    }

    private fun handleSetAecSuppressionLevel(level: Int, result: Result) {
        try {
            val success = audioProcessor?.setAecSuppressionLevel(level) ?: false
            Log.d(TAG, "AEC suppression level: $level, result: $success")
            result.success(success)
        } catch (e: Exception) {
            Log.e(TAG, "setAecSuppressionLevel failed", e)
            result.error("AEC_ERROR", e.message, null)
        }
    }

    private fun handleSetNsEnabled(enabled: Boolean, result: Result) {
        try {
            val success = audioProcessor?.setNsEnabled(enabled) ?: false
            Log.d(TAG, "NS enabled: $enabled, result: $success")
            result.success(success)
        } catch (e: Exception) {
            Log.e(TAG, "setNsEnabled failed", e)
            result.error("NS_ERROR", e.message, null)
        }
    }

    private fun handleSetNsSuppressionLevel(level: Int, result: Result) {
        try {
            val success = audioProcessor?.setNsSuppressionLevel(level) ?: false
            Log.d(TAG, "NS suppression level: $level, result: $success")
            result.success(success)
        } catch (e: Exception) {
            Log.e(TAG, "setNsSuppressionLevel failed", e)
            result.error("NS_ERROR", e.message, null)
        }
    }

    private fun handleSetAgcEnabled(enabled: Boolean, result: Result) {
        try {
            val success = audioProcessor?.setAgcEnabled(enabled) ?: false
            Log.d(TAG, "AGC enabled: $enabled, result: $success")
            result.success(success)
        } catch (e: Exception) {
            Log.e(TAG, "setAgcEnabled failed", e)
            result.error("AGC_ERROR", e.message, null)
        }
    }

    private fun handleSetAgcMode(mode: Int, result: Result) {
        try {
            val success = audioProcessor?.setAgcMode(mode) ?: false
            Log.d(TAG, "AGC mode: $mode, result: $success")
            result.success(success)
        } catch (e: Exception) {
            Log.e(TAG, "setAgcMode failed", e)
            result.error("AGC_ERROR", e.message, null)
        }
    }

    private fun handleSetAgcTargetLevel(targetLevelDbfs: Int, result: Result) {
        try {
            val success = audioProcessor?.setAgcTargetLevel(targetLevelDbfs) ?: false
            Log.d(TAG, "AGC target level: $targetLevelDbfs, result: $success")
            result.success(success)
        } catch (e: Exception) {
            Log.e(TAG, "setAgcTargetLevel failed", e)
            result.error("AGC_ERROR", e.message, null)
        }
    }

    private fun handleProcessCaptureFrame(audioData: ByteArray?, result: Result) {
        if (audioData == null) {
            result.error("INVALID_INPUT", "Audio data is null", null)
            return
        }

        try {
            val processedData = audioProcessor?.processCaptureFrame(audioData)
            result.success(processedData)
        } catch (e: Exception) {
            Log.e(TAG, "processCaptureFrame failed", e)
            result.error("PROCESS_ERROR", e.message, null)
        }
    }

    private fun handleProcessRenderFrame(audioData: ByteArray?, result: Result) {
        if (audioData == null) {
            result.error("INVALID_INPUT", "Audio data is null", null)
            return
        }

        try {
            val success = audioProcessor?.processRenderFrame(audioData) ?: false
            result.success(success)
        } catch (e: Exception) {
            Log.e(TAG, "processRenderFrame failed", e)
            result.error("PROCESS_ERROR", e.message, null)
        }
    }

    private fun handleGetStatus(result: Result) {
        try {
            val status = audioProcessor?.getStatus() ?: mapOf(
                "initialized" to false
            )
            result.success(status)
        } catch (e: Exception) {
            Log.e(TAG, "getStatus failed", e)
            result.error("STATUS_ERROR", e.message, null)
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        audioProcessor?.dispose()
        audioProcessor = null
        Log.d(TAG, "Plugin detached from engine")
    }
}
