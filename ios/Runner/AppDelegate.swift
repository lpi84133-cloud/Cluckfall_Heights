import Flutter
import UIKit
import UserNotifications
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Required by flutter_local_notifications so the planner's own reminders
    // are delivered to it. Notification *taps* are deliberately not handled
    // here: a tap on a remote push reaches Dart through firebase_messaging,
    // and a tap that launched the app is parked by SceneDelegate. Nothing in
    // this file may read launchOptions[.remoteNotification] — a silent wake
    // would then write a stale URL and hijack the next ordinary launch.
    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    // Deliberately this early: firebase_messaging parks the APNs token until
    // Dart configures Firebase, and it only ever sees the token when
    // registration happened during launch.
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
