import 'dart:convert';

import 'package:cluckfall_heights/loft/config/loft_config.dart';
import 'package:cluckfall_heights/loft/core/loft_codec.dart';
import 'package:cluckfall_heights/loft/core/loft_models.dart';
import 'package:cluckfall_heights/loft/infra/lift_signal.dart';
import 'package:cluckfall_heights/loft/infra/span_agent.dart';
import 'package:cluckfall_heights/loft/loft_guide.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('2.1 decode round-trips and the gate ignores optional fields', () {
    const expected = <String, String>{
      'endpoint': 'https://cluckfallheights.com/config.php',
      'gcd': 'https://gcdsdk.appsflyer.com/install_data/v5.0/',
      'appsFlyerKey': 'PG6N5qRcCdbtsBJs7vTBre',
      'firebaseProjectNumber': '678828505645',
      'uaProduct': 'Mozilla/5.0',
      'uaPlatformPrefix': '(iPhone; CPU iPhone OS',
      'uaPlatformSuffix': 'like Mac OS X)',
      'uaEngine': 'AppleWebKit/605.1.15 (KHTML, like Gecko)',
      'uaMobileToken': 'Mobile/15E148',
      'safariVersion': '18.7',
      'safariTail': '604.1',
      'appNameToken': 'CluckfallHeights',
      'oneLinkHost': 'cluckfallheights.onelink.me',
    };

    final decoded = <String, String>{
      'endpoint': LoftConfig.endpoint,
      'gcd': LoftConfig.gcdBase,
      'appsFlyerKey': LoftConfig.appsFlyerKey,
      'firebaseProjectNumber': LoftConfig.firebaseProjectNumber,
      'uaProduct': LoftConfig.uaProduct,
      'uaPlatformPrefix': LoftConfig.uaPlatformPrefix,
      'uaPlatformSuffix': LoftConfig.uaPlatformSuffix,
      'uaEngine': LoftConfig.uaEngine,
      'uaMobileToken': LoftConfig.uaMobileToken,
      'safariVersion': LoftConfig.safariVersion,
      'safariTail': LoftConfig.safariTail,
      'appNameToken': LoftConfig.appNameToken,
      'oneLinkHost': LoftConfig.oneLinkHost,
    };

    for (final entry in expected.entries) {
      final bytes = _cloak(entry.value);
      expect(
        unveilBytes(bytes),
        entry.value,
        reason: 'cloak→unveil failed for ${entry.key}',
      );
      expect(
        decoded[entry.key],
        entry.value,
        reason: 'LoftConfig getter mismatch for ${entry.key}',
      );
    }

    expect(LoftConfig.privacyUrl, 'https://cluckfallheights.com/privacy-policy.html');
    expect(LoftConfig.supportUrl, 'https://cluckfallheights.com/support.html');
    expect(LoftConfig.grayCredentialsReady, isTrue);
    expect(LoftConfig.storeToken, 'id6802356905');
  });

  test('2.2 User-Agent is plain Mobile Safari — no appid/appname suffix', () {
    final agent = SpanAgent();
    final ua = agent.userAgent;

    expect(ua.startsWith('Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X)'), isTrue);
    expect(ua, contains('AppleWebKit/605.1.15 (KHTML, like Gecko)'));
    expect(ua, endsWith('Version/18.7 Mobile/15E148 Safari/604.1'));
    expect(ua.contains('appid/'), isFalse);
    expect(ua.contains('appname/'), isFalse);
    expect(ua.contains(LoftConfig.iosStoreId), isFalse);
    expect(ua.contains(LoftConfig.appNameToken), isFalse);
    expect(ua.contains('Dart'), isFalse);
    expect(ua.contains('Flutter'), isFalse);
    expect(ua.contains('CFNetwork'), isFalse);
    expect(ua.contains('Darwin'), isFalse);
    expect(ua.contains('WebView'), isFalse);
  });

  test('2.3–2.4 compose always has device fields and omits empty push keys', () async {
    final body = await LiftSignal(SpanAgent()).compose(
      locale: 'en_US',
      pushToken: null,
    );

    expect(body['os'], 'iOS');
    expect(body['bundle_id'], LoftConfig.bundleId);
    expect(body['store_id'], 'id6802356905');
    expect(body['locale'], 'en_US');
    expect(body.containsKey('af_id'), isTrue);
    expect(body['af_status'], isNot('Non-organic'));
    expect(body.containsKey('push_token'), isFalse);
    expect(body.containsKey('firebase_project_id'), isFalse);

    final withToken = await LiftSignal(SpanAgent()).compose(
      locale: 'ru_RU',
      pushToken: 'fcm-token-sample',
    );
    expect(withToken['push_token'], 'fcm-token-sample');
    expect(withToken['firebase_project_id'], '678828505645');
  });

  test('2.4 reply parser requires ok+url and GCD uses numeric store id', () {
    final accepted = LoftReply.fromJson(<String, dynamic>{
      'ok': true,
      'url': 'https://offer.example/path',
      'expires': 1710000000,
    });
    expect(accepted.hasDestination, isTrue);
    expect(accepted.url, 'https://offer.example/path');

    final rejected = LoftReply.fromJson(<String, dynamic>{
      'ok': false,
      'message': 'organic',
    });
    expect(rejected.hasDestination, isFalse);

    expect(LoftReply.rejected('network_failure').isAuthoritative, isFalse);
    expect(LoftReply.rejected('invalid_response').isAuthoritative, isFalse);
    expect(LoftReply.rejected('http_500').isAuthoritative, isFalse);
    expect(LoftReply.rejected('http_502').isAuthoritative, isFalse);
    expect(LoftReply.rejected('http_404').isAuthoritative, isTrue);
    expect(
      LoftReply.rejected('credentials_unavailable').isAuthoritative,
      isTrue,
    );
    expect(LoftConfig.organicRecheckLag, 11);
    expect(LoftConfig.firstSignalTimeout.inSeconds, 28);
    expect(
      LoftReply.fromJson(<String, dynamic>{
        'ok': false,
        'message': 'No data',
      }).isAuthoritative,
      isTrue,
    );

    expect(
      LoftGuide.isAttributionLink('https://cluckfallheights.onelink.me/abc/def'),
      isTrue,
    );
    expect(
      LoftGuide.isAttributionLink('https://cluckfallheights.com/abc'),
      isTrue,
    );
    expect(
      LoftGuide.isAttributionLink('https://web.team-s.club/offer'),
      isFalse,
    );

    expect(LoftConfig.gcdBase, endsWith('/install_data/v5.0/'));
    expect(LoftConfig.iosStoreId, '6802356905');
    expect(LoftConfig.iosStoreId.contains('.'), isFalse);
  });
}

List<int> _cloak(String value) {
  const pepper = <int>[
    0x4C,
    0x6F,
    0x66,
    0x74,
    0x43,
    0x66,
    0x68,
    0x2E,
    0x6B,
    0x38,
    0x32,
    0x78,
    0x2D,
    0x39,
    0x31,
  ];
  final bytes = utf8.encode(value);
  return List<int>.generate(bytes.length, (index) {
    final p = pepper[index * 13 % pepper.length];
    final extra = (index * 29 + 7) & 0xff;
    return (bytes[index] ^ p ^ extra) & 0xff;
  });
}
