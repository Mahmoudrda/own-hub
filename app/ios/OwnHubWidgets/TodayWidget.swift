import SwiftUI
import WidgetKit

/// "Today": the week, today's workout line and the meal line, each one tap
/// from its screen. Medium only: a large widget would have little genuine to
/// show.
///
/// Never the session or programme title. A title can name a life stage, so
/// the line says only that today's workout is ready, under way or done.
struct TodayWidget: Widget {
  static let kind = "OwnHubToday"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: Self.kind, provider: OwnHubProvider()) { entry in
      TodayWidgetView(model: entry.model)
    }
    .configurationDisplayName("Today")
    .description("Today's workout and meal, one tap away.")
    .supportedFamilies([.systemMedium])
  }
}

struct TodayWidgetView: View {
  let model: WidgetModel

  var body: some View {
    content
      .widgetBackground(Palette.surface)
      .widgetURL(WidgetLink.today)
      .language(model.lang)
  }

  @ViewBuilder
  private var content: some View {
    switch model.mode {
    case .closed:
      ClosedView(model: model)
    case .preview:
      VStack(alignment: .leading, spacing: 10) {
        BrandRow()
        Spacer(minLength: 0)
        Text("Your week shows here")
          .font(Typeface.semibold(15, .subheadline))
          .foregroundColor(Palette.ink)
        WeekSegments(done: 0, target: model.target)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    case .open:
      VStack(alignment: .leading, spacing: 10) {
        HStack {
          BrandRow()
          Spacer(minLength: 8)
          label(model.todayTitle, "Today")
            .font(Typeface.semibold(13, .footnote))
            .foregroundColor(Palette.muted)
        }
        Link(destination: WidgetLink.progress) {
          VStack(alignment: .leading, spacing: 6) {
            label(model.week, "This week")
              .font(Typeface.semibold(15, .subheadline))
              .foregroundColor(Palette.ink)
              .lineLimit(1)
              .minimumScaleFactor(0.8)
            WeekSegments(done: model.done, target: model.target)
          }
          .accessibilityElement()
          .accessibilityLabel(label(model.a11y, "This week"))
        }
        Spacer(minLength: 0)
        Link(destination: WidgetLink.workout) {
          StatusLine(symbol: "figure.walk", text: Text(verbatim: model.status ?? ""))
        }
        Link(destination: WidgetLink.eat) {
          StatusLine(
            symbol: model.mealLogged ? "checkmark.circle" : "fork.knife",
            text: Text(verbatim: model.meal ?? ""))
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
  }
}

#if DEBUG
  struct TodayWidget_Previews: PreviewProvider {
    static var previews: some View {
      Group {
        TodayWidgetView(model: WeekWidget_Previews.english)
          .previewContext(WidgetPreviewContext(family: .systemMedium))
        TodayWidgetView(model: WeekWidget_Previews.arabic)
          .previewContext(WidgetPreviewContext(family: .systemMedium))
          .environment(\.colorScheme, .dark)
        TodayWidgetView(model: .preview)
          .previewContext(WidgetPreviewContext(family: .systemMedium))
      }
    }
  }
#endif
