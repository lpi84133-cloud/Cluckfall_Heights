enum SpanRoute {
  native,
  portal,
  undecided;

  String get storageValue => switch (this) {
    SpanRoute.native => 'shelf',
    SpanRoute.portal => 'span',
    SpanRoute.undecided => 'open',
  };

  static SpanRoute parse(String? value) => switch (value) {
    'span' || 'portal' || 'web' => SpanRoute.portal,
    'shelf' || 'native' || 'game' => SpanRoute.native,
    _ => SpanRoute.undecided,
  };
}

class LoftReply {
  const LoftReply({
    required this.accepted,
    this.url,
    this.expiresAt,
    this.reason,
  });

  factory LoftReply.fromJson(Map<String, dynamic> json) {
    final rawExpiry = json['expires'];
    final ok = json['ok'];
    final rawUrl = json['url'] ?? json['link'] ?? json['target'];
    return LoftReply(
      accepted: ok == true || ok == 1 || ok == 'true' || ok == '1',
      url: rawUrl is String ? rawUrl : null,
      expiresAt: rawExpiry is num
          ? rawExpiry.toInt()
          : int.tryParse(rawExpiry?.toString() ?? ''),
      reason: json['message']?.toString(),
    );
  }

  factory LoftReply.rejected(String reason) =>
      LoftReply(accepted: false, reason: reason);

  final bool accepted;
  final String? url;
  final int? expiresAt;
  final String? reason;

  bool get hasDestination => accepted && (url?.isNotEmpty ?? false);

  /// A real answer from the config host. Timeouts, 5xx and parse errors
  /// are not a first-launch decision — the route stays undecided.
  bool get isAuthoritative {
    if (reason == 'network_failure' || reason == 'invalid_response') {
      return false;
    }
    if (reason == 'credentials_unavailable') return true;
    if (reason != null && reason!.startsWith('http_')) {
      return reason == 'http_404';
    }
    return true;
  }
}

sealed class LoftDestination {
  const LoftDestination();
}

final class NativeSpan extends LoftDestination {
  const NativeSpan();
}

final class PortalSpan extends LoftDestination {
  const PortalSpan(this.url, {this.coldLaunch = false});

  final String url;
  final bool coldLaunch;
}

final class QuietSpan extends LoftDestination {
  const QuietSpan({required this.returnToNative});

  final bool returnToNative;
}
