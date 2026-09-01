// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

const List<int> _loftPepper = <int>[
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

List<int> _mask(int index) {
  final pepper = _loftPepper[index * 13 % _loftPepper.length];
  return <int>[pepper, (index * 29 + 7) & 0xff];
}

List<int> cloak(String value) {
  final bytes = utf8.encode(value);
  return List<int>.generate(bytes.length, (index) {
    final mask = _mask(index);
    return (bytes[index] ^ mask[0] ^ mask[1]) & 0xff;
  });
}

String unveil(List<int> encoded) {
  final plain = List<int>.generate(encoded.length, (index) {
    final mask = _mask(index);
    return (encoded[index] ^ mask[0] ^ mask[1]) & 0xff;
  });
  return utf8.decode(plain);
}

void main() {
  const values = <String, String>{
    'endpoint': 'https://cluckfallheights.com/config.php',
    'gcd': 'https://gcdsdk.appsflyer.com/install_data/v5.0/',
    'appsFlyerDevKey': 'PG6N5qRcCdbtsBJs7vTBre',
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

  for (final entry in values.entries) {
    final encoded = cloak(entry.value);
    stdout.writeln('${entry.key}: <int>[${encoded.join(', ')}]');
    if (unveil(encoded) != entry.value) {
      throw StateError('Round-trip failed for ${entry.key}');
    }
  }
  stdout.writeln('VERIFY: all values round-tripped');
}
