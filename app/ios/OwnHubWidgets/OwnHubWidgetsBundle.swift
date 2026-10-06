import SwiftUI
import WidgetKit

// The Own Hub widgets. Both read the one payload the app writes to the App
// Group (lib/app_state/home_widget_sync.dart) and nothing else: this
// extension links no Flutter, no pods and no network code.
@main
struct OwnHubWidgetsBundle: WidgetBundle {
  var body: some Widget {
    WeekWidget()
    TodayWidget()
  }
}
