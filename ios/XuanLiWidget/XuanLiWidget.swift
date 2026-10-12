import SwiftUI
import WidgetKit

// MARK: - Timeline

struct DayEntry: TimelineEntry {
    let date: Date
    let day: XuanLiDay?
    let stale: Bool
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> DayEntry {
        DayEntry(date: Date(), day: Provider.sample, stale: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (DayEntry) -> Void) {
        let slot = XuanLiLogic.slots(days: Provider.loadDays(), now: Date(), calendar: .current).first
        completion(DayEntry(date: Date(), day: slot?.day ?? Provider.sample, stale: slot?.stale ?? false))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DayEntry>) -> Void) {
        let slots = XuanLiLogic.slots(days: Provider.loadDays(), now: Date(), calendar: .current)
        let entries = slots.map { DayEntry(date: $0.start, day: $0.day, stale: $0.stale) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    /// App 用 `home_widget` 寫入嘅 7 日資料（同 Dart `WidgetDataBridge` 同一個 App Group／key）。
    static func loadDays() -> [XuanLiDay] {
        let raw = UserDefaults(suiteName: XuanLiLogic.appGroup)?.string(forKey: XuanLiLogic.dataKey)
        return XuanLiLogic.decodeDays(raw)
    }

    static let sample = XuanLiDay(
        date: "2026-07-11", ganzhiDay: "丙戌", lunarLabel: "五月廿七", fortuneScore: 72, band: "吉",
        yi: ["祈福", "祭祀", "解除"], ji: ["嫁娶", "作灶"], avoidHour: "申時（15–17）"
    )
}

// MARK: - 配色（design html tokens；深色跟系統）

struct Palette {
    let bg: Color, ink: Color, ink60: Color, track: Color, gold: Color, jade: Color, red: Color

    init(dark: Bool) {
        if dark {
            bg = Color(hex: 0x0D1120); ink = Color(hex: 0xE9DFC9)
            ink60 = Color(hex: 0xE9DFC9).opacity(0.6); track = Color(hex: 0xE9DFC9).opacity(0.12)
            gold = Color(hex: 0xC9A24B); jade = Color(hex: 0x7FC0AB); red = Color(hex: 0xE08484)
        } else {
            bg = Color(hex: 0xF6EFE2); ink = Color(hex: 0x1C2440)
            ink60 = Color(hex: 0x1C2440).opacity(0.6); track = Color(hex: 0x1C2440).opacity(0.12)
            gold = Color(hex: 0xC9A24B); jade = Color(hex: 0x3F7D6E); red = Color(hex: 0xB23A3A)
        }
    }

    func band(_ band: String) -> Color {
        switch band {
        case "吉": return jade
        case "忌": return red
        default: return gold
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

extension View {
    /// iOS 17 起 widget 背景要用 containerBackground，舊版用 background。
    @ViewBuilder
    func widgetBackground(_ color: Color) -> some View {
        if #available(iOS 17.0, macOS 14.0, *) {
            containerBackground(color, for: .widget)
        } else {
            background(color)
        }
    }
}

// MARK: - Views

struct ScoreRing: View {
    let score: Int?
    let palette: Palette
    let diameter: CGFloat

    var body: some View {
        ZStack {
            Circle().stroke(palette.track, lineWidth: diameter * 0.1)
            if let score = score {
                Circle()
                    .trim(from: 0, to: CGFloat(min(max(score, 0), 100)) / 100)
                    .stroke(palette.gold, style: StrokeStyle(lineWidth: diameter * 0.1, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(score)")
                    .font(.system(size: diameter * 0.38, weight: .bold, design: .serif))
                    .foregroundColor(palette.ink)
            }
        }
        .frame(width: diameter, height: diameter)
    }
}

struct SmallView: View {
    let entry: DayEntry
    let palette: Palette

    var body: some View {
        VStack(spacing: 3) {
            if let day = entry.day {
                Text(XuanLiLogic.dateLabel(day.date))
                    .font(.system(size: 11)).foregroundColor(palette.ink60)
                ScoreRing(score: day.fortuneScore, palette: palette, diameter: 66)
                Text(day.band)
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundColor(palette.band(day.band))
                if entry.stale {
                    Text("開 app 更新").font(.system(size: 9)).foregroundColor(palette.ink60)
                }
            } else {
                Text("Kairo").font(.system(size: 13, weight: .bold, design: .serif)).foregroundColor(palette.ink)
                ScoreRing(score: nil, palette: palette, diameter: 66)
                Text("開 app 完成設定").font(.system(size: 9)).foregroundColor(palette.ink60)
            }
        }
    }
}

struct MediumView: View {
    let entry: DayEntry
    let palette: Palette

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 3) {
                ScoreRing(score: entry.day?.fortuneScore, palette: palette, diameter: 72)
                if let day = entry.day {
                    Text(day.band)
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundColor(palette.band(day.band))
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                if let day = entry.day {
                    Text(XuanLiLogic.dateLabel(day.date) + "・" + day.ganzhiDay + "日")
                        .font(.system(size: 14, weight: .bold)).foregroundColor(palette.ink).lineLimit(1)
                    Text(day.lunarLabel).font(.system(size: 11)).foregroundColor(palette.ink60).lineLimit(1)
                    Text(XuanLiLogic.yiLine(day.yi))
                        .font(.system(size: 12)).foregroundColor(palette.jade).lineLimit(1).padding(.top, 5)
                    Text(XuanLiLogic.jiLine(day.ji))
                        .font(.system(size: 12)).foregroundColor(palette.red).lineLimit(1)
                    if let avoid = day.avoidHour {
                        Text("避開" + avoid)
                            .font(.system(size: 10)).foregroundColor(palette.ink60).lineLimit(1).padding(.top, 3)
                    }
                    if entry.stale {
                        Text("開 app 更新").font(.system(size: 9)).foregroundColor(palette.ink60)
                    }
                } else {
                    Text("Kairo").font(.system(size: 14, weight: .bold, design: .serif)).foregroundColor(palette.ink)
                    Text("開 app 完成設定").font(.system(size: 12)).foregroundColor(palette.ink60)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

struct XuanLiWidgetView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.widgetFamily) private var family
    let entry: DayEntry

    var body: some View {
        let palette = Palette(dark: colorScheme == .dark)
        Group {
            switch family {
            case .systemMedium: MediumView(entry: entry, palette: palette)
            default: SmallView(entry: entry, palette: palette)
            }
        }
        .widgetBackground(palette.bg)
        // 撳 widget → xuanli://day/yyyy-MM-dd（spec §9.6）；冇資料就開 app。
        .widgetURL(entry.day.flatMap { XuanLiLogic.deepLink($0.date) } ?? URL(string: "xuanli://"))
    }
}

// MARK: - Widget

struct XuanLiWidget: Widget {
    /// 要同 Dart `WidgetDataBridge._iOSWidgetName` 一致。
    let kind: String = "XuanLiWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            XuanLiWidgetView(entry: entry)
        }
        .configurationDisplayName("Kairo・今日")
        .description("今日命理分、宜忌同避時提示")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct XuanLiWidgetBundle: WidgetBundle {
    var body: some Widget {
        XuanLiWidget()
    }
}
