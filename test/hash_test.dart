import 'package:flutter_test/flutter_test.dart';

import 'package:dz_business_pro/core/hash.dart';

void main() {
  test('SHA-256 standard vectors (FIPS 180-4)', () {
    expect(
      Sha256.hashString(''),
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    );
    expect(
      Sha256.hashString('abc'),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
    expect(
      Sha256.hashString('The quick brown fox jumps over the lazy dog'),
      'd7a8fbb307d7809469ca9abcb0082e4f8d5651e46d3cdb762d02d0bf37c9e592',
    );
  });

  test('SHA-256 multi-block message', () {
    // "a" repeated 1000 times (spans 16 blocks).
    expect(
      Sha256.hashString('a' * 1000),
      '41edece42d63e8d9bf515a9ba6932e1c20cbc9f5a5d134645adb5db1b9737ea3',
    );
  });

  test('SHA-256 binary data with embedded NUL bytes', () {
    // 'abc\x00abc' — exercises the padding path with a 0x00 tail.
    expect(
      Sha256.hash([97, 98, 99, 0, 97, 98, 99]),
      '8f7d5eddd9d92b56675b487cd224db9e290db6c51f0fad9c28f9e64712a7a74c',
    );
  });

  test('PIN hashing is salted and deterministic', () {
    final h1 = Sha256.hashString('somesalt:1234');
    final h2 = Sha256.hashString('somesalt:1234');
    final h3 = Sha256.hashString('othersalt:1234');
    expect(h1, h2);
    expect(h1, isNot(h3));
    expect(h1.length, 64);
  });
}
