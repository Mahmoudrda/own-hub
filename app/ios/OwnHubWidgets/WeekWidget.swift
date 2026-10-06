import SwiftUI
import WidgetKit

/// "Your week": this week's sessions against her target, on the Home Screen
/// (small) and on the Lock Screen (circular, rectangular, inline).
///
/// The Lock Screen families are marked privacySensitive, so with "Allow access
/// when locked" off they show the placeholder. The payload holds nothing
/// sensitive in any case: no cycle, life stage, body or programme title.
struct WeekWidget: Widget {
  static let kind = "OwnHubWeek"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: Self.kind, provider: OwnHubProvider()) { entry in
      WeekWidgetView(model: entry.model)
    }
    .configurationDisplayName("Your week")
    .description("Sessions this week, at a glance. Nothing about your cycle or body.")
    .supportedFamilies(Self.families)
  }

  static var families: [WidgetFamily] {
    if #available(iOSApplicationExtension 16.0, *) {
      return [.systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline]
    }
    return [.systemSmall]
  }
}

struct WeekWidgetView: View {
  let model: WidgetModel
  @Environment(\.widgetFamily) private var family

  var body: some View {
    content
      .widgetURL(WidgetLink.today)
      .language(model.lang)
  }

  @ViewBuilder
  private var content: some View {
    if #available(iOSApplicationExtension 16.0, *) {
      switch family {
      case .accessoryCircular:
        WeekCircular(model: model).privacySensitive().widgetBackground(.clear)
      case .accessoryRectangular:
        WeekRectangular(model: model).privacySensitive().widgetBackground(.clear)
      case .accessoryInline:
        WeekInline(model: model).privacySensitive().widgetBackground(.clear)
      default:
        WeekSmall(model: model).widgetBackground(Palette.surface)
      }
    } else {
      WeekSmall(model: model).widgetBackground(Palette.surface)
    }
  }
}

/// Home Screen, small: brand, "This week", the segments, today's line.
struct WeekSmall: View {
  let model: WidgetModel

  var body: some View {
    if model.mode == .closed {
      ClosedView(model: model)
    } else {
      VStack(alignment: .leading, spacing: 8) {
        BrandRow()
        Spacer(minLength: 0)
        if model.mode == .preview {
          Text("Your week shows here")
            .font(Typeface.semibold(15, .subheadline))
            .foregroundColor(Palette.ink)
          WeekSegments(done: 0, target: model.target)
        } else {
          label(model.week, "This week")
            .font(Typeface.semibold(15, .subheadline))
            .foregroundColor(Palette.ink)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
          WeekSegments(done: model.done, target: model.target)
            .accessibilityElement()
            .accessibilityLabel(label(model.a11y, "This week"))
          Text(verbatim: model.status ?? "")
            .font(Typeface.regular(12, .caption))
            .foregroundColor(Palette.muted)
            .lineLimit(2)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
  }
}

/// Lock Screen, circular: a gauge of the week with the count in the middle.
@available(iOSApplicationExtension 16.0, *)
struct WeekCircular: View {
  let model: WidgetModel

  var body: some View {
    if model.mode == .open {
      Gauge(value: Double(min(model.done, model.target)), in: 0...Double(model.target)) {
        EmptyView()
      } currentValueLabel: {
        Text(verbatim: String(model.done))
          .font(Typeface.semibold(18, .title3))
      }
      .gaugeStyle(.accessoryCircularCapacity)
      .accentable()
      .accessibilityElement()
      .accessibilityLabel(label(model.a11y, "This week"))
    } else {
      ZStack {
        AccessoryWidgetBackground()
        BrandMark().padding(10)
      }
      .accessibilityLabel(Text(verbatim: "Own Hub"))
    }
  }
}

/// Lock Screen, rectangular: "Own Hub" and "This week, 1 of 3".
@available(iOSApplicationExtension 16.0, *)
struct WeekRectangular: View {
  let model: WidgetModel

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(verbatim: "Own Hub")
        .font(Typeface.semibold(13, .headline))
        .widgetAccentable()
      switch model.mode {
      case .open:
        label(model.week, "This week")
          .font(Typeface.regular(13, .body))
          .lineLimit(2)
      case .preview:
        Text("Your week shows here").font(Typeface.regular(13, .body))
      case .closed:
        label(model.closed, "Open Own Hub to start").font(Typeface.regular(13, .body))
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }
}

/// Lock Screen, inline: "1 of 3 this week".
@available(iOSApplicationExtension 16.0, *)
struct WeekInline: View {
  let model: WidgetModel

  var body: some View {
    switch model.mode {
    case .open:
      label(model.inline, "This week")
    case .preview:
      Text("Your week shows here")
    case .closed:
      label(model.closed, "Open Own Hub to start")
    }
  }
}

#if DEBUG
  struct WeekWidget_Previews: PreviewProvider {
    static let english = WidgetModel(
      mode: .open, lang: "en", done: 1, target: 3, title: "This week", todayTitle: "Today",
      week: "This week, 1 of 3", inline: "1 of 3 this week", a11y: "Sessions this week: 1 of 3",
      status: "Today's workout is ready", meal: "Log a meal", closed: "Open Own Hub to start")
    static let arabic = WidgetModel(
      mode: .open, lang: "ar", done: 2, target: 4, title: "هذا الأسبوع", todayTitle: "اليوم",
      week: "هذا الأسبوع، 2 من 4", inline: "2 من 4 هذا الأسبوع", a11y: "تمارين هذا الأسبوع: 2 من 4",
      status: "يومكِ بدأ", meal: "سجّلي وجبة", closed: "افتحي Own Hub للبدء")

    static var previews: some View {
      Group {
        WeekWidgetView(model: english)
          .previewContext(WidgetPreviewContext(family: .systemSmall))
        WeekWidgetView(model: arabic)
          .previewContext(WidgetPreviewContext(family: .systemSmall))
          .environment(\.colorScheme, .dark)
        WeekWidgetView(model: .preview)
          .previewContext(WidgetPreviewContext(family: .systemSmall))
        WeekWidgetView(model: WidgetModel(mode: .closed, lang: "ar", closed: "افتحي Own Hub للبدء"))
          .previewContext(WidgetPreviewContext(family: .systemSmall))
          .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
      }
    }
  }
#endif
