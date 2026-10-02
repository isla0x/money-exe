// money.exe 홈 화면 · 잠금화면 위젯
//
// 앱(Flutter)이 App Group 저장소에 "snapshot" 키로 JSON 을 넣으면 이 위젯이 읽어서 그린다.
// JSON 모양은 lib/widget_sync.dart 의 widgetSnapshot() 과 같다.
//
// 날짜가 지나면 위젯이 스스로 다시 계산한다:
//   - 남은 날 · 하루 쓸 돈은 그날 날짜로
//   - 이번 달(주)이 끝나면 새 달(주)의 빈 디스크로
//
// 지원 크기
//   홈 화면   : 작게 / 중간
//   잠금 화면 : 직사각형 / 원형 / 시계 위 한 줄

import SwiftUI
import WidgetKit

private let appGroupId = "group.com.isla0x.moneyexe"
private let snapshotKey = "snapshot"
/// 누르면 앱이 입력칸을 연 채로 켜진다. (?homeWidget 은 home_widget 플러그인이 알아보는 표시)
private let addURL = URL(string: "moneyexe://add?homeWidget")!

// MARK: - 데이터

struct RecentItem: Decodable, Hashable {
    /// "09.24"
    let d: String
    /// 메모
    let m: String
    /// 금액 (원)
    let a: Int
}

struct MoneySnapshot: Decodable {
    let pro: Bool?
    /// "month" | "week"
    let period: String
    /// auto | light | dark. 예전 데이터에는 없을 수 있다.
    let mode: String?
    /// 이번 주기 예산 (그 주기에만 더한 추가 예산 포함)
    let budget: Int
    /// 기본 예산. 주기가 지나면 추가 예산 없이 이것으로. 예전 데이터에는 없을 수 있다.
    let base: Int?
    let spent: Int
    let count: Int
    /// 이번 주기 시작 · 끝 (밀리초, 끝은 포함하지 않음)
    let from: Double
    let until: Double
    let recent: [RecentItem]

    var isPro: Bool { pro ?? false }
    var weekly: Bool { period == "week" }

    /// 앱의 mode 설정과 iOS 다크/라이트 설정으로 밝은 화면인지 정한다.
    func isLight(_ scheme: ColorScheme) -> Bool {
        switch mode ?? "auto" {
        case "light": return true
        case "dark": return false
        default: return scheme == .light
        }
    }

    static let empty = MoneySnapshot(
        pro: false, period: "month", mode: "auto", budget: 0, base: 0, spent: 0, count: 0,
        from: Date().timeIntervalSince1970 * 1000, until: Date().addingTimeInterval(86400 * 30).timeIntervalSince1970 * 1000,
        recent: []
    )

    static var sample: MoneySnapshot {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? Date()
        let end = cal.date(byAdding: .month, value: 1, to: start) ?? Date()
        return MoneySnapshot(
            pro: true, period: "month", mode: "auto", budget: 700000, base: 700000, spent: 607600, count: 21,
            from: start.timeIntervalSince1970 * 1000, until: end.timeIntervalSince1970 * 1000,
            recent: [
                RecentItem(d: "09.23", m: "커피", a: 4800),
                RecentItem(d: "09.24", m: "점심 김밥", a: 4500),
                RecentItem(d: "09.24", m: "아아", a: 2000),
            ]
        )
    }

    static func load() -> MoneySnapshot {
        guard
            let defaults = UserDefaults(suiteName: appGroupId),
            let raw = defaults.string(forKey: snapshotKey),
            let data = raw.data(using: .utf8),
            let snap = try? JSONDecoder().decode(MoneySnapshot.self, from: data)
        else { return .empty }
        return snap
    }

