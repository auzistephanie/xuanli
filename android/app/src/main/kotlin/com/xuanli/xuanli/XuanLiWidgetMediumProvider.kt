package com.xuanli.xuanli

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context

/** 中 widget（4×2）。類名要同 Dart `WidgetDataBridge` 嘅 `XuanLiWidgetMediumProvider` 一致。 */
class XuanLiWidgetMediumProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, XuanLiWidgetRenderer.buildMedium(context))
        }
        XuanLiWidgetScheduler.scheduleNext(context)
    }

    override fun onEnabled(context: Context) {
        XuanLiWidgetScheduler.scheduleNext(context)
    }
}
