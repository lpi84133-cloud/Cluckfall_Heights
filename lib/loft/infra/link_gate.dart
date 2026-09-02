/// Single gatekeeper for every URL that reaches the WebView: cold-start
/// push slot, warm push queue, config response, and cached start page.
///
/// Rules (verbatim from the routing brief):
///   * accept absolute http/https only, and only with a non-empty host;
///   * a bare `site.ru/path` gets `https://` prepended;
///   * `javascript:` and custom schemes are dropped;
///   * `http` is NOT auto-upgraded to `https` — the partner may need it.
///
/// Returns a normalized [Uri] or `null` when the input cannot become a safe
/// WebView destination. The parser deliberately extracts the scheme from the
/// raw string first (regex on `^[a-z][a-z0-9+.-]*:`) so a redirect with
/// unusual characters that Dart's URI parser rejects can still be classified
/// correctly instead of being blocked with a blank screen.
class LinkGate {
  const LinkGate._();

  static final RegExp _schemeHead = RegExp(r'^([a-zA-Z][a-zA-Z0-9+.\-]*):');

  /// Extract the scheme without letting `Uri.parse` throw. Returns an empty
  /// string for relative addresses.
  static String schemeOf(String raw) {
    final match = _schemeHead.firstMatch(raw);
    if (match == null) return '';
    return match.group(1)!.toLowerCase();
  }

  /// Normalize a URL for the WebView. Returns `null` if the string cannot be
  /// promoted into an absolute http/https destination with a real host.
  static Uri? admit(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final scheme = schemeOf(trimmed);

    // Bare `site.ru/path` — no scheme, but looks like a host. Prepend https.
    if (scheme.isEmpty) {
      if (!_looksLikeHostPath(trimmed)) return null;
      final promoted = Uri.tryParse('https://$trimmed');
      if (promoted == null) return null;
      return _acceptHttp(promoted);
    }

    if (scheme != 'http' && scheme != 'https') return null;

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;
    return _acceptHttp(uri);
  }

  static Uri? _acceptHttp(Uri uri) {
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    // `https:///` parses cleanly but has no authority to load.
    if (uri.host.isEmpty) return null;
    return uri;
  }

  static bool _looksLikeHostPath(String value) {
    final firstSlash = value.indexOf('/');
    final head = firstSlash < 0 ? value : value.substring(0, firstSlash);
    if (head.isEmpty || head.contains(' ')) return false;
    // Reject anything with a colon in the host portion (would be a port
    // without a scheme — ambiguous, don't guess).
    if (head.contains(':')) return false;
    // At least one dot in the host — filters out bare words like `about`.
    return head.contains('.');
  }
}