    /// [date] 기준으로 디스크를 다시 계산한다.
    func disk(at date: Date) -> Disk {
        let cal = Calendar.current
        var start = Date(timeIntervalSince1970: from / 1000)
        var end = Date(timeIntervalSince1970: until / 1000)
        var spent = self.spent
        var recent = self.recent
        var budget = self.budget
        var guardCount = 0
        // 주기가 끝났으면 새 주기 (앱을 아직 안 열어서 기록이 없다)
        while date >= end && guardCount < 60 {
            start = end
            end = (weekly
                ? cal.date(byAdding: .day, value: 7, to: start)
                : cal.date(byAdding: .month, value: 1, to: start)) ?? start.addingTimeInterval(86400 * 7)
            spent = 0
            recent = []
            budget = base ?? self.budget
            guardCount += 1
        }
        let today = cal.startOfDay(for: date)
        let daysLeft = max(1, cal.dateComponents([.day], from: today, to: cal.startOfDay(for: end)).day ?? 1)
        let title: String
        if weekly {
            let last = cal.date(byAdding: .day, value: -1, to: end) ?? end
            title = "이번 주 \(cal.component(.month, from: start)).\(cal.component(.day, from: start))~"
                + "\(cal.component(.month, from: last)).\(cal.component(.day, from: last))"
        } else {
            title = "\(cal.component(.month, from: start))월 예산"
        }
        return Disk(title: title, budget: budget, spent: spent, daysLeft: daysLeft, recent: recent)
    }
}

enum Level { case unset, ok, warn, full }

struct Disk {
    let title: String
    let budget: Int
    let spent: Int
    let daysLeft: Int
    let recent: [RecentItem]

    var free: Int { budget - spent }
    var ratio: Double { budget <= 0 ? 0 : Double(spent) / Double(budget) }
    var fill: Double { min(1, max(0, ratio)) }

    var level: Level {
        if budget <= 0 { return .unset }
        if free < 0 { return .full }
        if ratio >= 0.8 { return .warn }
        return .ok
    }

    /// 87% · 87.5%
    var pctLabel: String {
        if level == .unset { return "--" }
        let p = (ratio * 1000).rounded() / 10
        return p == p.rounded() ? "\(Int(p))%" : String(format: "%.1f%%", p)
    }

    var perDay: Int { free <= 0 ? 0 : (free / max(1, daysLeft)) / 100 * 100 }

    var freeLine: String {
        switch level {
        case .unset: return "쓴 돈 \(won(spent))원"
        case .full: return "\(won(-free))원 초과"
        default: return "여유 \(won(free))원"
        }
    }

    var dayLine: String {
        switch level {
        case .unset: return "예산을 정해 보세요"
        case .full: return "남은 \(daysLeft)일, 아껴요"
        default: return "하루 \(won(perDay))원"
        }
    }
}

private func won(_ n: Int) -> String {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.groupingSeparator = ","
    return f.string(from: NSNumber(value: n)) ?? "\(n)"
}

// MARK: - 색 (앱과 같은 cmd 팔레트, 폰이 라이트 모드면 종이 색)

struct TermColors {
    let bg, bar, fg, hi, dim, ok, tag, cmd, warn, line: Color

    static func of(light: Bool) -> TermColors {
        if light {
            return TermColors(bg: Color(hex: 0xF5F2E8), bar: Color(hex: 0xE8E4D6), fg: Color(hex: 0x2B2B2B),
                              hi: Color(hex: 0x111111), dim: Color(hex: 0x6B6B6B), ok: Color(hex: 0x0B7A0B),
                              tag: Color(hex: 0x7A5F00), cmd: Color(hex: 0x0B6E8A), warn: Color(hex: 0xC0282F),
                              line: Color(hex: 0xD6D1C2))
        }
        return TermColors(bg: Color(hex: 0x0C0C0C), bar: Color(hex: 0x1A1A1A), fg: Color(hex: 0xCCCCCC),
                          hi: Color(hex: 0xF2F2F2), dim: Color(hex: 0x8A8A8A), ok: Color(hex: 0x16C60C),
                          tag: Color(hex: 0xF9F1A5), cmd: Color(hex: 0x61D6D6), warn: Color(hex: 0xE74856),
                          line: Color(hex: 0x2A2A2A))
    }

