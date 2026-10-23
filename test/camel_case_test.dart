// Reads the test suite from test/test_suite with dart:io
@TestOn('vm')
library;

import 'package:livr/livr.dart';
import 'package:livr/util.dart';
import 'package:test/test.dart';

import 'support/test_suite.dart';

void main() {
  test('every built-in rule has a camelCase name', () {
    for (final name in builtInRules.keys) {
      expect(Validator.defaultRules[camelize(name)], same(builtInRules[name]));
    }
  });

  test('both names work in one schema', () {
    final validator = Validator.untyped({
      'age': [
        'required',
        'positiveInteger',
        {'minNumber': 18},
      ],
      'tags': {
        'list_of': {'max_length': 3},
      },
    });

    expect(
      validator.validate({
        'age': '20',
        'tags': ['a'],
      }),
      isA<ValidationSuccess<Map<String, Object?>>>(),
    );
    expect(
      (validator.validate({
                'age': '10',
                'tags': ['abcd'],
              })
              as ValidationFailure)
          .errors,
      {
        'age': 'TOO_LOW',
        'tags': ['TOO_LONG'],
      },
    );
  });

  test('field names are not converted', () {
    final validator = Validator.untyped({'first_name': 'required'});
    expect(
      (validator.validate({'firstName': 'x'}) as ValidationFailure).errors,
      {'first_name': 'REQUIRED'},
    );
  });

  test('overriding a rule overrides its camelCase name too', () {
    final validator = Validator.untyped(
      {'a': 'minLength'},
      rules: {
        'min_length': (args, context) =>
            (value, allValues) => RuleResult.error('MY_ERROR'),
      },
    );
    expect((validator.validate({'a': 'x'}) as ValidationFailure).errors, {
      'a': 'MY_ERROR',
    });
  });

  test('a rule registered under the camelCase name wins', () {
    final validator = Validator.untyped(
      {'a': 'my_rule', 'b': 'myRule'},
      rules: {
        'myRule': (args, context) =>
            (value, allValues) => RuleResult.error('CAMEL'),
        'my_rule': (args, context) =>
            (value, allValues) => RuleResult.error('UNDERSCORE'),
      },
    );
    expect(
      (validator.validate({'a': 'x', 'b': 'x'}) as ValidationFailure).errors,
      {'a': 'UNDERSCORE', 'b': 'CAMEL'},
    );
  });

  test('a camelCase rule has no underscore name', () {
    expect(
      () => Validator.untyped(
        {'a': 'strong_password'},
        rules: {
          'strongPassword': (args, context) =>
              (value, allValues) => RuleResult.valid,
        },
      ),
      throwsA(isA<LivrSchemaException>()),
    );
  });

  test('aliases work under both names', () {
    final validator = Validator.untyped(
      {'a': 'adultAge', 'b': 'adult_age'},
      aliases: [
        const LivrAlias(
          name: 'adult_age',
          rules: [
            'positive_integer',
            {'min_number': 18},
          ],
          error: 'WRONG_AGE',
        ),
      ],
    );
    expect((validator.validate({'a': 1, 'b': 2}) as ValidationFailure).errors, {
      'a': 'WRONG_AGE',
      'b': 'WRONG_AGE',
    });
  });

  // The whole test suite once more, with every rule name in camelCase
  group('test suite with camelCase rule names', () {
    for (final suite in [
      'positive',
      'negative',
      'aliases_positive',
      'aliases_negative',
    ]) {
      for (final suiteCase in loadSuite(suite)) {
        test('$suite ${suiteCase.name}', () {
          final validator = Validator.untyped(
            _camelizeRules(suiteCase.rules) as Map<String, Object?>,
            aliases: suiteCase.aliases?.map((alias) {
              final json = alias as Map<String, Object?>;
              return LivrAlias.fromJson({
                ...json,
                'name': camelize(json['name'] as String),
                'rules': _camelizeRules(json['rules'], isFieldRules: true),
              });
            }),
          );
          final result = validator.validate(suiteCase.input);

          if (suite.endsWith('positive')) {
            expect(
              (result as ValidationSuccess<Map<String, Object?>>).output,
              suiteCase.expected,
            );
          } else {
            expect((result as ValidationFailure).errors, suiteCase.expected);
          }
        });
      }
    }
  });
}

// Schema: field names stay, field rules are converted
Object? _camelizeRules(Object? rules, {bool isFieldRules = false}) {
  if (!isFieldRules && rules is Map<String, Object?>) {
    return {
      for (final entry in rules.entries)
        entry.key: _camelizeRules(entry.value, isFieldRules: true),
    };
  }
  if (rules is String) return camelize(rules);
  if (rules is List<Object?>) {
    return [for (final rule in rules) _camelizeRules(rule, isFieldRules: true)];
  }
  if (rules is Map<String, Object?>) {
    final name = rules.keys.first;
    return {camelize(name): _camelizeArgs(name, rules[name])};
  }
  return rules;
}

// Arguments of metarules contain rules, arguments of other rules are data
Object? _camelizeArgs(String ruleName, Object? args) {
  switch (ruleName) {
    case 'nested_object' || 'list_of_objects':
      return _camelizeRules(args);
    case 'variable_object' || 'list_of_different_objects':
      final [selector, schemas as Map<String, Object?>] = args as List<Object?>;
      return [
        selector,
        {for (final e in schemas.entries) e.key: _camelizeRules(e.value)},
      ];
    case 'list_of' || 'or':
      return _camelizeRules(args, isFieldRules: true);
    default:
      return args;
  }
}
