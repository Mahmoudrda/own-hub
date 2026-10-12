import Foundation

/// Shared with Runner. Must match both entitlements files and
/// `kWidgetAppGroup` in lib/app_state/home_widget_sync.dart.
let ownHubAppGroup = "group.com.ownhub.app"

/// `kWidgetPayloadKey` in lib/features/today/domain/widget_projection.dart.
let ownHubPayloadKey = "ownhub.widget.v1"

/// The sentences the app wrote, already in the language she chose there.
struct WidgetStrings: Codable {
  var title: String?
  var today: String?
  var week: String?
  var weekFresh: String?
  var inline: String?
  var inlineFresh: String?
  var a11y: String?
  var a11yFresh: String?
  var status: String?
  var meal: String?
  var mealNone: String?
  var stale: String?
  var closed: String?
}

/// The App Group payload. Only allow-listed fields exist here; anything else
/// the JSON might hold is ignored by the decoder.
struct WidgetPayload: Codable {
  var v: Int
  var state: String
  var lang: String
  var dayKey: String?
  var weekId: String?
  var done: Int?
  var target: Int?
  var today: String?
  var meal: Bool?
  var s: WidgetStrings

  /// What the app last wrote, or nil. A missing key, a different version or
  /// anything that does not decode reads as closed.
  static func load() -> WidgetPayload? {
    guard
      let raw = UserDefaults(suiteName: ownHubAppGroup)?.string(forKey: ownHubPayloadKey),
      let data = raw.data(using: .utf8),
      let payload = try? JSONDecoder().decode(WidgetPayload.self, from: data),
      payload.v == 1
    else { return nil }
    return payload
  }
}

/// What a widget draws at one moment.
struct WidgetModel {
  enum Mode { case closed, preview, open }

  var mode: Mode
  /// "ar" or "en" from the payload; nil follows the phone.
  var lang: String?
  var done = 0
  var target = 3
  var title: String?
  var todayTitle: String?
  var week: String?
  var inline: String?
  var a11y: String?
  var status: String?
  var meal: String?
  var mealLogged = false
  var closed: String?

  /// Empty segments and "Your week shows here": no invented figures.
  static let preview = WidgetModel(mode: .preview)

  /// The payload as it reads at [date]. Past midnight the day it describes is
  /// over, so today's line asks her to open the app; past Monday the week is
  /// new, so the count is zero of her target. Weeks are ISO weeks in her time
  /// zone, as `WeekKey` computes them in the app.
  static func make(_ payload: WidgetPayload?, at date: Date) -> WidgetModel {
    guard let p = payload, p.state == "open",
      let dayKey = p.dayKey, let weekId = p.weekId,
      let done = p.done, let target = p.target
    else {
      return WidgetModel(mode: .closed, lang: payload?.lang, closed: payload?.s.closed)
    }
    let sameWeek = weekId == Self.weekId(date)
    let sameDay = sameWeek && dayKey == Self.dayKey(date)
    let logged = sameDay && (p.meal ?? false)
    return WidgetModel(
      mode: .open,
      lang: p.lang,
      done: sameWeek ? max(done, 0) : 0,
      target: max(target, 1),
      title: p.s.title,
      todayTitle: p.s.today,
      week: sameWeek ? p.s.week : p.s.weekFresh,
      inline: sameWeek ? p.s.inline : p.s.inlineFresh,
      a11y: sameWeek ? p.s.a11y : p.s.a11yFresh,
      status: sameDay ? p.s.status : p.s.stale,
      meal: logged ? p.s.meal : p.s.mealNone,
      mealLogged: logged,
      closed: p.s.closed
    )
  }

  /// `yyyy-MM-dd` of [date] on this phone, Western digits. Gregorian whatever
  /// calendar the phone is set to, because the app's `dayKey` is.
  static func dayKey(_ date: Date) -> String {
    var gregorian = Calendar(identifier: .gregorian)
    gregorian.timeZone = .current
    let c = gregorian.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04ld-%02ld-%02ld", c.year ?? 0, c.month ?? 0, c.day ?? 0)
  }

  /// `yyyy-Www`, the ISO week [date] falls in on this phone.
  static func weekId(_ date: Date) -> String {
    var iso = Calendar(identifier: .iso8601)
    iso.timeZone = .current
    let c = iso.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
    return String(format: "%04ld-W%02ld", c.yearForWeekOfYear ?? 0, c.weekOfYear ?? 0)
  }
}
