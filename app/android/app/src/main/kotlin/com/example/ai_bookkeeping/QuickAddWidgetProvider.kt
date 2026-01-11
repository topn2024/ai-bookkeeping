package com.example.ai_bookkeeping

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import android.util.Log

/**
 * 快捷记账小组件
 *
 * 点击打开语音记账页面
 */
class QuickAddWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val TAG = "QuickAddWidget"
        private const val ACTION_VOICE_RECORD = "com.example.ai_bookkeeping.ACTION_VOICE_RECORD"
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

        if (intent.action == ACTION_VOICE_RECORD) {
            Log.d(TAG, "Voice record action received")
            openVoiceRecord(context)
        }
    }

    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val views = RemoteViews(context.packageName, R.layout.widget_quick_add)

        // 设置点击事件 - 打开语音记账
        val intent = Intent(context, QuickAddWidgetProvider::class.java).apply {
            action = ACTION_VOICE_RECORD
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_quick_add, pendingIntent)

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    private fun openVoiceRecord(context: Context) {
        // 通过深度链接打开语音记账
        val intent = Intent(Intent.ACTION_VIEW).apply {
            data = Uri.parse("aibook://voice")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        try {
            context.startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open voice record", e)
            // 降级：直接打开应用
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            launchIntent?.let {
                it.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                context.startActivity(it)
            }
        }
    }

    override fun onEnabled(context: Context) {
        Log.d(TAG, "Quick add widget enabled")
    }

    override fun onDisabled(context: Context) {
        Log.d(TAG, "Quick add widget disabled")
    }
}
