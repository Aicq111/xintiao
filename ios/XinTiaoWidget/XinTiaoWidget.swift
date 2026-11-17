// ============================================================
// 薪跳 · 桌面小组件（小 2×2 / 中 4×2 / 大 4×4）
// 数据来源：主 App 通过 App Group UserDefaults 写入
// ============================================================
import WidgetKit
import SwiftUI

private let appGroupId = "group.com.xintiao.widget"

private func defaults() -> UserDefaults {
  return UserDefaults(suiteName: appGroupId) ?? .standard
}

struct XinTiaoEntry: TimelineEntry {
  let date: Date
  let total: String
  let rate: String
  let today: String
  let month: String
  let payday: String
  let status: String
  let working: Bool
  let badge: String
  let work: String
  let rows: [String]
  let accentHex: String
  let viewName: String
}

private func sampleEntry() -> XinTiaoEntry {
  XinTiaoEntry(
    date: Date(),
    total: "¥ 3,456.789",
    rate: "+0.83厘/秒",
    today: "¥ 112.345",
    month: "¥ 3,456.789",
    payday: "距发薪 12 天",
    status: "上班中",
    working: true,
    badge: "1.5×",
    work: "已工作 6:23:45 · 距下班 2:36:15",
    rows: ["主工资 ¥2,867.124", "写作副业 ¥421.560", "理财利息 ¥168.105"],
    accentHex: "#34D399",
    viewName: "全部收入")
}

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> XinTiaoEntry { sampleEntry() }

  func getSnapshot(in context: Context, completion: @escaping (XinTiaoEntry) -> Void) {
    completion(sampleEntry())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<XinTiaoEntry>) -> Void) {
    let d = defaults()
    let entry = XinTiaoEntry(
      date: Date(),
      total: d.string(forKey: "total") ?? "¥ 0.000",
      rate: d.string(forKey: "rate") ?? "+0厘/秒",
      today: d.string(forKey: "today") ?? "¥ 0.000",
      month: d.string(forKey: "month") ?? "¥ 0.000",
      payday: d.string(forKey: "payday") ?? "—",
      status: d.string(forKey: "status") ?? "—",
      working: d.bool(forKey: "working"),
      badge: d.string(forKey: "badge") ?? "1.0×",
      work: d.string(forKey: "work") ?? "",
      rows: d.stringArray(forKey: "rows") ?? [],
      accentHex: d.string(forKey: "accent") ?? "#34D399",
      viewName: d.string(forKey: "view") ?? "全部收入")
    // 金额按时间戳推算由主 App 完成；小组件 15 分钟拉取一次新时间线
    let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date())
      ?? Date().addingTimeInterval(900)
    completion(Timeline(entries: [entry], policy: .after(next)))
  }
}

extension Color {
  init(hex: String) {
    var h = hex.trimmingCharacters(in: .whitespaces)
    if h.hasPrefix("#") { h.removeFirst() }
    var v: UInt64 = 0
    Scanner(string: h).scanHexInt64(&v)
    let r = Double((v >> 16) & 0xFF) / 255.0
    let g = Double((v >> 8) & 0xFF) / 255.0
    let b = Double(v & 0xFF) / 255.0
    self.init(red: r, green: g, blue: b)
  }
}

struct XinTiaoWidgetEntryView: View {
  @Environment(\.widgetFamily) var family
  var entry: XinTiaoEntry

  private var accent: Color { Color(hex: entry.accentHex) }
  private var dim: Color { Color(white: 0.55) }

  var body: some View {
    switch family {
    case .systemMedium:
      medium
    case .systemLarge:
      large
    default:
      small
    }
  }

