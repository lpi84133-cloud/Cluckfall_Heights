import 'package:cluckfall_heights/loft/infra/link_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LinkGate.admit', () {
    test('accepts absolute http and https with a real host', () {
      expect(
        LinkGate.admit('https://cluckfallheights.com/lp/xyz?token=1')?.host,
        'cluckfallheights.com',
      );
      expect(
        LinkGate.admit('http://partner.example/path')?.scheme,
        'http',
      );
    });

    test('rejects blanks, malformed URLs and hostless authorities', () {
      expect(LinkGate.admit(null), isNull);
      expect(LinkGate.admit(''), isNull);
      expect(LinkGate.admit('   '), isNull);
      expect(LinkGate.admit('https:///path'), isNull);
      expect(LinkGate.admit('https://'), isNull);
    });

    test('drops javascript and custom app schemes', () {
      expect(LinkGate.admit('javascript:alert(1)'), isNull);
      expect(LinkGate.admit('tg://resolve?domain=x'), isNull);
      expect(LinkGate.admit('viber://chat'), isNull);
      expect(LinkGate.admit('mailto:hi@x.com'), isNull);
    });

    test('promotes bare host+path to https, refuses ambiguous ones', () {
      expect(
        LinkGate.admit('cluckfallheights.com/lp')?.toString(),
        'https://cluckfallheights.com/lp',
      );
      // No dot → looks like a scheme fragment, not a host.
      expect(LinkGate.admit('about'), isNull);
      // A colon in the host portion is ambiguous with a scheme.
      expect(LinkGate.admit('foo.com:8080/x'), isNull);
    });

    test('does not upgrade http to https', () {
      expect(LinkGate.admit('http://x.com/p')?.scheme, 'http');
    });

    test('schemeOf reads from the raw string, tolerating unusual chars', () {
      // Uri.parse can trip on some unencoded characters; schemeOf must not.
      expect(LinkGate.schemeOf('https://x.com/a[b]c'), 'https');
      expect(LinkGate.schemeOf('/relative/path'), '');
      expect(LinkGate.schemeOf('JavaScript:doStuff()'), 'javascript');
    });
  });
}
