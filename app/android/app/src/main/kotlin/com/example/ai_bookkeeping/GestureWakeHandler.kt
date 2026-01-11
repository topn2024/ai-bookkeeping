package com.example.ai_bookkeeping

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.KeyEvent
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.engine.FlutterEngine
import kotlin.math.sqrt

/**
 * 手势唤醒处理器
 *
 * 处理需要原生实现的手势:
 * - 双击背面 (使用加速度传感器检测)
 * - 长按音量键
 */
class GestureWakeHandler(private val context: Context) : SensorEventListener {

    companion object {
        private const val TAG = "GestureWakeHandler"
        private const val CHANNEL_NAME = "com.example.ai_bookkeeping/gesture_wake"
        private const val EVENT_CHANNEL_NAME = "com.example.ai_bookkeeping/gesture_wake_events"

        // 双击背面检测参数
        private const val TAP_THRESHOLD = 15.0f       // 敲击加速度阈值
        private const val TAP_WINDOW_MS = 500L        // 双击时间窗口
        private const val TAP_COOLDOWN_MS = 1000L     // 冷却时间

        // 音量键长按检测参数
        private const val VOLUME_LONG_PRESS_MS = 800L // 长按时间阈值
    }

    private var sensorManager: SensorManager? = null
    private var accelerometer: Sensor? = null
    private var eventSink: EventChannel.EventSink? = null

    // 双击检测状态
    private var lastTapTime = 0L
    private var tapCount = 0
    private var lastEventTime = 0L
    private var isDoubleTapEnabled = false

    // 音量键长按检测状态
    private var volumeKeyDownTime = 0L
    private var isVolumeKeyDown = false
    private var isVolumeLongPressEnabled = false
    private val handler = Handler(Looper.getMainLooper())

    private val volumeLongPressRunnable = Runnable {
        if (isVolumeKeyDown && isVolumeLongPressEnabled) {
            Log.d(TAG, "Volume long press detected")
            eventSink?.success("volumeLongPress")
            isVolumeKeyDown = false
        }
    }

    /**
     * 注册 Flutter 通道
     */
    fun registerWith(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startGestureDetection" -> {
                    isDoubleTapEnabled = call.argument<Boolean>("doubleTapBack") ?: false
                    isVolumeLongPressEnabled = call.argument<Boolean>("volumeLongPress") ?: false

                    if (isDoubleTapEnabled) {
                        startTapDetection()
                    }
                    result.success(true)
                }
                "stopGestureDetection" -> {
                    stopTapDetection()
                    isDoubleTapEnabled = false
                    isVolumeLongPressEnabled = false
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            EVENT_CHANNEL_NAME
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    /**
     * 开始敲击检测
     */
    private fun startTapDetection() {
        if (sensorManager == null) {
            sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
            accelerometer = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        }

        accelerometer?.let {
            sensorManager?.registerListener(
                this,
                it,
                SensorManager.SENSOR_DELAY_GAME
            )
            Log.d(TAG, "Tap detection started")
        }
    }

    /**
     * 停止敲击检测
     */
    private fun stopTapDetection() {
        sensorManager?.unregisterListener(this)
        Log.d(TAG, "Tap detection stopped")
    }

    override fun onSensorChanged(event: SensorEvent?) {
        event ?: return
        if (event.sensor.type != Sensor.TYPE_ACCELEROMETER) return

        val currentTime = System.currentTimeMillis()

        // 防止处理过于频繁
        if (currentTime - lastEventTime < 50) return
        lastEventTime = currentTime

        // 计算加速度变化
        val x = event.values[0]
        val y = event.values[1]
        val z = event.values[2]

        val magnitude = sqrt(x * x + y * y + z * z)

        // 检测敲击（加速度突然增大）
        if (magnitude > TAP_THRESHOLD) {
            if (currentTime - lastTapTime < TAP_WINDOW_MS) {
                // 在时间窗口内检测到第二次敲击
                tapCount++
                if (tapCount >= 2) {
                    // 检测到双击
                    if (isDoubleTapEnabled && currentTime - lastTapTime > TAP_COOLDOWN_MS) {
                        Log.d(TAG, "Double tap back detected")
                        eventSink?.success("doubleTapBack")
                    }
                    tapCount = 0
                }
            } else {
                // 开始新的敲击序列
                tapCount = 1
            }
            lastTapTime = currentTime
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // 不需要处理
    }

    /**
     * 处理按键事件 (从 Activity 调用)
     */
    fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (!isVolumeLongPressEnabled) return false

        when (keyCode) {
            KeyEvent.KEYCODE_VOLUME_UP, KeyEvent.KEYCODE_VOLUME_DOWN -> {
                if (!isVolumeKeyDown) {
                    isVolumeKeyDown = true
                    volumeKeyDownTime = System.currentTimeMillis()
                    handler.postDelayed(volumeLongPressRunnable, VOLUME_LONG_PRESS_MS)
                }
                return false // 不阻止正常音量调节
            }
        }
        return false
    }

    /**
     * 处理按键释放事件 (从 Activity 调用)
     */
    fun onKeyUp(keyCode: Int, event: KeyEvent?): Boolean {
        when (keyCode) {
            KeyEvent.KEYCODE_VOLUME_UP, KeyEvent.KEYCODE_VOLUME_DOWN -> {
                isVolumeKeyDown = false
                handler.removeCallbacks(volumeLongPressRunnable)
                return false
            }
        }
        return false
    }

    /**
     * 释放资源
     */
    fun dispose() {
        stopTapDetection()
        handler.removeCallbacks(volumeLongPressRunnable)
        eventSink = null
    }
}
