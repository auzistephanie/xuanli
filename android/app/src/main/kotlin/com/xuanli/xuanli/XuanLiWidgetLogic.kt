package com.xuanli.xuanli

import java.util.Calendar
import java.util.TimeZone

/** Dart 側 `WidgetDayPayload.toJson()` 寫入嘅一日份資料（欄位要同 Dart 一致）。 */
data class XuanLiDay(
    val date: String, // yyyy-MM-dd
    val ganzhiDay: String,
    val lunarLabel: String,
    val fortuneScore: Int,
    val band: String, // 吉 | 平 | 忌
    val yi: List<String>,
    val ji: List<String>,
    val avoidHour: String?,
)

/** [stale] = 7 日份資料已經用晒，顯示緊最後一日，要提示「開 app 更新」。 */
data class XuanLiWidgetState(val day: XuanLiDay?, val stale: Boolean)

/** 冇 Android 依賴嘅純邏輯，方便喺 JVM 直接跑測試。 */
object XuanLiWidgetLogic {

    fun dateKey(cal: Calendar): String = String.format(
        "%04d-%02d-%02d",
        cal.get(Calendar.YEAR),
        cal.get(Calendar.MONTH) + 1,
        cal.get(Calendar.DAY_OF_MONTH),
    )

    /** 攞今日嗰日；冇就（spec §9.6）顯示最後一日＋提示開 app。 */
    fun pick(days: List<XuanLiDay>, today: String): XuanLiWidgetState {
        if (days.isEmpty()) return XuanLiWidgetState(null, false)
        val match = days.firstOrNull { it.date == today }
        if (match != null) return XuanLiWidgetState(match, false)
        return XuanLiWidgetState(days.last(), true)
    }

    /** 下一次自動刷新：今日 00:05、今日 07:00、明日 00:05 入面第一個喺 [nowMillis] 之後嘅時間。 */
    fun nextTriggerMillis(nowMillis: Long, timeZone: TimeZone = TimeZone.getDefault()): Long {
        fun at(dayOffset: Int, hour: Int, minute: Int): Long {
            val c = Calendar.getInstance(timeZone)
            c.timeInMillis = nowMillis
            c.add(Calendar.DAY_OF_MONTH, dayOffset)
            c.set(Calendar.HOUR_OF_DAY, hour)
            c.set(Calendar.MINUTE, minute)
            c.set(Calendar.SECOND, 0)
            c.set(Calendar.MILLISECOND, 0)
            return c.timeInMillis
        }
        return listOf(at(0, 0, 5), at(0, 7, 0), at(1, 0, 5)).first { it > nowMillis }
    }

    fun sweepDegrees(score: Int): Float = 360f * score.coerceIn(0, 100) / 100f

    /** "2026-07-11" → "7月11日"。 */
    fun dateLabel(dateKey: String): String {
        val parts = dateKey.split("-")
        if (parts.size != 3) return dateKey
        val month = parts[1].toIntOrNull() ?: return dateKey
        val day = parts[2].toIntOrNull() ?: return dateKey
        return "${month}月${day}日"
    }

    fun yiLine(items: List<String>): String =
        if (items.isEmpty()) "宜　靜守" else "宜　" + items.joinToString("・")

    fun jiLine(items: List<String>): String =
        if (items.isEmpty()) "忌　無" else "忌　" + items.joinToString("・")

    fun deepLink(dateKey: String): String = "xuanli://day/$dateKey"
}
