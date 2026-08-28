import 'dart:convert';

/// Position-keyed XOR over UTF-8 bytes. Not a stream cipher: one pass, no
/// KSA/PRGA, no permutation table. The pepper is unique to this project.
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

String unveilBytes(List<int> encoded) {
  if (encoded.isEmpty) return '';
  final plain = List<int>.generate(encoded.length, (index) {
    final mask = _mask(index);
    return (encoded[index] ^ mask[0] ^ mask[1]) & 0xff;
  });
  return utf8.decode(plain);
}
