// Reads the test suite from test/test_suite_2.5 with dart:io
@TestOn('vm')
library;

import 'dart:math';

import 'package:livr/livr.dart';
import 'package:test/test.dart';

import 'support/test_suite.dart';

// The format and checksum rules of LIVR 2.5 are scanners. Each one must accept
// exactly the strings of the regular expression of the JavaScript
// implementation (with its extra checks), on the values of the test suite and
// on random edits of them
final class FormatCase {
  FormatCase(
    this.rules,
    this.isValid,
    this.alphabet, [
    this.samples = const [],
  ]);

  final Object rules;
  final bool Function(String) isValid;

  // The characters of random edits
  final String alphabet;
  final List<String> samples;
}

bool Function(String) matches(String pattern) {
  final re = RegExp(pattern);
  return re.hasMatch;
}

const String hexAlphabet = '0123456789abcdefABCDEFgG-:.#x';
const String ipv4Byte = '(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])';
const String uuidRe =
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$';

final RegExp hostnameRe = RegExp(
  r'^[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$',
);
final RegExp lastLabelDigitsRe = RegExp(r'(?:^|\.)[0-9]+$');
final RegExp jwtRe = RegExp(
  r'^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]*$',
);
final RegExp ibanRe = RegExp(r'^[A-Z]{2}[0-9]{2}[A-Z0-9]{11,30}$');

bool hasLuhnChecksum(String digits) {
  var sum = 0;
  for (var i = 0; i < digits.length; i++) {
    var digit = int.parse(digits[digits.length - 1 - i]);
    if (i.isOdd) digit = digit * 2 > 9 ? digit * 2 - 9 : digit * 2;
    sum += digit;
  }
  return sum % 10 == 0;
}

bool hasIbanChecksum(String iban) {
  final moved = iban.substring(4) + iban.substring(0, 4);
  final digits = moved.split('').map((c) {
    final code = c.codeUnitAt(0);
    return code >= 0x41 ? '${code - 55}' : c;
  }).join();
  return BigInt.parse(digits) % BigInt.from(97) == BigInt.one;
}

