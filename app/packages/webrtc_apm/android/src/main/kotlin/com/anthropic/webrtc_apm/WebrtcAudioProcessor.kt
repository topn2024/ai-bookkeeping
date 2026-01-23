package com.anthropic.webrtc_apm

import android.util.Log

/**
 * WebRTC 音频处理器
 *
 * 封装 WebRTC APM 的 JNI 调用
 */
class WebrtcAudioProcessor {

    companion object {
        private const val TAG = "WebrtcAudioProcessor"

        init {
            try {
                System.loadLibrary("webrtc_apm_jni")
                Log.d(TAG, "Native library loaded successfully")
            } catch (e: UnsatisfiedLinkError) {
                Log.e(TAG, "Failed to load native library: ${e.message}")
            }
        }
    }

    private var nativeHandle: Long = 0
    private var isInitialized = false

    private var aecEnabled = false
    private var nsEnabled = false
    private var agcEnabled = false
    private var aecSuppressionLevel = 2
    private var nsSuppressionLevel = 2
    private var agcMode = 1
    private var agcTargetLevel = 3

    /**
     * 初始化 APM
     */
    fun initialize(sampleRate: Int, channels: Int): Boolean {
        if (isInitialized) {
            Log.d(TAG, "Already initialized")
            return true
        }

        return try {
            nativeHandle = nativeCreate(sampleRate, channels)
            isInitialized = nativeHandle != 0L
            Log.d(TAG, "Initialize: handle=$nativeHandle, success=$isInitialized")
            isInitialized
        } catch (e: Exception) {
            Log.e(TAG, "Initialize failed", e)
            false
        }
    }

    /**
     * 释放资源
     */
    fun dispose() {
        if (!isInitialized) return

        try {
            nativeDestroy(nativeHandle)
            nativeHandle = 0
            isInitialized = false
            Log.d(TAG, "Disposed")
        } catch (e: Exception) {
            Log.e(TAG, "Dispose failed", e)
        }
    }

    /**
     * 启用/禁用 AEC
     */
    fun setAecEnabled(enabled: Boolean): Boolean {
        if (!isInitialized) return false

        return try {
            val result = nativeSetAecEnabled(nativeHandle, enabled)
            if (result) aecEnabled = enabled
            result
        } catch (e: Exception) {
            Log.e(TAG, "setAecEnabled failed", e)
            false
        }
    }

    /**
     * 设置 AEC 抑制级别
     */
    fun setAecSuppressionLevel(level: Int): Boolean {
        if (!isInitialized) return false

        return try {
            val result = nativeSetAecSuppressionLevel(nativeHandle, level)
            if (result) aecSuppressionLevel = level
            result
        } catch (e: Exception) {
            Log.e(TAG, "setAecSuppressionLevel failed", e)
            false
        }
    }

    /**
     * 启用/禁用 NS
     */
    fun setNsEnabled(enabled: Boolean): Boolean {
        if (!isInitialized) return false

        return try {
            val result = nativeSetNsEnabled(nativeHandle, enabled)
            if (result) nsEnabled = enabled
            result
        } catch (e: Exception) {
            Log.e(TAG, "setNsEnabled failed", e)
            false
        }
    }

    /**
     * 设置 NS 抑制级别
     */
    fun setNsSuppressionLevel(level: Int): Boolean {
        if (!isInitialized) return false

        return try {
            val result = nativeSetNsSuppressionLevel(nativeHandle, level)
            if (result) nsSuppressionLevel = level
            result
        } catch (e: Exception) {
            Log.e(TAG, "setNsSuppressionLevel failed", e)
            false
        }
    }

    /**
     * 启用/禁用 AGC
     */
    fun setAgcEnabled(enabled: Boolean): Boolean {
        if (!isInitialized) return false

        return try {
            val result = nativeSetAgcEnabled(nativeHandle, enabled)
            if (result) agcEnabled = enabled
            result
        } catch (e: Exception) {
            Log.e(TAG, "setAgcEnabled failed", e)
            false
        }
    }

    /**
     * 设置 AGC 模式
     */
    fun setAgcMode(mode: Int): Boolean {
        if (!isInitialized) return false

        return try {
            val result = nativeSetAgcMode(nativeHandle, mode)
            if (result) agcMode = mode
            result
        } catch (e: Exception) {
            Log.e(TAG, "setAgcMode failed", e)
            false
        }
    }

    /**
     * 设置 AGC 目标电平
     */
    fun setAgcTargetLevel(targetLevelDbfs: Int): Boolean {
        if (!isInitialized) return false

        return try {
            val result = nativeSetAgcTargetLevel(nativeHandle, targetLevelDbfs)
            if (result) agcTargetLevel = targetLevelDbfs
            result
        } catch (e: Exception) {
            Log.e(TAG, "setAgcTargetLevel failed", e)
            false
        }
    }

    /**
     * 处理捕获的音频帧
     */
    fun processCaptureFrame(audioData: ByteArray): ByteArray? {
        if (!isInitialized) return audioData

        return try {
            nativeProcessCaptureFrame(nativeHandle, audioData)
        } catch (e: Exception) {
            Log.e(TAG, "processCaptureFrame failed", e)
            audioData
        }
    }

    /**
     * 处理渲染的音频帧（TTS 参考信号）
     */
    fun processRenderFrame(audioData: ByteArray): Boolean {
        if (!isInitialized) return false

        return try {
            nativeProcessRenderFrame(nativeHandle, audioData)
        } catch (e: Exception) {
            Log.e(TAG, "processRenderFrame failed", e)
            false
        }
    }

    /**
     * 获取状态
     */
    fun getStatus(): Map<String, Any> {
        return mapOf(
            "initialized" to isInitialized,
            "aecEnabled" to aecEnabled,
            "nsEnabled" to nsEnabled,
            "agcEnabled" to agcEnabled,
            "aecSuppressionLevel" to aecSuppressionLevel,
            "nsSuppressionLevel" to nsSuppressionLevel,
            "agcMode" to agcMode,
            "agcTargetLevel" to agcTargetLevel
        )
    }

    // Native methods
    private external fun nativeCreate(sampleRate: Int, channels: Int): Long
    private external fun nativeDestroy(handle: Long)
    private external fun nativeSetAecEnabled(handle: Long, enabled: Boolean): Boolean
    private external fun nativeSetAecSuppressionLevel(handle: Long, level: Int): Boolean
    private external fun nativeSetNsEnabled(handle: Long, enabled: Boolean): Boolean
    private external fun nativeSetNsSuppressionLevel(handle: Long, level: Int): Boolean
    private external fun nativeSetAgcEnabled(handle: Long, enabled: Boolean): Boolean
    private external fun nativeSetAgcMode(handle: Long, mode: Int): Boolean
    private external fun nativeSetAgcTargetLevel(handle: Long, targetLevelDbfs: Int): Boolean
    private external fun nativeProcessCaptureFrame(handle: Long, audioData: ByteArray): ByteArray?
    private external fun nativeProcessRenderFrame(handle: Long, audioData: ByteArray): Boolean
}
