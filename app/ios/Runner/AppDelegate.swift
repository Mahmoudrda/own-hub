import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Training reminders and "your check is done" go through the app
    // delegate, which hands them to the notification plugins.
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Keeps the screen awake while a workout is live.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "OwnHubScreenAwake") {
      let channel = FlutterMethodChannel(
        name: "com.ownhub.app/screen",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { call, result in
        if call.method == "keepScreenOn" {
          UIApplication.shared.isIdleTimerDisabled = (call.arguments as? Bool) ?? false
          result(true)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }
}
