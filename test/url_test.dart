import 'dart:math';

import 'package:livr/livr.dart';
import 'package:test/test.dart';

final validator = Validator.untyped({'url': 'url'});

bool isUrl(String url) => validator.validate({'url': url}).isValid;

void expectValid(List<String> urls) {
  for (final url in urls) {
    expect(isUrl(url), isTrue, reason: url);
  }
}

void expectInvalid(List<String> urls) {
  for (final url in urls) {
    expect(isUrl(url), isFalse, reason: url);
  }
}

void expectInvalidWithin50Ms(List<String> urls) {
  // The first validation compiles the regular expression
  expect(isUrl('https://example.com/'), isTrue);

  // The best of three runs, so that a pause of the process does not count
  var ms = double.infinity;
  for (var run = 0; run < 3; run++) {
    final stopwatch = Stopwatch()..start();
    expectInvalid(urls);
    ms = min(ms, stopwatch.elapsedMicroseconds / 1000);
  }

  expect(ms, lessThan(50), reason: '${ms.toStringAsFixed(1)} ms');
}

void main() {
  test('url rejects invalid hosts quickly', () {
    expectInvalidWithin50Ms([
      'http://${'aaaa.' * 12}_',
      'http://${'aaaa-' * 12}_',
      'http://${'aaaa.' * 12}a!',
      'http://user@${'aaaa.' * 12}_',
      'http://${'a@' * 12}${'aaaa.' * 12}_',
      'http://${'a:@' * 100}${'aaaa.' * 10}_',
    ]);
  });

  test('url rejects long invalid values quickly', () {
    expectInvalidWithin50Ms([
      'http://${'aaaa.' * 400}_',
      'http://${'a' * 2000}!',
      'http://${'a@' * 1000}_',
      'http://${'a@a.com/' * 250} ',
    ]);
  });

  test('url rejects a dot after the host', () {
    expectInvalid([
      'https://example.com.',
      'https://www.google.',
      'https://example.com./path',
      'https://example.com.:8080',
      'https://example.com.?q=1',
      'http://127.0.0.1./',
    ]);
    expectValid(['https://example.com/file.', 'https://example.com/?q=a.']);
  });

  test('url accepts host labels of up to 63 characters', () {
    expectValid(['https://${'a' * 63}.com', 'https://example.${'a' * 63}']);
    expectInvalid(['https://${'a' * 64}.com', 'https://example.${'a' * 64}']);
  });

  test('url accepts ports from 0 to 65535', () {
    expectValid([
      'https://example.com:0',
      'https://example.com:8',
      'https://example.com:80/path',
      'https://example.com:00080',
      'https://example.com:65535',
      'http://192.0.2.1:8/',
    ]);
    expectInvalid([
      'https://example.com:65536',
      'https://example.com:99999',
      'https://example.com:123456',
    ]);
  });

  test(
    'url accepts Unicode hosts, localhost and IPv4 addresses like before',
    () {
      expectValid([
        'https://пример.рф',
        'https://münchen.de/straße',
        'http://localhost',
        'http://LOCALHOST:3000/x',
        'http://10.0.0.1/',
        'HTTP://127.0.0.1:3233/?param_1=123&param_2=asd',
        'https://user:pass@example.com',
      ]);
      expectInvalid([
        'http://intranet/',
        'http://0.0.0.0/',
        'http://1.2.3.255/',
        'http://224.0.0.1/',
        'http://256.1.1.1/',
        'https://example.c',
        'https://example.123',
        'https://example..com',
        'http://g_oogle.com',
      ]);
    },
  );
}
