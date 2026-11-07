import 'package:livr/livr.dart';
import 'package:livr/util.dart';
import 'package:test/test.dart';

Object? errorsOf(ValidationResult<Object?> result) =>
    (result as ValidationFailure).errors;

Map<String, Object?> outputOf(ValidationResult<Map<String, Object?>> result) =>
    (result as ValidationSuccess<Map<String, Object?>>).output;

void main() {
  group('now', () {
    test('is called on every validation, not when the validator is built', () {
      var now = DateTime.utc(2026, 10, 18, 12);
      var calls = 0;
      final validator = Validator.untyped(
        {
          'date': {
            'iso_date': {'max': 'today'},
          },
        },
        now: () {
          calls++;
          return now;
        },
      );
      expect(calls, 0);

      expect(validator.validate({'date': '2026-10-19'}).isValid, isFalse);
      now = DateTime.utc(2026, 10, 19);
      expect(validator.validate({'date': '2026-10-19'}).isValid, isTrue);
      expect(calls, 2);
    });

    test('days are UTC days, whatever the time zone of the clock', () {
      // 2026-10-18T23:30:00-05:00 is 2026-10-19 in UTC
      final now = DateTime.parse('2026-10-18T23:30:00-05:00').toLocal();
      final validator = Validator.untyped({
        'date': {
          'iso_date': {'min': 'today', 'max': 'today'},
        },
        'at': {
          'iso_datetime': {'min': 'yesterday', 'max': 'yesterday'},
        },
      }, now: () => now);

      expect(
        outputOf(
          validator.validate({
            'date': '2026-10-19',
            'at': '2026-10-18T23:59:59.999Z',
          }),
        ),
        {'date': '2026-10-19', 'at': '2026-10-18T23:59:59.999Z'},
      );
      expect(
        errorsOf(
          validator.validate({
            'date': '2026-10-18',
            'at': '2026-10-19T00:00:00Z',
          }),
        ),
        {'date': 'DATE_TOO_EARLY', 'at': 'DATETIME_TOO_LATE'},
      );
    });

    test('follows days, months and years', () {
      var now = DateTime.utc(2024, 2, 28, 23, 59);
      final validator = Validator.untyped({
        'date': {
          'iso_date': {'min': 'tomorrow', 'max': 'tomorrow'},
        },
      }, now: () => now);

      expect(validator.validate({'date': '2024-02-29'}).isValid, isTrue);
      now = DateTime.utc(2024, 12, 31);
      expect(validator.validate({'date': '2025-01-01'}).isValid, isTrue);
      now = DateTime.utc(1969, 12, 31, 12);
      expect(validator.validate({'date': '1970-01-01'}).isValid, isTrue);
    });

    test('reaches metarules, aliases and default aliases', () {
      final now = DateTime.utc(2000, 1, 1);
      final before = {
        'iso_date': {'max': 'today'},
      };
      final validator = Validator.untyped(
        {
          'list': {'list_of': before},
          'object': {
            'nested_object': {'date': before},
          },
          'alias': 'not_in_future',
          'when': {
            'when': ['list', 'any', before],
          },
        },
        aliases: [LivrAlias(name: 'not_in_future', rules: before)],
        now: () => now,
      );

      expect(
        errorsOf(
          validator.validate({
            'list': ['2000-01-02'],
            'object': {'date': '2000-01-02'},
            'alias': '2000-01-02',
            'when': '2000-01-02',
          }),
        ),
        {
          'list': ['DATE_TOO_LATE'],
          'object': {'date': 'DATE_TOO_LATE'},
          'alias': 'DATE_TOO_LATE',
          'when': 'DATE_TOO_LATE',
        },
      );
    });

    test('is the system time by default', () {
      final validator = Validator.untyped({
        'date': {
          'iso_date': {'min': 'yesterday', 'max': 'tomorrow'},
        },
      });
      final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
      expect(validator.validate({'date': today}).isValid, isTrue);
      expect(validator.validate({'date': '2000-01-01'}).isValid, isFalse);
    });

    test('is the clock of custom rules', () {
      LivrRule notExpired(List<Object?> args, RuleContext context) {
        final clock = context.clock;
        return (value, allValues) => value is int && value < clock().year
            ? RuleResult.error('EXPIRED')
            : RuleResult.valid;
      }

      final validator = Validator.untyped(
        {'year': 'not_expired'},
        rules: {'not_expired': notExpired},
        now: () => DateTime.utc(2030),
      );
      expect(errorsOf(validator.validate({'year': 2029})), {'year': 'EXPIRED'});
      expect(validator.validate({'year': 2030}).isValid, isTrue);
    });
  });

  group('parseReference', () {
    test('reads fields, paths and list indexes', () {
      final data = <String, Object?>{
        'a': 1,
        'b': {
          'c': [
            {'d': 2},
          ],
        },
        'x/y': 3,
        '~': 4,
        '01': 5,
      };
      expect(parseReference('a', 'r')(data), 1);
      expect(parseReference('b/c/0/d', 'r')(data), 2);
      expect(parseReference('x~1y', 'r')(data), 3);
      expect(parseReference('~0', 'r')(data), 4);
      expect(parseReference('01', 'r')(data), 5);
      expect(parseReference('b/c/00/d', 'r')(data), isNull);
      expect(parseReference('b/c/1/d', 'r')(data), isNull);
      expect(parseReference('a/b', 'r')(data), isNull);
      expect(parseReference('missing', 'r')(data), isNull);
    });

    test('throws for wrong references', () {
      for (final reference in [
        null,
        1,
        '',
        '/a',
        'a/',
        'a//b',
        '/',
        'a~2',
        'a~',
      ]) {
        expect(
          () => parseReference(reference, 'r'),
          throwsA(isA<LivrSchemaException>()),
          reason: '$reference',
        );
      }
    });
  });

  test('ip: IPv6 text forms of RFC 4291', () {
    final validator = Validator.untyped({
      'ip': {'ip': 'v6'},
    });
    bool isIPv6(String str) => validator.validate({'ip': str}).isValid;

    for (final valid in [
      '::',
      '::1',
      '1::',
      '2001:db8::1',
      '2001:0db8:0000:0000:0000:ff00:0042:8329',
      '1:2:3:4:5:6:7::',
      '::2:3:4:5:6:7:8',
      '::ffff:192.0.2.1',
      '1:2:3:4:5:6:192.0.2.1',
      'ABCD:ef01::',
    ]) {
      expect(isIPv6(valid), isTrue, reason: valid);
    }
    for (final invalid in [
      ':',
      ':::',
      '1::2::3',
      '1:2:3:4:5:6:7:8:9',
      '1:2:3:4:5:6:7',
      '1:2:3:4:5:6:7:8::',
      '12345::',
      ':1:2:3:4:5:6:7',
      '1:2:3:4:5:6:7:',
      '::192.0.2.1.5',
      '::ffff:192.0.2.01',
      '1:2:3:4:5:6:7:192.0.2.1',
      '192.0.2.1::',
      'fe80::1%eth0',
      '[::1]',
      'g::1',
    ]) {
      expect(isIPv6(invalid), isFalse, reason: invalid);
    }
  });

  test('keys are checked as they are with autoTrim', () {
    final validator = Validator.untyped({
      'map': {
        'keys': {
          'one_of': ['a'],
        },
      },
    }, autoTrim: true);
    expect(
      errorsOf(
        validator.validate({
          'map': {' a ': ' x '},
        }),
      ),
      {
        'map': {' a ': 'WRONG_KEY'},
      },
    );
  });

  test('values returns a Map<String, Object?>', () {
    final validator = Validator.untyped({
      'stock': {'values': 'positive_integer'},
    });
    final output = outputOf(
      validator.validate({
        'stock': {'a': '1', 'b': 2},
      }),
    );
    expect(output['stock'], isA<Map<String, Object?>>());
    expect(output['stock'], {'a': 1, 'b': 2});
  });

  test('the string form of numbers', () {
    final validator = Validator.untyped({'value': 'digits'});
    for (final (number, string) in [
      (1.0, '1'),
      (-0.0, '0'),
      (100, '100'),
      (1e3, '1000'),
      (123456789012345, '123456789012345'),
    ]) {
      expect(outputOf(validator.validate({'value': number})), {
        'value': string,
      });
    }
    expect(
      outputOf(
        Validator.untyped({
          'value': {'starts_with': '-'},
        }).validate({'value': -12.25}),
      ),
      {'value': '-12.25'},
    );
  });

  group('arguments', () {
    test('extra arguments are ignored, not checked', () {
      final validator = Validator.untyped({
        'split': {
          'split': [',', <String, Object?>{}],
        },
        'date': {
          'iso_date': [
            {'max': '2026-01-01'},
            'x',
          ],
        },
        'datetime': {
          'iso_datetime': [
            {'max': '2026-01-01'},
            null,
          ],
        },
        'time': {
          'iso_time': [
            {'max': '09:00'},
            <Object?>[],
          ],
        },
        'vat': {
          'required_if': [
            {'type': 'company'},
            'x',
          ],
        },
        'base64': {
          'base64': ['url', 'x'],
        },
      });
      expect(
        errorsOf(
          validator.validate({
            'split': 'a,b',
            'date': '2026-01-02',
            'datetime': '2026-01-02T00:00Z',
            'time': '10:00',
            'type': 'company',
            'base64': 'a+==',
          }),
        ),
        {
          'date': 'DATE_TOO_LATE',
          'datetime': 'DATETIME_TOO_LATE',
          'time': 'TIME_TOO_LATE',
          'vat': 'REQUIRED',
          'base64': 'WRONG_BASE64',
        },
      );
    });

    test('numbers and strings are interchangeable', () {
      final validator = Validator.untyped({
        'mac': {'mac': '64'},
        'amount': {'max_decimals': '1'},
        'split': {'split': 1},
        'prefix': {'starts_with': 1},
        'users': {'unique': 1},
        'decimal_string': {'max_decimals': '02'},
        'length': {'list_length': '2.0'},
      });
      expect(
        outputOf(
          validator.validate({
            'mac': '00:1A:2B:3C:4D:5E:6F:70',
            'amount': '1.5',
            'split': '213',
            'prefix': 12,
            'users': [
              {'1': 'a'},
              {'1': 'b'},
            ],
            'decimal_string': '1.25',
            'length': [1, 2],
          }),
        ),
        {
          'mac': '00:1A:2B:3C:4D:5E:6F:70',
          'amount': 1.5,
          'split': ['2', '3'],
          'prefix': '12',
          'users': [
            {'1': 'a'},
            {'1': 'b'},
          ],
          'decimal_string': 1.25,
          'length': [1, 2],
        },
      );

      for (final schema in <Object?>[
        {'split': true},
        {'starts_with': false},
        {'mac': '32'},
        {'max_decimals': '1.5'},
        {'max_decimals': ' 2'},
        {'max_decimals': '1e1'},
        {'mac': '0x40'},
        {'list_length': '2 '},
        {
          'list_length': [3, 'x'],
        },
        {'unique': true},
        {
          'when': [1, 'required', 'any'],
        },
      ]) {
        expect(
          () => Validator.untyped({'field': schema}),
          throwsA(isA<LivrSchemaException>()),
          reason: '$schema',
        );
      }
    });

    test('2.0 metarules ignore extra arguments and keep custom rules', () {
      LivrRule isAnswer(List<Object?> args, RuleContext context) =>
          (value, allValues) =>
              value == 42 ? RuleResult.valid : RuleResult.error('NOT_ANSWER');

      final validator = Validator.untyped(
        {
          'object': {
            'nested_object': [
              {'a': 'is_answer'},
              'x',
            ],
          },
          'objects': {
            'list_of_objects': [
              {'a': 'is_answer'},
              'x',
            ],
          },
          'variable': {
            'variable_object': [
              'type',
              {
                't': {'a': 'is_answer'},
              },
              'x',
            ],
          },
          'different': {
            'list_of_different_objects': [
              'type',
              {
                't': {'a': 'is_answer'},
              },
              'x',
            ],
          },
        },
        rules: {'is_answer': isAnswer},
      );
      expect(
        errorsOf(
          validator.validate({
            'object': {'a': 1},
            'objects': [
              {'a': 1},
            ],
            'variable': {'type': 't', 'a': 1},
            'different': [
              {'type': 't', 'a': 1},
            ],
          }),
        ),
        {
          'object': {'a': 'NOT_ANSWER'},
          'objects': [
            {'a': 'NOT_ANSWER'},
          ],
          'variable': {'a': 'NOT_ANSWER'},
          'different': [
            {'a': 'NOT_ANSWER'},
          ],
        },
      );
    });

    test('split splits numbers and booleans in their string form', () {
      final validator = Validator.untyped({
        'number': {'split': '.'},
        'boolean': {'split': ','},
      });
      expect(outputOf(validator.validate({'number': 1.5, 'boolean': true})), {
        'number': ['1', '5'],
        'boolean': ['true'],
      });
    });

    test('min is checked first with a fixed and a relative bound', () {
      final validator = Validator.untyped({
        'date': {
          'iso_date': {'min': '2026-12-01', 'max': 'today'},
        },
        'datetime': {
          'iso_datetime': {'min': '2026-12-01', 'max': 'today'},
        },
      }, now: () => DateTime.utc(2026, 10, 30));
      expect(
        errorsOf(
          validator.validate({
            'date': '2026-11-15',
            'datetime': '2026-11-15T00:00Z',
          }),
        ),
        {'date': 'DATE_TOO_EARLY', 'datetime': 'DATETIME_TOO_EARLY'},
      );
    });

    test('iso_datetime compares min and max cut to milliseconds', () {
      expect(
        Validator.untyped({
          'datetime': {
            'iso_datetime': {
              'min': '2026-10-29T10:00:00.0009Z',
              'max': '2026-10-29T10:00:00Z',
            },
          },
        }).validate({'datetime': '2026-10-29T10:00:00Z'}).isValid,
        isTrue,
      );
    });

    test('max_decimals: a number too large for a double is NOT_NUMBER', () {
      final validator = Validator.untyped({
        'amount': {'max_decimals': 0},
      });
      expect(errorsOf(validator.validate({'amount': '1${'0' * 400}.5'})), {
        'amount': 'NOT_NUMBER',
      });
    });

    test('{rule: null} is one null argument: an error for 2.5 rules', () {
      for (final rule in [
        'boolean',
        'iso_datetime',
        'iso_time',
        'unique',
        'uuid',
        'ip',
        'cidr',
        'mac',
        'base64',
        'hex',
        'any',
      ]) {
        for (final schema in <Object?>[
          {rule: null},
          {
            rule: [null],
          },
        ]) {
          expect(
            () => Validator.untyped({'field': schema}),
            throwsA(isA<LivrSchemaException>()),
            reason: '$schema',
          );
        }
      }
    });

    test('{iso_date: null} is the plain iso_date, as in 2.0', () {
      final validator = Validator.untyped({
        'date': {'iso_date': null},
      });
      expect(outputOf(validator.validate({'date': '2026-01-01'})), {
        'date': '2026-01-01',
      });
      expect(errorsOf(validator.validate({'date': '2026-02-30'})), {
        'date': 'WRONG_DATE',
      });
    });

    test('{rule: null} is one null argument for 2.0 and custom rules', () {
      // As in LIVR 2.0: {default: null} sets null, a custom rule gets [null]
      List<Object?>? gotArgs;
      LivrRule spy(List<Object?> args, RuleContext context) {
        gotArgs = args;
        return (value, allValues) => RuleResult.valid;
      }

      final validator = Validator.untyped(
        {
          'name': {'default': null},
          'field': {'spy': null},
        },
        rules: {'spy': spy},
      );
      expect(gotArgs, [null]);
      expect(outputOf(validator.validate(<String, Object?>{})), {'name': null});

      for (final schema in <Object?>[
        'default',
        {'eq': null},
      ]) {
        expect(
          () => Validator.untyped({'field': schema}),
          throwsA(isA<LivrSchemaException>()),
          reason: '$schema',
        );
      }
    });

    test('a null argument of a 2.5 rule that takes values is an error', () {
      for (final schema in <Object?>[
        {
          'not_one_of': [null],
        },
        {
          'not_one_of': ['admin', null],
        },
        {
          'required_if': {'type': null},
        },
        {'list_length': null},
        {
          'list_length': {'min': null},
        },
        {
          'list_length': {'min': 1, 'max': null},
        },
        {'split': null},
        {'max_decimals': null},
        {'starts_with': null},
        {'digest': null},
        {'values': null},
        {
          'when': ['type', null],
        },
      ]) {
        expect(
          () => Validator.untyped({'field': schema}),
          throwsA(isA<LivrSchemaException>()),
          reason: '$schema',
        );
      }
    });
  });

  group('iso_date', () {
    test('uses the proleptic Gregorian calendar in every form', () {
      for (final schema in <Object?>[
        'iso_date',
        {'iso_date': null},
        {
          'iso_date': {'min': '1000-01-01', 'max': 'today'},
        },
      ]) {
        final validator = Validator.untyped({'date': schema});
        expect(
          validator.validate({'date': '1582-10-10'}).isValid,
          isTrue,
          reason: '$schema',
        );
        expect(errorsOf(validator.validate({'date': '1500-02-29'})), {
          'date': 'WRONG_DATE',
        }, reason: '$schema');
      }
    });
  });

  group('unique', () {
    test('a key value that is an object or a list is FORMAT_ERROR', () {
      final validator = Validator.untyped({
        'one_key': {'unique': 'id'},
        'two_keys': {
          'unique': ['country', 'zip'],
        },
      });
      for (final keyValue in <Object?>[
        <String, Object?>{},
        <Object?>[],
        ['a'],
      ]) {
        expect(
          errorsOf(
            validator.validate({
              'one_key': [
                {'id': keyValue},
              ],
              'two_keys': [
                {'country': keyValue},
                {'country': 'UA', 'zip': keyValue},
                {'country': 'UA', 'zip': '01001'},
              ],
            }),
          ),
          {'one_key': 'FORMAT_ERROR', 'two_keys': 'FORMAT_ERROR'},
          reason: '$keyValue',
        );
      }
    });
  });

  group('eq and one_of with booleans', () {
    test('match the string form "true" and "false", as in 2.0', () {
      final validator = Validator.untyped({
        'eq_true': {'eq': true},
        'eq_string': {'eq': 'false'},
        'one_of': {
          'one_of': [true, 'x'],
        },
        'one_of_string': {
          'one_of': ['true', 'x'],
        },
      });
      expect(
        outputOf(
          validator.validate({
            'eq_true': 'true',
            'eq_string': false,
            'one_of': 'true',
            'one_of_string': true,
          }),
        ),
        {
          'eq_true': true,
          'eq_string': 'false',
          'one_of': true,
          'one_of_string': 'true',
        },
      );
      expect(outputOf(validator.validate({'eq_true': true, 'one_of': true})), {
        'eq_true': true,
        'one_of': true,
      });

      // Other forms did not match in 2.0 and do not now
      for (final value in ['1', 'True', 'TRUE', 't', 1]) {
        expect(
          errorsOf(validator.validate({'eq_true': value, 'one_of': value})),
          {'eq_true': 'NOT_ALLOWED_VALUE', 'one_of': 'NOT_ALLOWED_VALUE'},
          reason: '$value',
        );
      }
    });
  });
}