  // ---------- 小尺寸 ----------
  private var small: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Text("薪跳")
          .font(.system(size: 11, weight: .bold))
          .foregroundColor(.white)
        Spacer()
        Circle()
          .fill(entry.working ? accent : Color(white: 0.45))
          .frame(width: 6, height: 6)
      }
      Spacer()
      Text(entry.total)
        .font(Font.system(size: 19, weight: .bold).monospacedDigit())
        .foregroundColor(accent)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
      Spacer()
      Text("\(entry.rate) · \(entry.payday)")
        .font(.system(size: 9))
        .foregroundColor(dim)
        .lineLimit(1)
    }
  }

  // ---------- 中尺寸 ----------
  private var medium: some View {
    HStack(spacing: 14) {
      VStack(alignment: .leading, spacing: 3) {
        HStack(spacing: 4) {
          Circle()
            .fill(entry.working ? accent : Color(white: 0.45))
            .frame(width: 6, height: 6)
          Text(entry.status)
            .font(.system(size: 10))
            .foregroundColor(dim)
        }
        Text(entry.total)
          .font(Font.system(size: 24, weight: .bold).monospacedDigit())
          .foregroundColor(accent)
          .lineLimit(1)
          .minimumScaleFactor(0.6)
        Text(entry.rate)
          .font(.system(size: 11))
          .foregroundColor(dim)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 8) {
        mini("今日已赚", entry.today)
        mini("本月已赚", entry.month)
        mini("发薪", entry.payday)
      }
    }
  }

  private func mini(_ k: String, _ v: String) -> some View {
    VStack(alignment: .trailing, spacing: 1) {
      Text(k).font(.system(size: 9)).foregroundColor(dim)
      Text(v)
        .font(Font.system(size: 12, weight: .bold).monospacedDigit())
        .foregroundColor(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
  }

  // ---------- 大尺寸 ----------
  private var large: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Text("薪跳 · \(entry.viewName)")
          .font(.system(size: 12, weight: .bold))
          .foregroundColor(.white)
        Spacer()
        HStack(spacing: 4) {
          Circle()
            .fill(entry.working ? accent : Color(white: 0.45))
            .frame(width: 6, height: 6)
          Text(entry.status)
            .font(.system(size: 10))
            .foregroundColor(dim)
        }
      }
      Text(entry.total)
        .font(Font.system(size: 32, weight: .bold).monospacedDigit())
        .foregroundColor(accent)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
      Text(entry.rate)
        .font(.system(size: 11))
        .foregroundColor(dim)
      Spacer(minLength: 8)
      HStack(spacing: 8) {
        cell("今日已赚", entry.today)
        cell("本月已赚", entry.month)
        cell("距发薪", entry.payday)
        cell("状态", entry.badge)
      }
      Spacer(minLength: 8)
      ForEach(entry.rows.prefix(4), id: \.self) { row in
        HStack {
          Text(row.components(separatedBy: " ").first ?? "")
            .font(.system(size: 11))
            .foregroundColor(.white)
          Spacer()
          Text(row.components(separatedBy: " ").dropFirst().joined(separator: " "))
            .font(Font.system(size: 11, weight: .semibold).monospacedDigit())
            .foregroundColor(.white)
        }
        if row != entry.rows.prefix(4).last {
          Divider().overlay(Color(white: 0.15))
        }
      }
    }
  }

  private func cell(_ k: String, _ v: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(k).font(.system(size: 9)).foregroundColor(dim)
      Text(v)
        .font(Font.system(size: 12, weight: .bold).monospacedDigit())
        .foregroundColor(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

@main
struct XinTiaoWidgetBundle: WidgetBundle {
  var body: some Widget {
    XinTiaoWidget()
  }
}

struct XinTiaoWidget: Widget {
  let kind = "XinTiaoWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: Provider()) { entry in
      if #available(iOS 17.0, *) {
        XinTiaoWidgetEntryView(entry: entry)
          .containerBackground(for: .widget) {
            Color(red: 0.043, green: 0.071, blue: 0.125)
          }
      } else {
        XinTiaoWidgetEntryView(entry: entry)
          .padding(14)
          .background(Color(red: 0.043, green: 0.071, blue: 0.125))
      }
    }
    .configurationDisplayName("薪跳")
    .description("随时查看工资每秒增长：总数、增速、今日已赚、距发薪")
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
  }
}
