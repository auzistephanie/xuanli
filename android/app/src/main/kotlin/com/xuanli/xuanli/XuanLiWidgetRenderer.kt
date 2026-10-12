package com.xuanli.xuanli

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import java.util.Calendar

/** 讀 `home_widget` 寫入嘅 7 日資料，畫小／中 widget，並綁「撳落去跳去當日」。 */
object XuanLiWidgetRenderer {
    // home_widget 套件寫入嘅 SharedPreferences 名同 Dart `WidgetDataBridge._dataKey`。
    private const val PREFS = "HomeWidgetPreferences"
    private const val DATA_KEY = "xuanli_week_readings"

    fun updateAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val small = manager.getAppWidgetIds(ComponentName(context, XuanLiWidgetProvider::class.java))
        for (id in small) manager.updateAppWidget(id, buildSmall(context))
        val medium = manager.getAppWidgetIds(ComponentName(context, XuanLiWidgetMediumProvider::class.java))
        for (id in medium) manager.updateAppWidget(id, buildMedium(context))
    }

    fun loadDays(context: Context): List<XuanLiDay> {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(DATA_KEY, null) ?: return emptyList()
        return try {
            parse(raw)
        } catch (e: Exception) {
            emptyList() // JSON 壞咗就當冇資料，唔好令 widget crash
        }
    }

    fun parse(raw: String): List<XuanLiDay> {
        val array = JSONArray(raw)
        val out = ArrayList<XuanLiDay>(array.length())
        for (i in 0 until array.length()) {
            val o = array.getJSONObject(i)
            out.add(
                XuanLiDay(
                    date = o.getString("date"),
                    ganzhiDay = o.getString("ganzhiDay"),
                    lunarLabel = o.getString("lunarLabel"),
                    fortuneScore = o.getInt("fortuneScore"),
                    band = o.getString("band"),
                    yi = strings(o.optJSONArray("yi")),
                    ji = strings(o.optJSONArray("ji")),
                    avoidHour = if (o.isNull("avoidHour")) null else o.getString("avoidHour"),
                ),
            )
        }
        return out
    }

    private fun strings(array: JSONArray?): List<String> {
        if (array == null) return emptyList()
        return (0 until array.length()).map { array.getString(it) }
    }

    private fun state(context: Context): XuanLiWidgetState =
        XuanLiWidgetLogic.pick(loadDays(context), XuanLiWidgetLogic.dateKey(Calendar.getInstance()))

    fun buildSmall(context: Context): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_small)
        val s = state(context)
        val day = s.day
        if (day == null) {
            views.setTextViewText(R.id.widget_date, "玄曆")
            views.setImageViewBitmap(R.id.widget_ring, ringBitmap(context, null, null))
            views.setTextViewText(R.id.widget_band, "")
            views.setTextViewText(R.id.widget_hint, "開 app 完成設定")
            views.setViewVisibility(R.id.widget_hint, View.VISIBLE)
            views.setOnClickPendingIntent(R.id.widget_root, launchApp(context, 1))
            return views
        }
        views.setTextViewText(R.id.widget_date, XuanLiWidgetLogic.dateLabel(day.date))
        views.setImageViewBitmap(R.id.widget_ring, ringBitmap(context, day.fortuneScore, day.band))
        views.setTextViewText(R.id.widget_band, day.band)
        views.setTextColor(R.id.widget_band, bandColor(context, day.band))
        showStaleHint(views, s.stale)
        views.setOnClickPendingIntent(R.id.widget_root, openDay(context, day.date, 1))
        return views
    }

    fun buildMedium(context: Context): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_medium)
        val s = state(context)
        val day = s.day
        if (day == null) {
            views.setImageViewBitmap(R.id.widget_ring, ringBitmap(context, null, null))
            views.setTextViewText(R.id.widget_band, "")
            views.setTextViewText(R.id.widget_date, "玄曆")
            views.setTextViewText(R.id.widget_lunar, "")
            views.setTextViewText(R.id.widget_yi, "開 app 完成設定")
            views.setTextViewText(R.id.widget_ji, "")
            views.setTextViewText(R.id.widget_avoid, "")
            views.setOnClickPendingIntent(R.id.widget_root, launchApp(context, 2))
            return views
        }
        views.setImageViewBitmap(R.id.widget_ring, ringBitmap(context, day.fortuneScore, day.band))
        views.setTextViewText(R.id.widget_band, day.band)
        views.setTextColor(R.id.widget_band, bandColor(context, day.band))
        views.setTextViewText(R.id.widget_date, XuanLiWidgetLogic.dateLabel(day.date) + "・" + day.ganzhiDay + "日")
        views.setTextViewText(R.id.widget_lunar, day.lunarLabel)
        views.setTextViewText(R.id.widget_yi, XuanLiWidgetLogic.yiLine(day.yi))
        views.setTextViewText(R.id.widget_ji, XuanLiWidgetLogic.jiLine(day.ji))
        views.setTextViewText(R.id.widget_avoid, if (day.avoidHour != null) "避開" + day.avoidHour else "")
        showStaleHint(views, s.stale)
        views.setOnClickPendingIntent(R.id.widget_root, openDay(context, day.date, 2))
        return views
    }

    private fun showStaleHint(views: RemoteViews, stale: Boolean) {
        if (stale) {
            views.setTextViewText(R.id.widget_hint, "開 app 更新")
            views.setViewVisibility(R.id.widget_hint, View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.widget_hint, View.GONE)
        }
    }

    private fun bandColor(context: Context, band: String): Int = when (band) {
        "吉" -> context.getColor(R.color.xuanli_widget_jade)
        "忌" -> context.getColor(R.color.xuanli_widget_red)
        else -> context.getColor(R.color.xuanli_widget_gold)
    }

    /** 命理分金環：用 Canvas 畫成 Bitmap（RemoteViews 冇辦法直接畫弧）。 */
    fun ringBitmap(context: Context, score: Int?, band: String?): Bitmap {
        val size = 220
        val stroke = 20f
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val rect = RectF(stroke / 2, stroke / 2, size - stroke / 2, size - stroke / 2)

        val track = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = stroke
            color = context.getColor(R.color.xuanli_widget_track)
        }
        canvas.drawArc(rect, 0f, 360f, false, track)

        if (score != null) {
            val arc = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE
                strokeWidth = stroke
                strokeCap = Paint.Cap.ROUND
                color = context.getColor(R.color.xuanli_widget_gold)
            }
            canvas.drawArc(rect, -90f, XuanLiWidgetLogic.sweepDegrees(score), false, arc)

            val text = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = context.getColor(R.color.xuanli_widget_ink)
                textSize = 86f
                typeface = Typeface.create(Typeface.SERIF, Typeface.BOLD)
                textAlign = Paint.Align.CENTER
            }
            val baseline = size / 2f - (text.ascent() + text.descent()) / 2f
            canvas.drawText(score.toString(), size / 2f, baseline, text)
        }
        return bitmap
    }

    /** 撳 widget → `xuanli://day/yyyy-MM-dd`（spec §9.6）。 */
    private fun openDay(context: Context, dateKey: String, requestCode: Int): PendingIntent {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(XuanLiWidgetLogic.deepLink(dateKey)))
            .setPackage(context.packageName)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun launchApp(context: Context, requestCode: Int): PendingIntent {
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent()
        return PendingIntent.getActivity(
            context,
            requestCode + 10,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
