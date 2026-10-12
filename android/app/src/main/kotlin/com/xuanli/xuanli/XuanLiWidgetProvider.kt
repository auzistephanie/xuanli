package com.xuanli.xuanli

import android.appwidget.AppWidgetManager
import android.content.Context
import android.appwidget.AppWidgetProvider

/** 小 widget（2×2）。類名要同 Dart `WidgetDataBridge` 嘅 `XuanLiWidgetProvider` 一致。 */
class XuanLiWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, XuanLiWidgetRenderer.buildSmall(context))
        }
        XuanLiWidgetScheduler.scheduleNext(context)
    }

    override fun onEnabled(context: Context) {
        XuanLiWidgetScheduler.scheduleNext(context)
    }
}
