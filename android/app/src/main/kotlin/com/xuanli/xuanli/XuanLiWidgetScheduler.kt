package com.xuanli.xuanli

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * 每日 00:05（轉日）同 07:00 自動刷新 widget（spec §9.6）。用 inexact alarm，唔使特別權限；
 * 重開機／app 更新之後 alarm 會被清走，所以 [XuanLiWidgetTickReceiver] 都收 BOOT_COMPLETED／
 * MY_PACKAGE_REPLACED 重新排。
 */
object XuanLiWidgetScheduler {
    const val ACTION_TICK = "com.xuanli.xuanli.WIDGET_TICK"

    fun scheduleNext(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, XuanLiWidgetTickReceiver::class.java).setAction(ACTION_TICK)
        val pending = PendingIntent.getBroadcast(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val triggerAt = XuanLiWidgetLogic.nextTriggerMillis(System.currentTimeMillis())
        alarmManager.set(AlarmManager.RTC, triggerAt, pending)
    }
}

class XuanLiWidgetTickReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        XuanLiWidgetRenderer.updateAll(context)
        XuanLiWidgetScheduler.scheduleNext(context)
    }
}
