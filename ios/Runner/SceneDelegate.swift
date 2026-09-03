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
    // Same priority as BeamHub._extract: offer lives in `deep_link`,
    // while `url` is often the partner landing / start page. Taking
    // `url` first opens the wrong page on a fresh test-site push.
    let candidates = ["deep_link", "target", "url", "deeplink", "link"]

    if let direct = webLink(in: payload, candidates: candidates) {
      return direct
    }
    for container in ["payload", "data"] {
      guard let nested = payload[container] as? [AnyHashable: Any] else {
        continue
      }
      if let found = webLink(in: nested, candidates: candidates) {
        return found
      }
    }
    return nil
  }

  /// Skip non-http values and keep walking the candidate list. A bare
  /// string in `url` must not beat a real `deep_link` offer.
  private static func webLink(
    in fields: [AnyHashable: Any],
    candidates: [String]
  ) -> String? {
    for candidate in candidates {
      guard let raw = fields[candidate] as? String else { continue }
      let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
      guard
        let parsed = URL(string: trimmed),
        let scheme = parsed.scheme?.lowercased(),
        scheme == "https" || scheme == "http",
        parsed.host?.isEmpty == false
      else { continue }
      return trimmed
    }
    return nil
  }
}
