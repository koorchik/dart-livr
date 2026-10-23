import 'dart:math';

import 'package:livr/livr.dart';
import 'package:test/test.dart';

import 'support/test_suite.dart';

// The regular expression of the JavaScript implementation: the email rule is a
// scanner that must accept exactly the same strings
final RegExp jsEmailRe = RegExp(
  r'^(?:[^<>()\[\]\\.,;:\s@"]+(?:\.[^<>()\[\]\\.,;:\s@"]+)*|"[^@\n\r  ]+")'
  r'@(?:\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\]|(?:[a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,})$',
);

final validator = Validator.untyped({'email': 'email'});

bool isEmail(String str) => validator.validate({'email': str}).isValid;

void main() {
  test('agrees with the JavaScript regular expression on the test suite', () {
    final emails = <String>[];
    for (final suite in ['positive', 'negative']) {
      for (final suiteCase in loadSuite(suite)) {
        if (!suiteCase.name.endsWith('email')) continue;
        final input = suiteCase.input as Map<String, Object?>;
        emails.addAll(input.values.whereType<String>());
      }
    }
    expect(emails, hasLength(greaterThan(50)));

    for (final email in emails.where((e) => e.isNotEmpty)) {
      expect(isEmail(email), jsEmailRe.hasMatch(email), reason: email);
    }
  });

  test('agrees with the JavaScript regular expression on edge cases', () {
    for (final email in [
      'a@b.cc',
      'a@b.c',
      'a@b',
      'a@.cc',
      'a@b..cc',
      'a@b.cc.',
      'a@-.cc',
      'a@b.c1',
      'a@1.cc',
      'a@B.CC',
      'a@b_c.cc',
      '@b.cc',
      'a@',
      'a@@b.cc',
      'a.b@c.dd',
      '.a@c.dd',
      'a.@c.dd',
      'a..b@c.dd',
      'a b@c.dd',
      'a b@c.dd',
      'a b@c.dd',
      'a　@c.dd',
      'ä@c.dd',
      '😀@c.dd',
      'a@ä.dd',
      '"a"@c.dd',
      '""@c.dd',
      '"a b"@c.dd',
      '"a"b"@c.dd',
      '"a\nb"@c.dd',
      '"a@c.dd',
      'a"@c.dd',
      '"a".b@c.dd',
      'a@[1.2.3.4]',
      'a@[1.2.3]',
      'a@[1.2.3.4.5]',
      'a@[1234.2.3.4]',
      'a@[1.2.3.]',
      'a@[.1.2.3]',
      'a@[1.2.3.4',
      'a@[]',
      'a@[1..3.4]',
      'a<b@c.dd',
      'a(b@c.dd',
      'a;b@c.dd',
      'a\\b@c.dd',
      'a\tb@c.dd',
      'a@c.dd\n',
      '\na@c.dd',
      'a@c.d-d',
      'a@c-d.ee',
    ]) {
      expect(isEmail(email), jsEmailRe.hasMatch(email), reason: email);
    }
  });

  test('agrees with the JavaScript regular expression on random strings', () {
    // Characters that matter for the grammar, plus a few others
    const alphabet = [
      'a',
      'Z',
      '0',
      '9',
      '-',
      '_',
      '.',
      '@',
      '"',
      '[',
      ']',
      ' ',
      '\n',
      ',',
      ' ',
      'ä',
      ' ',
      '+',
      '(',
    ];
    final random = Random(42);
    var matches = 0;
    String pick() => alphabet[random.nextInt(alphabet.length)];

    for (var i = 0; i < 200000; i++) {
      final buffer = StringBuffer();
      final length = random.nextInt(12);
      for (var j = 0; j < length; j++) {
        buffer.write(pick());
      }
      // Bias towards the shape of an address
      if (random.nextBool()) {
        buffer
          ..write('@')
          ..write(random.nextBool() ? 'ab' : pick())
          ..write('.')
          ..write(random.nextBool() ? 'cd' : pick() + pick());
      }
      final str = buffer.toString();
      if (str.isEmpty) continue;
      final isMatch = jsEmailRe.hasMatch(str);
      if (isMatch) matches++;
      expect(isEmail(str), isMatch, reason: str);
    }
    // The strings must test both outcomes
    expect(matches, greaterThan(1000));
  });
}
