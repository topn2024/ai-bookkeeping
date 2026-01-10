package com.example.ai_bookkeeping

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.graphics.Bitmap
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.Display
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.Executor

/**
 * 无障碍服务 - 屏幕内容读取器
 *
 * 用于读取当前屏幕上的文本内容，支持：
 * - 读取微信/支付宝账单页面的交易信息
 * - 截取当前屏幕截图
 * - 提取页面上的金额、商户、时间等信息
 *
 * 注意：此服务需要用户手动在系统设置中启用无障碍权限
 */
class ScreenReaderService : AccessibilityService() {

    companion object {
        private const val TAG = "ScreenReaderService"

        // 服务状态
        var isServiceEnabled = false
            private set

        // 单例实例
        var instance: ScreenReaderService? = null
            private set

        // 支持的应用包名
        private val supportedApps = setOf(
            "com.tencent.mm",           // 微信
            "com.eg.android.AlipayGphone", // 支付宝
            "com.unionpay",             // 云闪付
            "com.chinamworld.bocmbci",  // 中国银行
            "com.icbc",                 // 工商银行
            "com.ccb.app",              // 建设银行
            "com.abchina.abc",          // 农业银行
        )

        // 账单相关关键词
        private val billKeywords = listOf(
            "账单详情", "交易详情", "支付详情", "转账详情",
            "消费", "支出", "收入", "转账", "红包",
            "付款", "收款", "退款"
        )

        // 金额正则表达式
        private val amountPattern = Regex("""[¥￥]?\s*(\d+(?:\.\d{1,2})?)\s*元?""")

        // 时间正则表达式
        private val timePattern = Regex("""(\d{4}[-/年]\d{1,2}[-/月]\d{1,2}日?\s*\d{1,2}:\d{2}(?::\d{2})?)""")
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        isServiceEnabled = true

        // 配置服务信息
        val info = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                    AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                    AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
            notificationTimeout = 100
        }
        serviceInfo = info
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // 目前不主动处理事件，只在用户请求时读取屏幕
    }

    override fun onInterrupt() {
        // 服务被中断
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        isServiceEnabled = false
    }

    /**
     * 读取当前屏幕内容
     * 返回提取的文本信息
     */
    fun readScreenContent(): ScreenContent {
        val rootNode = rootInActiveWindow ?: return ScreenContent.empty()

        val packageName = rootNode.packageName?.toString() ?: ""
        val texts = mutableListOf<String>()
        val nodes = mutableListOf<NodeInfo>()

        // 递归提取所有文本
        extractText(rootNode, texts, nodes)

        rootNode.recycle()

        return ScreenContent(
            packageName = packageName,
            texts = texts,
            nodes = nodes,
            timestamp = System.currentTimeMillis()
        )
    }

    /**
     * 递归提取节点文本
     */
    private fun extractText(
        node: AccessibilityNodeInfo,
        texts: MutableList<String>,
        nodes: MutableList<NodeInfo>,
        depth: Int = 0
    ) {
        // 提取当前节点文本
        val text = node.text?.toString()?.trim()
        val contentDesc = node.contentDescription?.toString()?.trim()

        if (!text.isNullOrEmpty()) {
            texts.add(text)
            nodes.add(NodeInfo(
                text = text,
                className = node.className?.toString() ?: "",
                viewId = node.viewIdResourceName ?: "",
                depth = depth
            ))
        }

        if (!contentDesc.isNullOrEmpty() && contentDesc != text) {
            texts.add(contentDesc)
            nodes.add(NodeInfo(
                text = contentDesc,
                className = node.className?.toString() ?: "",
                viewId = node.viewIdResourceName ?: "",
                depth = depth,
                isContentDescription = true
            ))
        }

        // 递归处理子节点
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            extractText(child, texts, nodes, depth + 1)
            child.recycle()
        }
    }

    /**
     * 解析单个账单信息（兼容旧接口）
     * 从屏幕内容中提取交易相关信息
     */
    fun parseBillInfo(content: ScreenContent): BillInfo? {
        val bills = parseMultipleBills(content)
        return bills.firstOrNull()
    }

    /**
     * 解析多个账单信息
     * 支持从长图/账单列表中提取多笔交易
     */
    fun parseMultipleBills(content: ScreenContent): List<BillInfo> {
        if (content.texts.isEmpty()) return emptyList()

        val fullText = content.texts.joinToString("\n")

        // 检查是否为账单相关页面
        val isBillPage = billKeywords.any { fullText.contains(it) }
        if (!isBillPage) return emptyList()

        // 尝试按交易块解析
        val billBlocks = segmentBillBlocks(content.texts)

        if (billBlocks.isNotEmpty()) {
            // 有明确的交易块，逐块解析
            return billBlocks.mapNotNull { block ->
                parseSingleBillBlock(block, content.packageName)
            }
        }

        // 回退到简单解析
        val simpleBill = parseSimpleBill(content)
        return if (simpleBill != null) listOf(simpleBill) else emptyList()
    }

    /**
     * 分割账单块
     * 根据常见的账单列表模式将文本分割成独立的交易块
     */
    private fun segmentBillBlocks(texts: List<String>): List<List<String>> {
        val blocks = mutableListOf<List<String>>()
        var currentBlock = mutableListOf<String>()
        var lastWasAmount = false

        // 交易分隔标志
        val separatorPatterns = listOf(
            Regex("""^\d{1,2}[月/]\d{1,2}[日号]?"""),  // 日期开头
            Regex("""^(支出|收入|转账|消费|退款)"""),    // 交易类型开头
            Regex("""^[-—─]+$"""),                      // 分隔线
        )

        for (text in texts) {
            val trimmed = text.trim()
            if (trimmed.isEmpty()) continue

            // 检查是否是新交易的开始
            val isNewBlock = separatorPatterns.any { it.containsMatchIn(trimmed) }
            val hasAmount = amountPattern.containsMatchIn(trimmed)

            if (isNewBlock && currentBlock.isNotEmpty()) {
                // 保存当前块，开始新块
                if (blockHasAmount(currentBlock)) {
                    blocks.add(currentBlock.toList())
                }
                currentBlock = mutableListOf()
            }

            currentBlock.add(trimmed)

            // 如果遇到金额且之前已有金额，可能是新交易
            if (hasAmount && lastWasAmount && currentBlock.size > 1) {
                // 回溯：把当前金额作为新块的开始
                val lastItem = currentBlock.removeLast()
                if (blockHasAmount(currentBlock)) {
                    blocks.add(currentBlock.toList())
                }
                currentBlock = mutableListOf(lastItem)
            }

            lastWasAmount = hasAmount
        }

        // 保存最后一个块
        if (currentBlock.isNotEmpty() && blockHasAmount(currentBlock)) {
            blocks.add(currentBlock)
        }

        return blocks
    }

    /**
     * 检查块是否包含金额
     */
    private fun blockHasAmount(block: List<String>): Boolean {
        return block.any { amountPattern.containsMatchIn(it) }
    }

    /**
     * 解析单个账单块
     */
    private fun parseSingleBillBlock(block: List<String>, packageName: String): BillInfo? {
        val blockText = block.joinToString(" ")

        // 提取金额
        val amountMatch = amountPattern.find(blockText)
        val amount = amountMatch?.groupValues?.get(1)?.toDoubleOrNull() ?: return null

        // 提取时间
        val timeMatch = timePattern.find(blockText)
        val time = timeMatch?.groupValues?.get(1)

        // 提取商户
        val merchant = extractMerchantFromBlock(block)

        // 确定交易类型
        val type = when {
            blockText.contains("收入") || blockText.contains("收款") || blockText.contains("到账") -> "income"
            blockText.contains("转账") || blockText.contains("转出") -> "transfer"
            blockText.contains("退款") || blockText.contains("退回") -> "income"
            else -> "expense"
        }

        return BillInfo(
            amount = amount,
            merchant = merchant,
            time = time,
            type = type,
            rawTexts = block,
            packageName = packageName,
            confidence = calculateConfidence(true, merchant != null, time != null)
        )
    }

    /**
     * 从账单块中提取商户名
     */
    private fun extractMerchantFromBlock(block: List<String>): String? {
        for (text in block) {
            // 跳过金额、时间、纯数字
            if (amountPattern.containsMatchIn(text)) continue
            if (timePattern.containsMatchIn(text)) continue
            if (text.matches(Regex("""^[\d.]+$"""))) continue
            if (text.length < 2 || text.length > 30) continue

            // 跳过常见非商户文本
            val skipWords = listOf("支出", "收入", "转账", "消费", "退款", "详情", "账单", "交易")
            if (skipWords.any { text.contains(it) }) continue

            return text
        }
        return null
    }

    /**
     * 简单账单解析（回退方案）
     */
    private fun parseSimpleBill(content: ScreenContent): BillInfo? {
        val fullText = content.texts.joinToString("\n")

        // 提取金额
        val amounts = amountPattern.findAll(fullText)
            .map { it.groupValues[1].toDoubleOrNull() }
            .filterNotNull()
            .toList()

        if (amounts.isEmpty()) return null

        // 提取时间
        val times = timePattern.findAll(fullText)
            .map { it.groupValues[1] }
            .toList()

        // 提取商户名称
        val merchant = extractMerchant(content.texts)

        // 确定交易类型
        val transactionType = when {
            fullText.contains("收入") || fullText.contains("收款") -> "income"
            fullText.contains("支出") || fullText.contains("付款") || fullText.contains("消费") -> "expense"
            fullText.contains("转账") -> "transfer"
            else -> "expense"
        }

        return BillInfo(
            amount = amounts.firstOrNull(),
            merchant = merchant,
            time = times.firstOrNull(),
            type = transactionType,
            rawTexts = content.texts,
            packageName = content.packageName,
            confidence = calculateConfidence(amounts.isNotEmpty(), merchant != null, times.isNotEmpty())
        )
    }

    /**
     * 提取商户名称
     */
    private fun extractMerchant(texts: List<String>): String? {
        // 常见商户相关标签
        val merchantLabels = listOf("商户名称", "商户", "收款方", "付款方", "对方", "来自", "转给")

        for ((index, text) in texts.withIndex()) {
            for (label in merchantLabels) {
                if (text.contains(label) && index + 1 < texts.size) {
                    val nextText = texts[index + 1]
                    // 过滤掉明显不是商户名的内容
                    if (nextText.length in 2..20 && !amountPattern.containsMatchIn(nextText)) {
                        return nextText
                    }
                }
            }
        }

        return null
    }

    /**
     * 计算识别置信度
     */
    private fun calculateConfidence(hasAmount: Boolean, hasMerchant: Boolean, hasTime: Boolean): Double {
        var score = 0.0
        if (hasAmount) score += 0.5
        if (hasMerchant) score += 0.3
        if (hasTime) score += 0.2
        return score
    }

    /**
     * 截取当前屏幕
     * 需要 Android 5.0+ 和额外的截屏权限
     */
    fun takeScreenshot(callback: (String?) -> Unit) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            callback(null)
            return
        }

        takeScreenshot(
            Display.DEFAULT_DISPLAY,
            mainExecutor,
            object : TakeScreenshotCallback {
                override fun onSuccess(screenshot: ScreenshotResult) {
                    try {
                        val bitmap = Bitmap.wrapHardwareBuffer(
                            screenshot.hardwareBuffer,
                            screenshot.colorSpace
                        )

                        if (bitmap != null) {
                            val path = saveBitmap(bitmap)
                            screenshot.hardwareBuffer.close()
                            callback(path)
                        } else {
                            callback(null)
                        }
                    } catch (e: Exception) {
                        e.printStackTrace()
                        callback(null)
                    }
                }

                override fun onFailure(errorCode: Int) {
                    callback(null)
                }
            }
        )
    }

    /**
     * 保存位图到缓存目录
     */
    private fun saveBitmap(bitmap: Bitmap): String? {
        return try {
            val cacheDir = File(applicationContext.cacheDir, "screenshots")
            if (!cacheDir.exists()) {
                cacheDir.mkdirs()
            }

            val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
            val file = File(cacheDir, "screenshot_$timestamp.png")

            FileOutputStream(file).use { out ->
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            }

            file.absolutePath
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }
}

/**
 * 屏幕内容数据类
 */
data class ScreenContent(
    val packageName: String,
    val texts: List<String>,
    val nodes: List<NodeInfo>,
    val timestamp: Long
) {
    companion object {
        fun empty() = ScreenContent("", emptyList(), emptyList(), 0)
    }

    val isEmpty: Boolean get() = texts.isEmpty()
}

/**
 * 节点信息
 */
data class NodeInfo(
    val text: String,
    val className: String,
    val viewId: String,
    val depth: Int,
    val isContentDescription: Boolean = false
)

/**
 * 账单信息
 */
data class BillInfo(
    val amount: Double?,
    val merchant: String?,
    val time: String?,
    val type: String,
    val rawTexts: List<String>,
    val packageName: String,
    val confidence: Double
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "amount" to amount,
        "merchant" to merchant,
        "time" to time,
        "type" to type,
        "rawTexts" to rawTexts,
        "packageName" to packageName,
        "confidence" to confidence
    )
}