    func level(_ l: Level) -> Color {
        switch l {
        case .full: return warn
        case .warn: return tag
        default: return ok
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

private func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
    .system(size: size, weight: weight, design: .monospaced)
}

// MARK: - 타임라인

struct MoneyEntry: TimelineEntry {
    let date: Date
    let snap: MoneySnapshot
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> MoneyEntry {
        MoneyEntry(date: .now, snap: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (MoneyEntry) -> Void) {
        // 위젯 고르는 화면에서는 어떤 모습인지 보이도록 예시를 보여준다.
        completion(MoneyEntry(date: .now, snap: context.isPreview ? .sample : MoneySnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MoneyEntry>) -> Void) {
        let now = Date()
        let snap = MoneySnapshot.load()
        // 하루 쓸 돈 · 남은 날은 날짜가 바뀌면 달라진다: 다음 이틀 자정마다 미리 그려 둔다.
        var entries = [MoneyEntry(date: now, snap: snap)]
        let cal = Calendar.current
        var next = cal.startOfDay(for: now)
        for _ in 0..<2 {
            next = cal.date(byAdding: .day, value: 1, to: next) ?? next.addingTimeInterval(86400)
            entries.append(MoneyEntry(date: next, snap: snap))
        }
        completion(Timeline(entries: entries, policy: .after(next)))
    }
}

// MARK: - 홈 화면 위젯

struct DiskBar: View {
    let fill: Double
    let color: Color
    let border: Color
    var height: CGFloat = 12

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Rectangle().stroke(border, lineWidth: 1)
                Rectangle()
                    .fill(color)
                    .frame(width: max(0, (g.size.width - 4) * fill))
                    .padding(2)
            }
        }
        .frame(height: height)
    }
}

/// 작은 위젯 · 중간 위젯 왼쪽: 디스크
struct DiskColumn: View {
    let disk: Disk
    let c: TermColors

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Text(">_").font(mono(11, .bold)).foregroundColor(c.ok)
                Text("money.exe").font(mono(11, .bold)).foregroundColor(c.hi)
            }
            Text("C: · " + disk.title).font(mono(10)).foregroundColor(c.dim).lineLimit(1).minimumScaleFactor(0.8)
            DiskBar(fill: disk.fill, color: c.level(disk.level), border: c.dim)
            HStack(alignment: .firstTextBaseline) {
                Text(disk.level == .full ? "가득 참" : disk.pctLabel)
                    .font(mono(22, .bold))
                    .foregroundColor(disk.level == .full ? c.warn : c.hi)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                if disk.level != .unset && disk.level != .full {
                    Text("사용").font(mono(10)).foregroundColor(c.dim)
                }
            }
            Spacer(minLength: 0)
            Text(disk.freeLine).font(mono(11)).foregroundColor(c.fg).lineLimit(1).minimumScaleFactor(0.8)
            Text(disk.dayLine)
                .font(mono(11))
                .foregroundColor(disk.level == .unset ? c.dim : c.level(disk.level))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

struct SmallView: View {
    let disk: Disk
    let c: TermColors

    var body: some View {
        DiskColumn(disk: disk, c: c).padding(14)
    }
}

struct MediumView: View {
    let disk: Disk
    let c: TermColors

