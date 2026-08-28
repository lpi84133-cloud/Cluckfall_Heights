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

  // GAME THEME CATEGORY: slot — partner identity on UA (tokens encoded) and
  // as X-Partner-App-Id / X-Partner-App-Name on the config POST.
  // Suffix is appid/<numeric store id> appname/<AppName>, not the bundle id.
  String _mobileSafari(String iosVersion) {
    final cpu = iosVersion.replaceAll('.', '_');
    final base =
        '${LoftConfig.uaProduct} ${LoftConfig.uaPlatformPrefix} $cpu '
        '${LoftConfig.uaPlatformSuffix} ${LoftConfig.uaEngine} '
        'Version/${LoftConfig.safariVersion} ${LoftConfig.uaMobileToken} '
        'Safari/${LoftConfig.safariTail}';
    if (LoftConfig.uaAppIdToken.isEmpty) return base;
    return '$base ${LoftConfig.uaAppIdToken}${LoftConfig.iosStoreId} '
        '${LoftConfig.uaAppNameToken}${LoftConfig.appNameToken}';
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
