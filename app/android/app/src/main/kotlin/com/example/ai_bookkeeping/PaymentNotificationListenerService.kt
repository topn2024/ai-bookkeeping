package com.example.ai_bookkeeping

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.util.regex.Pattern

/**
 * 支付通知监听服务
 *
 * 监听微信、支付宝等支付应用的通知，自动识别消费金额
 */
class PaymentNotificationListenerService : NotificationListenerService() {

    companion object {
        private const val TAG = "PaymentNotification"
        private const val CHANNEL_NAME = "com.bookkeeping.ai/payment_notification"

        // 支持的支付应用包名
        private val SUPPORTED_PACKAGES = setOf(
            "com.tencent.mm",           // 微信
            "com.eg.android.AlipayGphone", // 支付宝
            "com.unionpay",             // 云闪付
            "com.chinamworld.main"      // 中国银行
        )

        // 金额提取正则
        private val AMOUNT_PATTERNS = listOf(
            Pattern.compile("([\\d,]+\\.?\\d*)元"),
            Pattern.compile("¥([\\d,]+\\.?\\d*)"),
            Pattern.compile("支付([\\d,]+\\.?\\d*)"),
            Pattern.compile("消费([\\d,]+\\.?\\d*)"),
            Pattern.compile("收款([\\d,]+\\.?\\d*)")
        )

        // 商户名提取正则
        private val MERCHANT_PATTERNS = listOf(
            Pattern.compile("在(.+?)消费"),
            Pattern.compile("向(.+?)付款"),
            Pattern.compile("收到(.+?)的付款"),
            Pattern.compile("(.+?)支付成功")
        )

        // 事件流单例
        var eventSink: EventChannel.EventSink? = null
        var instance: PaymentNotificationListenerService? = null
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        Log.d(TAG, "PaymentNotificationListenerService created")
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
        Log.d(TAG, "PaymentNotificationListenerService destroyed")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        sbn ?: return

        val packageName = sbn.packageName
        if (packageName !in SUPPORTED_PACKAGES) return

        val notification = sbn.notification ?: return
        val extras = notification.extras ?: return

        val title = extras.getString(Notification.EXTRA_TITLE) ?: ""
        val text = extras.getString(Notification.EXTRA_TEXT) ?: ""
        val content = "$title $text"

        Log.d(TAG, "Payment notification from $packageName: $content")

        // 过滤非支付通知
        if (!isPaymentNotification(content)) return

        // 提取支付信息
        val amount = extractAmount(content)
        val merchant = extractMerchant(content)

        if (amount != null) {
            val paymentInfo = JSONObject().apply {
                put("package", packageName)
                put("amount", amount)
                put("merchant", merchant ?: "")
                put("title", title)
                put("text", text)
                put("timestamp", System.currentTimeMillis())
                put("appName", getAppName(packageName))
            }

            Log.d(TAG, "Payment detected: $paymentInfo")

            // 发送到 Flutter
            eventSink?.success(paymentInfo.toString())
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        // 通知移除时不需要处理
    }

    /**
     * 判断是否为支付通知
     */
    private fun isPaymentNotification(content: String): Boolean {
        val paymentKeywords = listOf(
            "支付成功", "付款成功", "消费", "收款", "转账",
            "扣款", "已支付", "交易成功"
        )
        val excludeKeywords = listOf(
            "红包", "优惠券", "积分", "签到", "任务"
        )

        val hasPaymentKeyword = paymentKeywords.any { content.contains(it) }
        val hasExcludeKeyword = excludeKeywords.any { content.contains(it) }

        return hasPaymentKeyword && !hasExcludeKeyword
    }

    /**
     * 提取金额
     */
    private fun extractAmount(content: String): Double? {
        for (pattern in AMOUNT_PATTERNS) {
            val matcher = pattern.matcher(content)
            if (matcher.find()) {
                val amountStr = matcher.group(1)?.replace(",", "") ?: continue
                return amountStr.toDoubleOrNull()
            }
        }
        return null
    }

    /**
     * 提取商户名
     */
    private fun extractMerchant(content: String): String? {
        for (pattern in MERCHANT_PATTERNS) {
            val matcher = pattern.matcher(content)
            if (matcher.find()) {
                return matcher.group(1)?.trim()
            }
        }
        return null
    }

    /**
     * 获取应用名称
     */
    private fun getAppName(packageName: String): String {
        return when (packageName) {
            "com.tencent.mm" -> "微信"
            "com.eg.android.AlipayGphone" -> "支付宝"
            "com.unionpay" -> "云闪付"
            "com.chinamworld.main" -> "中国银行"
            else -> "未知"
        }
    }
}