    var body: some View {
        HStack(spacing: 12) {
            DiskColumn(disk: disk, c: c).frame(width: 132)
            Rectangle().fill(c.line).frame(width: 1)
            VStack(alignment: .leading, spacing: 3) {
                Text("최근 기록").font(mono(10)).foregroundColor(c.dim)
                if disk.recent.isEmpty {
                    Text("기록 없음").font(mono(11)).foregroundColor(c.dim)
                } else {
                    ForEach(disk.recent, id: \.self) { r in
                        HStack(spacing: 6) {
                            Text(r.d).foregroundColor(c.dim)
                            Text(r.m).foregroundColor(c.hi).lineLimit(1)
                            Spacer(minLength: 0)
                            Text("-" + won(r.a)).foregroundColor(c.hi)
                        }
                        .font(mono(11))
                    }
                }
                Spacer(minLength: 0)
                HStack(spacing: 5) {
                    Text("C:\\money>").font(mono(11)).foregroundColor(c.hi)
                    Rectangle().fill(c.ok).frame(width: 7, height: 13)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 8)
                .frame(height: 28)
                .overlay(Rectangle().stroke(c.line, lineWidth: 1))
            }
        }
        .padding(14)
    }
}

// MARK: - 잠금화면 위젯

struct LockRectView: View {
    let disk: Disk

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("C:\\money> " + disk.pctLabel).font(mono(13, .bold)).widgetAccentable()
            Text("> " + disk.freeLine).font(mono(12)).lineLimit(1)
            Text("> " + disk.dayLine).font(mono(12)).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LockCircleView: View {
    let disk: Disk

    var body: some View {
        Gauge(value: disk.fill) {
            Text("C:").font(mono(10))
        } currentValueLabel: {
            Text(disk.level == .unset ? "--" : "\(Int((disk.ratio * 100).rounded()))")
                .font(mono(16, .bold))
                .minimumScaleFactor(0.6)
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .widgetAccentable()
    }
}

struct LockInlineView: View {
    let disk: Disk

    var body: some View {
        Text(disk.level == .unset ? ">_ money.exe · " + disk.freeLine : ">_ " + disk.freeLine + " · " + disk.dayLine)
    }
}

// MARK: - PRO 가 아닐 때

struct LockedHomeView: View {
    let c: TermColors

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Text(">_").font(mono(11, .bold)).foregroundColor(c.ok)
                Text("money.exe").font(mono(11, .bold)).foregroundColor(c.hi)
            }
            (Text("C:\\money> ").foregroundColor(c.dim) + Text("widget").foregroundColor(c.cmd))
                .font(mono(11))
            Text("Access is denied.").font(mono(12, .bold)).foregroundColor(c.warn)
            Text("위젯은 PRO 기능이에요.").font(mono(11)).foregroundColor(c.fg)
            Spacer(minLength: 0)
            (Text("앱에서 ").foregroundColor(c.dim) + Text("upgrade").foregroundColor(c.cmd))
                .font(mono(11))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
    }
}

struct LockedAccessoryView: View {
    let family: WidgetFamily

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Text(">_").font(mono(11, .bold))
                    Text("PRO").font(mono(12, .bold))
                }
            }
            .widgetAccentable()
        case .accessoryInline:
            Text(">_ money.exe · PRO 필요")
        default:
            VStack(alignment: .leading, spacing: 1) {
                Text("C:\\money> widget").font(mono(12, .bold)).widgetAccentable()
                Text("Access is denied.").font(mono(12))
                Text("앱에서 upgrade").font(mono(12))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - 위젯 정의

struct MoneyWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var scheme
    let entry: MoneyEntry

    private var c: TermColors { TermColors.of(light: entry.snap.isLight(scheme)) }

    var body: some View {
        content.widgetURL(addURL)
    }

    @ViewBuilder
    private var content: some View {
        let disk = entry.snap.disk(at: entry.date)
        let accessory = family == .accessoryRectangular || family == .accessoryCircular || family == .accessoryInline
        if !entry.snap.isPro {
            if accessory {
                LockedAccessoryView(family: family).containerBackground(for: .widget) { Color.clear }
            } else {
                LockedHomeView(c: c).containerBackground(for: .widget) { c.bg }
            }
        } else {
            switch family {
            case .accessoryRectangular:
                LockRectView(disk: disk).containerBackground(for: .widget) { Color.clear }
            case .accessoryCircular:
                LockCircleView(disk: disk).containerBackground(for: .widget) { Color.clear }
            case .accessoryInline:
                LockInlineView(disk: disk).containerBackground(for: .widget) { Color.clear }
            case .systemMedium:
                MediumView(disk: disk, c: c).containerBackground(for: .widget) { c.bg }
            default:
                SmallView(disk: disk, c: c).containerBackground(for: .widget) { c.bg }
            }
        }
    }
}

struct MoneyWidget: Widget {
    /// Flutter 쪽 WidgetSync.iOSWidgetKind 와 같아야 한다.
    let kind = "MoneyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            MoneyWidgetView(entry: entry)
        }
        .configurationDisplayName("money.exe")
        .description("이번 달(주) 예산을 디스크 용량처럼 보여줘요.")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryRectangular, .accessoryCircular, .accessoryInline,
        ])
        .contentMarginsDisabled()
    }
}

// MARK: - Xcode 미리보기

#Preview("작게", as: .systemSmall) {
    MoneyWidget()
} timeline: {
    MoneyEntry(date: .now, snap: .sample)
}

#Preview("중간", as: .systemMedium) {
    MoneyWidget()
} timeline: {
    MoneyEntry(date: .now, snap: .sample)
}

#Preview("잠금 직사각형", as: .accessoryRectangular) {
    MoneyWidget()
} timeline: {
    MoneyEntry(date: .now, snap: .sample)
}

#Preview("잠금 원형", as: .accessoryCircular) {
    MoneyWidget()
} timeline: {
    MoneyEntry(date: .now, snap: .sample)
}

#Preview("PRO 아님", as: .systemSmall) {
    MoneyWidget()
} timeline: {
    MoneyEntry(date: .now, snap: .empty)
}
