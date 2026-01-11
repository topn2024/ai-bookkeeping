package com.example.ai_bookkeeping

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import android.util.Log
import java.text.NumberFormat
import java.util.Locale

/**
 * 今日统计小组件
 *
 * 显示今日消费统计，支持快捷记账
 */
class TodayStatsWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val TAG = "TodayStatsWidget"
        private const val ACTION_VOICE_RECORD = "com.example.ai_bookkeeping.ACTION_VOICE"
        private const val ACTION_ADD_RECORD = "com.example.ai_bookkeeping.ACTION_ADD"
        private const val ACTION_REFRESH = "com.example.ai_bookkeeping.ACTION_REFRESH"
        private const val PREFS_NAME = "widget_data"
        private const val KEY_TODAY_AMOUNT = "today_amount"
        private const val KEY_TODAY_COUNT = "today_count"

        /**
         * 更新所有小组件
         */
        fun updateWidgets(context: Context, amount: Double, count: Int) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit()
                .putFloat(KEY_TODAY_AMOUNT, amount.toFloat())
                .putInt(KEY_TODAY_COUNT, count)
                .apply()

            val intent = Intent(context, TodayStatsWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            }
            context.sendBroadcast(intent)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        when (intent.action) {
            ACTION_VOICE_RECORD -> {
                Log.d(TAG, "Voice record action received")
                openDeepLink(context, "aibook://voice")
            }
            ACTION_ADD_RECORD -> {
                Log.d(TAG, "Add record action received")
                openDeepLink(context, "aibook://add")
            }
            ACTION_REFRESH -> {
                Log.d(TAG, "Refresh action received")
                refreshWidget(context)
            }
            AppWidgetManager.ACTION_APPWIDGET_UPDATE -> {
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val appWidgetIds = appWidgetManager.getAppWidgetIds(
                    ComponentName(context, TodayStatsWidgetProvider::class.java)
                )
                for (appWidgetId in appWidgetIds) {
                    updateAppWidget(context, appWidgetManager, appWidgetId)
                }
            }
        }
    }

    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val views = RemoteViews(context.packageName, R.layout.widget_today_stats)

        // 获取统计数据
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val amount = prefs.getFloat(KEY_TODAY_AMOUNT, 0f).toDouble()
        val count = prefs.getInt(KEY_TODAY_COUNT, 0)

        // 格式化金额
        val formatter = NumberFormat.getCurrencyInstance(Locale.CHINA)
        val amountText = formatter.format(amount)

        // 更新显示
        views.setTextViewText(R.id.tv_amount, amountText)
        views.setTextViewText(R.id.tv_count, "共${count}笔")

        // 语音记账按钮
        val voiceIntent = Intent(context, TodayStatsWidgetProvider::class.java).apply {
            action = ACTION_VOICE_RECORD
        }
        val voicePendingIntent = PendingIntent.getBroadcast(
            context, 0, voiceIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.btn_voice, voicePendingIntent)

        // 手动记账按钮
        val addIntent = Intent(context, TodayStatsWidgetProvider::class.java).apply {
            action = ACTION_ADD_RECORD
        }
        val addPendingIntent = PendingIntent.getBroadcast(
            context, 1, addIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.btn_add, addPendingIntent)

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    private fun openDeepLink(context: Context, uri: String) {
        val intent = Intent(Intent.ACTION_VIEW).apply {
            data = Uri.parse(uri)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        try {
            context.startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open deep link: $uri", e)
            // 降级：直接打开应用
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            launchIntent?.let {
                it.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                context.startActivity(it)
            }
        }
    }

    private fun refreshWidget(context: Context) {
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(
            ComponentName(context, TodayStatsWidgetProvider::class.java)
        )
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onEnabled(context: Context) {
        Log.d(TAG, "Today stats widget enabled")
    }

    override fun onDisabled(context: Context) {
        Log.d(TAG, "Today stats widget disabled")
    }
}
