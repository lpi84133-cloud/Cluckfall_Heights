import Flutter
import UIKit
import UserNotifications

class SceneDelegate: FlutterSceneDelegate {
  static let launchRouteKey = "flutter.cfh_tap_path"

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    if let response = connectionOptions.notificationResponse {
      Self.persistDestination(
        Self.destination(inside: response.notification.request.content.userInfo)
      )
    }
    if let url = connectionOptions.urlContexts.first?.url {
      Self.persistDestination(url.absoluteString)
    }
    for activity in connectionOptions.userActivities {
      if activity.activityType == NSUserActivityTypeBrowsingWeb,
         let url = activity.webpageURL {
        Self.persistDestination(url.absoluteString)
      }
    }
    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    if let url = URLContexts.first?.url {
      Self.persistDestination(url.absoluteString)
    }
    super.scene(scene, openURLContexts: URLContexts)
  }

  override func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
       let url = userActivity.webpageURL {
      Self.persistDestination(url.absoluteString)
    }
    super.scene(scene, continue: userActivity)
  }

  private static func persistDestination(_ raw: String?) {
    guard let raw, !raw.isEmpty else { return }
    guard let url = URL(string: raw), let host = url.host?.lowercased() else { return }
    // OneLink is attribution, not a WebView address.
    if host.hasSuffix("onelink.me") { return }
    guard url.scheme == "http" || url.scheme == "https" else { return }
    let defaults = UserDefaults.standard
    defaults.set(raw, forKey: launchRouteKey)
    defaults.synchronize()
    #if DEBUG
    NSLog("[CFH.ROUTE] captured destination")
    #endif
  }

  private static func destination(
    inside payload: [AnyHashable: Any]
  ) -> String? {
    let candidates = ["deep_link", "target", "url", "deeplink", "link"]

    func firstValue(in dictionary: [AnyHashable: Any]) -> String? {
      for candidate in candidates {
        guard let value = dictionary[candidate] as? String else { continue }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
      }
      return nil
    }

    if let direct = firstValue(in: payload) { return direct }

    for container in ["payload", "data"] {
      if let nested = payload[container] as? [AnyHashable: Any],
         let value = firstValue(in: nested) {
        return value
      }
    }
    return nil
  }
}
