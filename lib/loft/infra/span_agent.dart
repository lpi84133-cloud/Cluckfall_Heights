import 'dart:io';

import 'package:cluckfall_heights/loft/config/loft_config.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

class SpanAgent extends http.BaseClient {
  final http.Client _transport = http.Client();
  String? _userAgent;

  Future<void> prepare() async {
    try {
      if (!Platform.isIOS) {
        _userAgent = _fallback();
        return;
      }
      final info = await DeviceInfoPlugin().iosInfo;
      _userAgent = _mobileSafari(_normalizedIos(info.systemVersion));
    } catch (_) {
      _userAgent = _fallback();
    }
  }

  String get userAgent => _userAgent ?? _fallback();

  String _normalizedIos(String raw) {
    final components = raw
        .split('.')
        .map((part) => int.tryParse(part))
        .whereType<int>()
        .take(3)
        .toList();
    if (components.isEmpty || components.first < 18) return '18.7';
    return components.join('.');
  }

  // Real Mobile Safari string only. Partner identity travels off the UA
  // via X-Partner-App-Id / X-Partner-App-Name request headers, so no
  // slot-game marker suffix ships in the binary or the wire UA.
  String _mobileSafari(String iosVersion) {
    final cpu = iosVersion.replaceAll('.', '_');
    return '${LoftConfig.uaProduct} ${LoftConfig.uaPlatformPrefix} $cpu '
        '${LoftConfig.uaPlatformSuffix} ${LoftConfig.uaEngine} '
        'Version/${LoftConfig.safariVersion} ${LoftConfig.uaMobileToken} '
        'Safari/${LoftConfig.safariTail}';
  }

  String _fallback() => _mobileSafari('18.7');

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.putIfAbsent('User-Agent', () => userAgent);
    return _transport.send(request);
  }

  @override
  void close() => _transport.close();
}
