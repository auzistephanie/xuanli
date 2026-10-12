import Foundation

/// Dart 側 `WidgetDayPayload.toJson()` 寫入嘅一日份資料（欄位要同 Dart 一致）。
struct XuanLiDay: Decodable, Equatable {
    let date: String // yyyy-MM-dd
    let ganzhiDay: String
    let lunarLabel: String
    let fortuneScore: Int
    let band: String // 吉 | 平 | 忌
    let yi: [String]
    let ji: [String]
    let avoidHour: String?
}

/// Timeline 一格：幾時開始顯示、顯示邊日、係咪已經用晒 7 日份資料（要提示開 app 更新）。
struct XuanLiSlot: Equatable {
    let start: Date
    let day: XuanLiDay?
    let stale: Bool
}

/// 冇 WidgetKit 依賴嘅純邏輯，方便直接用 swiftc 編譯執行測試。
enum XuanLiLogic {
    static let appGroup = "group.com.xuanli.xuanli"
    static let dataKey = "xuanli_week_readings"

    static func decodeDays(_ raw: String?) -> [XuanLiDay] {
        guard let raw = raw, let data = raw.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([XuanLiDay].self, from: data)) ?? []
    }

    static func dateKey(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// "2026-07-11" → "7月11日"
    static func dateLabel(_ key: String) -> String {
        let parts = key.split(separator: "-")
        guard parts.count == 3, let m = Int(parts[1]), let d = Int(parts[2]) else { return key }
        return "\(m)月\(d)日"
    }

    static func yiLine(_ items: [String]) -> String {
        items.isEmpty ? "宜　靜守" : "宜　" + items.joined(separator: "・")
    }

    static func jiLine(_ items: [String]) -> String {
        items.isEmpty ? "忌　無" : "忌　" + items.joined(separator: "・")
    }

    static func deepLink(_ dateKey: String) -> URL? {
        URL(string: "xuanli://day/\(dateKey)")
    }

    /// 由 [now] 開始嘅 timeline：
    /// - 第一格喺 [now]：今日有資料就用今日，冇就用最後一日（stale）；
    /// - 之後每個未到嘅日子喺 00:00 同 07:00 各一格（spec §9.6）；
    /// - 7 日用晒之後，最後一日喺其後一個 00:00 變 stale（提示開 app 更新）。
    static func slots(days: [XuanLiDay], now: Date, calendar: Calendar) -> [XuanLiSlot] {
        guard let last = days.last else {
            return [XuanLiSlot(start: now, day: nil, stale: false)]
        }
        let todayKey = dateKey(now, calendar: calendar)
        var out: [XuanLiSlot] = []
        if let today = days.first(where: { $0.date == todayKey }) {
            out.append(XuanLiSlot(start: now, day: today, stale: false))
        } else if todayKey < days[0].date {
            // 部機日期早過資料：照第一日顯示都冇意思，當 stale 用最後一日。
            out.append(XuanLiSlot(start: now, day: last, stale: true))
        } else if todayKey > last.date {
            out.append(XuanLiSlot(start: now, day: last, stale: true))
            return out
        } else {
            out.append(XuanLiSlot(start: now, day: last, stale: true))
        }
        for day in days where day.date > todayKey {
            guard let startOfDay = date(fromKey: day.date, calendar: calendar) else { continue }
            out.append(XuanLiSlot(start: startOfDay, day: day, stale: false))
            if let seven = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: startOfDay), seven > now {
                out.append(XuanLiSlot(start: seven, day: day, stale: false))
            }
        }
        if let lastStart = date(fromKey: last.date, calendar: calendar),
           let after = calendar.date(byAdding: .day, value: 1, to: lastStart),
           after > now {
            out.append(XuanLiSlot(start: after, day: last, stale: true))
        }
        return out
    }

    static func date(fromKey key: String, calendar: Calendar) -> Date? {
        let parts = key.split(separator: "-")
        guard parts.count == 3, let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) else { return nil }
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d; c.hour = 0; c.minute = 0; c.second = 0
        return calendar.date(from: c)
    }
}
