import Flutter
import UIKit
import UserNotifications

/// Cold-start push destination capture for the gray-flow shell.
///
/// Matches HenheavenDash: a single key, notification-tap only, no host
/// filtering. Push URLs are backend-signed and go straight to the portal.
/// URL schemes and Universal Links are left to the plugins (AppsFlyer's
/// SDK collects OneLink attribution through its own hooks; those hosts must
/// never become a WebView destination).
class SceneDelegate: FlutterSceneDelegate {
  static let launchRouteKey = "flutter.cfh_cold_tap"

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    // Persist BEFORE super so the write is committed to UserDefaults before
    // the Flutter engine spins up and Dart hits TapPathReader.consume().
    // Otherwise the poll (~400 ms) can race a slow synchronize() and return
    // empty on a genuine cold-tap.
    if let response = connectionOptions.notificationResponse {
      Self.persistPush(from: response.notification.request.content.userInfo)
    }

    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }

  /// Push URL is trusted end-to-end — write without filtering. It might live
  /// on the brand's own domain when the backend routes through it. Called by
  /// [CfhTapCatcher] as well, for warm/background taps that don't go through
  /// `scene:willConnectTo:`.
  static func persistPush(from userInfo: [AnyHashable: Any]) {
    guard let raw = extractUrl(from: userInfo), !raw.isEmpty else { return }
    let defaults = UserDefaults.standard
    defaults.set(raw, forKey: launchRouteKey)
    defaults.synchronize()
    #if DEBUG
    NSLog("[CFH.ROUTE] captured push destination")
    #endif
  }

  private static func extractUrl(
    from payload: [AnyHashable: Any]
  ) -> String? {
    let candidates = ["url", "link", "target", "deeplink", "deep_link"]

    func firstValue(in dictionary: [AnyHashable: Any]) -> String? {
      for candidate in candidates {
        guard let value = dictionary[candidate] as? String else { continue }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
      }
      return nil
    }

    if let direct = firstValue(in: payload) { return direct }
    if let aps = payload["aps"] as? [AnyHashable: Any],
       let value = firstValue(in: aps) {
      return value
    }
    for container in ["payload", "data"] {
      if let nested = payload[container] as? [AnyHashable: Any],
         let value = firstValue(in: nested) {
        return value
      }
    }
    return nil
  }
}
