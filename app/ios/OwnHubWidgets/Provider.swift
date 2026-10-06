import WidgetKit

struct OwnHubEntry: TimelineEntry {
  let date: Date
  let model: WidgetModel
}

/// One timeline for both widgets: now, the next midnight, and the next ISO
/// Monday. The app asks for a reload whenever the payload changes; these
/// entries only make the day and the week turn over on time without it.
struct OwnHubProvider: TimelineProvider {
  func placeholder(in context: Context) -> OwnHubEntry {
    OwnHubEntry(date: Date(), model: .preview)
  }

  func getSnapshot(in context: Context, completion: @escaping (OwnHubEntry) -> Void) {
    let now = Date()
    let model = context.isPreview ? WidgetModel.preview : WidgetModel.make(WidgetPayload.load(), at: now)
    completion(OwnHubEntry(date: now, model: model))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<OwnHubEntry>) -> Void) {
    let now = Date()
    let payload = WidgetPayload.load()
    let midnight = DateComponents(hour: 0, minute: 0, second: 0)
    var dates = [now]
    if let next = Calendar.current.nextDate(after: now, matching: midnight, matchingPolicy: .nextTime) {
      dates.append(next)
    }
    var iso = Calendar(identifier: .iso8601)
    iso.timeZone = .current
    var monday = midnight
    monday.weekday = 2
    if let next = iso.nextDate(after: now, matching: monday, matchingPolicy: .nextTime),
      !dates.contains(next)
    {
      dates.append(next)
    }
    let entries = dates.sorted().map { OwnHubEntry(date: $0, model: .make(payload, at: $0)) }
    completion(Timeline(entries: entries, policy: .atEnd))
  }
}
