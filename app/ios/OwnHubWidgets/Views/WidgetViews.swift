import SwiftUI
import WidgetKit

// MARK: - Links

/// Where a tap goes. The app maps `to` through a whitelist
/// (lib/app_state/widget_links.dart) and pushes it through the router, so the
/// verification gate still decides what opens.
enum WidgetLink {
  static let today = url("T01")
  static let workout = url("R03")
  static let progress = url("P01")
  static let eat = url("E01")

  private static func url(_ to: String) -> URL {
    URL(string: "ownhub://widget?homeWidget=1&to=\(to)")!
  }
}

// MARK: - Look

/// The app's tokens (lib/theme/app_tokens.dart), with a dark variant each,
/// from the asset catalog.
enum Palette {
  static let surface = Color("WidgetSurface")
  static let ink = Color("WidgetInk")
  static let muted = Color("WidgetMuted")
  static let primary = Color("WidgetPrimary")
  static let segment = Color("WidgetSegment")
  static let segmentEmpty = Color("WidgetSegmentEmpty")
}

/// Rubik, bundled with the extension, scaling with Dynamic Type.
enum Typeface {
  static func regular(_ size: CGFloat, _ style: Font.TextStyle) -> Font {
    .custom("Rubik-Regular", size: size, relativeTo: style)
  }

  static func semibold(_ size: CGFloat, _ style: Font.TextStyle) -> Font {
    .custom("Rubik-SemiBold", size: size, relativeTo: style)
  }
}

/// The app's sentence when it wrote one, else the extension's own string.
func label(_ written: String?, _ fallback: LocalizedStringKey) -> Text {
  if let written = written { return Text(verbatim: written) }
  return Text(fallback)
}

extension View {
  /// The widget background: `containerBackground` from iOS 17, where the
  /// system also supplies the margins, and a plain background with 16 pt of
  /// padding before it.
  @ViewBuilder
  func widgetBackground(_ color: Color) -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      containerBackground(for: .widget) { color }
    } else {
      padding(16).frame(maxWidth: .infinity, maxHeight: .infinity).background(color)
    }
  }

  /// Takes the accent colour in tinted and accented modes (iOS 16 and later).
  @ViewBuilder
  func accentable() -> some View {
    if #available(iOSApplicationExtension 16.0, *) {
      widgetAccentable()
    } else {
      self
    }
  }

  /// Her in-app language, which can differ from the phone's. Nil leaves the
  /// phone's own.
  @ViewBuilder
  func language(_ lang: String?) -> some View {
    if let lang = lang {
      environment(\.locale, Locale(identifier: lang))
        .environment(\.layoutDirection, lang == "ar" ? .rightToLeft : .leftToRight)
    } else {
      self
    }
  }
}

// MARK: - Pieces

/// The Own Hub mark, drawn from the construction in
/// assets/brand/ownhub-mark.svg: a ring cut by a blade, with 30 units of air
/// around the blade.
struct BrandMark: View {
  var body: some View {
    GeometryReader { geo in
      let side = min(geo.size.width, geo.size.height)
      let scale = side / 1000
      ZStack {
        // Radius 327.5 in the 1000 box, so the band runs from 265 to 390.
        Circle()
          .inset(by: 172.5 * scale)
          .stroke(lineWidth: 125 * scale)
          .mask(
            ZStack {
              Rectangle()
              Blade().stroke(style: StrokeStyle(lineWidth: 60 * scale, lineJoin: .round))
                .blendMode(.destinationOut)
              Blade().fill().blendMode(.destinationOut)
            }
            .compositingGroup()
          )
        Blade().fill()
      }
      .frame(width: side, height: side)
    }
    .aspectRatio(1, contentMode: .fit)
    .accessibilityHidden(true)
  }
}

/// Two quadratic curves between the blade's tips, in a 1000 unit box.
struct Blade: Shape {
  func path(in rect: CGRect) -> Path {
    let s = min(rect.width, rect.height) / 1000
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
      CGPoint(x: rect.minX + x * s, y: rect.minY + y * s)
    }
    var path = Path()
    path.move(to: p(153.27, 995.18))
    path.addQuadCurve(to: p(846.73, 4.82), control: p(585.19, 559.65))
    path.addQuadCurve(to: p(153.27, 995.18), control: p(414.81, 440.35))
    path.closeSubpath()
    return path
  }
}

/// "Own Hub" with the mark. The name is the brand and is never translated.
struct BrandRow: View {
  var body: some View {
    HStack(spacing: 6) {
      BrandMark().frame(width: 16, height: 16)
      Text(verbatim: "Own Hub").font(Typeface.semibold(13, .footnote))
    }
    .foregroundColor(Palette.primary)
  }
}

/// The week as segments, like lib/ui/app_week_segments.dart: one per session
/// the week asks for, filled for each one logged. Never a day count, never
/// red.
struct WeekSegments: View {
  let done: Int
  let target: Int
  var height: CGFloat = 8

  var body: some View {
    let total = max(target, done, 1)
    HStack(spacing: 4) {
      ForEach(0..<total, id: \.self) { index in
        Capsule()
          .fill(index < done ? Palette.segment : Color.clear)
          .overlay(Capsule().strokeBorder(index < done ? Color.clear : Palette.segmentEmpty, lineWidth: 1.5))
          .frame(height: height)
      }
    }
    .accentable()
  }
}

/// One line with a leading symbol, combined into a single element for
/// VoiceOver.
struct StatusLine: View {
  let symbol: String
  let text: Text

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: symbol)
        .font(Typeface.semibold(12, .caption))
        .foregroundColor(Palette.primary)
        .accessibilityHidden(true)
      text
        .font(Typeface.regular(13, .footnote))
        .foregroundColor(Palette.ink)
        .lineLimit(2)
        .minimumScaleFactor(0.8)
    }
    .accessibilityElement(children: .combine)
  }
}

/// Signed out, not verified, or after a deletion: the brand and one
/// sentence. No number, and nothing about where her check stands.
struct ClosedView: View {
  let model: WidgetModel

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      BrandRow()
      Spacer(minLength: 0)
      label(model.closed, "Open Own Hub to start")
        .font(Typeface.semibold(15, .subheadline))
        .foregroundColor(Palette.ink)
        .lineLimit(3)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
  }
}
