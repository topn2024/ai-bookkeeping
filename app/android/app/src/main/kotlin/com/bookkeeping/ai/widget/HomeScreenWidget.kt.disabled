package com.bookkeeping.ai.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import com.bookkeeping.ai.R
import com.bookkeeping.ai.MainActivity

/**
 * 1×1 极简版小组件
 * 点击直接启动语音记账
 */
class VoiceQuickWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val views = RemoteViews(context.packageName, R.layout.widget_voice_quick)

            // 点击启动语音记账
            val intent = Intent(context, MainActivity::class.java).apply {
                action = "ACTION_VOICE_RECORDING"
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }

            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}

/**
 * 2×2 标准版小组件
 * 显示今日/本周支出 + 快捷金额按钮
 */
class StandardWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion fun {
        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
            todayExpense: Double = 0.0,
            weekExpense: Double = 0.0
        ) {
            val views = RemoteViews(context.packageName, R.layout.widget_standard)

            // 更新数据
            views.setTextViewText(R.id.today_expense, "¥${String.format("%.0f", todayExpense)}")
            views.setTextViewText(R.id.week_expense, "¥${String.format("%.0f", weekExpense)}")

            // 语音记账按钮
            val voiceIntent = Intent(context, MainActivity::class.java).apply {
                action = "ACTION_VOICE_RECORDING"
            }
            views.setOnClickPendingIntent(
                R.id.voice_button,
                PendingIntent.getActivity(context, 0, voiceIntent, PendingIntent.FLAG_IMMUTABLE)
            )

            // 快捷金额按钮
            val amounts = listOf(10, 20, 50, 100)
            val buttonIds = listOf(R.id.amount_10, R.id.amount_20, R.id.amount_50, R.id.amount_100)

            amounts.zip(buttonIds).forEach { (amount, buttonId) ->
                val intent = Intent(context, MainActivity::class.java).apply {
                    action = "ACTION_QUICK_AMOUNT"
                    putExtra("amount", amount)
                }
                views.setOnClickPendingIntent(
                    buttonId,
                    PendingIntent.getActivity(context, amount, intent, PendingIntent.FLAG_IMMUTABLE)
                )
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