final Map<String, FormatCase> formatCases = {
  'hex': FormatCase('hex', matches(r'^[0-9a-fA-F]+$'), hexAlphabet, [
    'deadBEEF',
    '0',
  ]),
  'mongo_id': FormatCase(
    'mongo_id',
    matches(r'^[0-9a-fA-F]{24}$'),
    hexAlphabet,
    ['507f1f77bcf86cd799439011'],
  ),
  'hex_color': FormatCase(
    'hex_color',
    matches(r'^#(?:[0-9a-fA-F]{3,4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$'),
    hexAlphabet,
    ['#fff', '#ffff', '#a0b1c2', '#a0b1c2d3'],
  ),
  'e164': FormatCase(
    'e164',
    matches(r'^\+[1-9][0-9]{6,14}$'),
    '+0123456789 -',
    ['+380441234567', '+1234567'],
  ),
  'uuid': FormatCase(
    'uuid',
    (str) =>
        RegExp(uuidRe).hasMatch(str) ||
        RegExp(
          r'^(?:00000000-0000-0000-0000-000000000000|ffffffff-ffff-ffff-ffff-ffffffffffff)$',
          caseSensitive: false,
        ).hasMatch(str),
    hexAlphabet,
    [
      '123e4567-e89b-12d3-a456-426614174000',
      '00000000-0000-0000-0000-000000000000',
      'FFFFFFFF-ffff-FFFF-ffff-FFFFFFFFFFFF',
    ],
  ),
  'uuid v4 v7': FormatCase(
    {
      'uuid': ['v4', 'v7'],
    },
    (str) => RegExp(uuidRe).hasMatch(str) && (str[14] == '4' || str[14] == '7'),
    hexAlphabet,
    [
      '123e4567-e89b-42d3-a456-426614174000',
      '017f22e2-79b0-7cc3-98c4-dc0c0c07398f',
    ],
  ),
  'ip v4': FormatCase(
    {'ip': 'v4'},
    matches('^(?:$ipv4Byte\\.){3}$ipv4Byte\$'),
    '0123456789.:',
    ['192.0.2.1', '255.255.255.255', '0.0.0.0', '10.20.30.40'],
  ),
  'hostname': FormatCase(
    'hostname',
    (str) =>
        str.length <= 253 &&
        hostnameRe.hasMatch(str) &&
        !lastLabelDigitsRe.hasMatch(str),
    'aZ09-._ ',
    ['example.com', 'localhost', 'a-b.c-d.e1', '192.0.2.1', 'x.${'a' * 63}'],
  ),
  'base64': FormatCase(
    'base64',
    matches(
      r'^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$',
    ),
    'Az09+/=-_ ',
    ['aGVsbG8=', 'aGk=', 'aGVsbG8gd29ybGQ='],
  ),
  'base64 url': FormatCase(
    {'base64': 'url'},
    matches(
      r'^(?:[A-Za-z0-9_-]{4})*(?:[A-Za-z0-9_-]{2}(?:==)?|[A-Za-z0-9_-]{3}=?)?$',
    ),
    'Az09+/=-_ ',
    ['aGVsbG8', 'aGk', 'aGk=', 'SA==', 'SA'],
  ),
  'mac': FormatCase(
    'mac',
    matches(r'^[0-9a-fA-F]{2}([:-])[0-9a-fA-F]{2}(?:\1[0-9a-fA-F]{2}){4}$'),
    hexAlphabet,
    ['00:1A:2b:3c:4D:5e', '00-1a-2b-3c-4d-5e'],
  ),
  'mac 64': FormatCase(
    {'mac': 64},
    matches(r'^[0-9a-fA-F]{2}([:-])[0-9a-fA-F]{2}(?:\1[0-9a-fA-F]{2}){6}$'),
    hexAlphabet,
    ['70-B3-D5-7E-D0-00-12-34', '70:b3:d5:7e:d0:00:12:34'],
  ),
  'semver': FormatCase(
    'semver',
    matches(
      r'^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-((?:0|[1-9][0-9]*|[0-9]*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9][0-9]*|[0-9]*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$',
    ),
    '0123a-+.Z',
    ['1.2.3', '1.0.0-rc.1', '1.0.0-0.3.7+build.5', '10.20.30-x-y.0a+001'],
  ),
  'jwt': FormatCase(
    'jwt',
    (str) =>
        jwtRe.hasMatch(str) &&
        str.split('.').every((segment) => segment.length % 4 != 1),
    'aZ09-_.=+',
    ['eyJh.eyJz.c2ln', 'eyJhbGciOiJub25lIn0.eyJzdWIiOiIxIn0.', 'abcd.ef.gh'],
  ),
  'luhn': FormatCase(
    'luhn',
    (str) => RegExp(r'^[0-9]{2,}$').hasMatch(str) && hasLuhnChecksum(str),
    '0123456789 -',
    ['79927398713', '18', '00'],
  ),
  'credit_card': FormatCase(
    'credit_card',
    (str) => RegExp(r'^[0-9]{12,19}$').hasMatch(str) && hasLuhnChecksum(str),
    '0123456789 -',
    ['4111111111111111', '378282246310005', '6011111111111117'],
  ),
  'iban': FormatCase(
    'iban',
    (str) => ibanRe.hasMatch(str) && hasIbanChecksum(str),
    'GB82WEST0123456789az ',
    ['GB82WEST12345698765432', 'UA213223130000026007233566001'],
  ),
};

void main() {
  // The values of the format and checksum cases of the 2.5 suite
  final suiteValues = <String>[];
  for (final suite in ['positive', 'negative']) {
    for (final suiteCase in loadSuite(suite, dir: testSuite25Dir)) {
      final input = suiteCase.input;
      if (input is Map<String, Object?>) {
        suiteValues.addAll(input.values.whereType<String>());
      }
    }
  }

  for (final MapEntry(key: name, value: formatCase) in formatCases.entries) {
    final validator = Validator.untyped({'value': formatCase.rules});
    bool isValid(String str) => validator.validate({'value': str}).isValid;

    test('$name agrees with the JavaScript implementation', () {
      final strings = [...suiteValues, ...formatCase.samples];
      for (final str in strings.where((s) => s.isNotEmpty)) {
        expect(isValid(str), formatCase.isValid(str), reason: str);
      }

      // Random edits of the samples: replaced, inserted and deleted
      // characters
      final random = Random(42);
      final alphabet = formatCase.alphabet;
      for (var i = 0; i < 20000; i++) {
        final chars = formatCase
            .samples[random.nextInt(formatCase.samples.length)]
            .split('');
        for (var edits = random.nextInt(3) + 1; edits > 0; edits--) {
          final char = alphabet[random.nextInt(alphabet.length)];
          final at = random.nextInt(chars.length + 1);
          switch (random.nextInt(3)) {
            case 0 when at < chars.length:
              chars[at] = char;
            case 1:
              chars.insert(at, char);
            case _ when chars.length > 1 && at < chars.length:
              chars.removeAt(at);
          }
        }
        final str = chars.join();
        if (str.isEmpty) continue;
        expect(isValid(str), formatCase.isValid(str), reason: str);
      }
    });
  }
}
