import 'package:livr/livr.dart';
import 'package:livr/util.dart';
import 'package:test/test.dart';

Object _errors(ValidationResult<Object?> result) =>
    (result as ValidationFailure).errors;
Map<String, Object?> _output(ValidationResult<Map<String, Object?>> result) =>
    (result as ValidationSuccess<Map<String, Object?>>).output;

LivrRule strongPassword(List<Object?> args, RuleContext context) {
  final minLength = numberArg(args, 0, 'strong_password');

  return (value, allValues) {
    if (isNoValue(value)) return RuleResult.valid;
    if (value is! String) return RuleResult.error('FORMAT_ERROR');
    if (value.length < minLength || !value.contains(RegExp(r'\d'))) {
      return RuleResult.error('WEAK_PASSWORD');
    }
    return RuleResult.valid;
  };
}

// A metarule of its own: every item of the list is validated with the rules
LivrRule listOfTags(List<Object?> args, RuleContext context) {
  final validateItem = context.compileField(args);

  return (value, allValues) {
    if (value is! List<Object?>) return RuleResult.error('FORMAT_ERROR');

    final output = <Object?>[];
    for (final item in value) {
      final result = validateItem(item, allValues);
      if (result.isError) return result;
      output.add(result.valueOr(item));
    }

    return RuleResult.value(output);
  };
}

void main() {
  test('rules of a validator', () {
    final validator = Validator.untyped(
      {
        'password': [
          'required',
          {'strong_password': 8},
        ],
      },
      rules: {'strong_password': strongPassword},
    );
    expect(validator.validate({'password': 'secret123'}).isValid, isTrue);
    expect(_errors(validator.validate({'password': 'secret'})), {
      'password': 'WEAK_PASSWORD',
    });
    expect(_errors(validator.validate({})), {'password': 'REQUIRED'});
  });

  test('custom rules are found in nested rules and aliases', () {
    final validator = Validator.untyped(
      {
        'users': {
          'list_of_objects': {'password': 'strongPassword'},
        },
        'admin': 'admin_password',
      },
      rules: {
        'strongPassword': (args, context) => strongPassword(const [8], context),
      },
      aliases: [
        const LivrAlias(
          name: 'admin_password',
          rules: ['required', 'strongPassword'],
          error: 'WRONG_ADMIN_PASSWORD',
        ),
      ],
    );
    expect(
      _errors(
        validator.validate({
          'users': [
            {'password': 'secret123'},
            {'password': 'secret'},
          ],
          'admin': 'x',
        }),
      ),
      {
        'users': [
          null,
          {'password': 'WEAK_PASSWORD'},
        ],
        'admin': 'WRONG_ADMIN_PASSWORD',
      },
    );
  });

  test('a custom metarule with RuleContext.compileField', () {
    final validator = Validator.untyped(
      {
        'tags': {
          'list_of_tags': ['required', 'to_lc'],
        },
      },
      rules: {'list_of_tags': listOfTags},
    );
    expect(
      _output(
        validator.validate({
          'tags': ['A', 'b'],
        }),
      ),
      {
        'tags': ['a', 'b'],
      },
    );
    expect(
      _errors(
        validator.validate({
          'tags': ['A', ''],
        }),
      ),
      {'tags': 'REQUIRED'},
    );
  });

  test('a recursive rule can use its own validator', () {
    late final Validator<Map<String, Object?>> treeValidator;
    treeValidator = Validator.untyped(
      {
        'name': ['required', 'to_uc'],
        'children': 'tree_list',
      },
      rules: {
        'tree_list': (args, context) => (value, allValues) {
          if (isNoValue(value)) return RuleResult.valid;
          if (value is! List<Object?>) {
            return RuleResult.error('FORMAT_ERROR');
          }

          final results = <Object?>[];
          for (final child in value) {
            switch (treeValidator.validate(child)) {
              case ValidationSuccess(:final output):
                results.add(output);
              case ValidationFailure(:final errors):
                return RuleResult.error(errors);
            }
          }
          return RuleResult.value(results);
        },
      },
    );

    expect(
      _output(
        treeValidator.validate({
          'name': 'root',
          'children': [
            {'name': 'a'},
            {
              'name': 'b',
              'children': [
                {'name': 'c'},
              ],
            },
          ],
        }),
      ),
      {
        'name': 'ROOT',
        'children': [
          {'name': 'A'},
          {
            'name': 'B',
            'children': [
              {'name': 'C'},
            ],
          },
        ],
      },
    );
  });

  test('rules see all values of the object', () {
    final validator = Validator.untyped(
      {'b': 'greater_than_a'},
      rules: {
        'greater_than_a': (args, context) =>
            (value, allValues) => (value as num) > (allValues['a'] as num)
            ? RuleResult.valid
            : RuleResult.error('TOO_LOW'),
      },
    );
    expect(validator.validate({'a': 1, 'b': 2}).isValid, isTrue);
    expect(_errors(validator.validate({'a': 3, 'b': 2})), {'b': 'TOO_LOW'});
  });

  test('errors of metarules are nested in errors of custom metarules', () {
    final validator = Validator.untyped(
      {
        'groups': {
          'list_of_tags': {
            'nested_object': {'name': 'required'},
          },
        },
      },
      rules: {'list_of_tags': listOfTags},
    );
    expect(
      _errors(
        validator.validate({
          'groups': [
            {'name': 'a'},
            {'name': ''},
          ],
        }),
      ),
      {
        'groups': {'name': 'REQUIRED'},
      },
    );
  });

  group('default rules', () {
    test('registerDefaultRules and registerAliasedDefaultRule', () {
      Validator.registerDefaultRules({'strong_password': strongPassword});
      Validator.registerAliasedDefaultRule(
        const LivrAlias(
          name: 'adult_age',
          rules: [
            'positive_integer',
            {'min_number': 18},
          ],
        ),
      );

      final validator = Validator.untyped({
        'password': {'strongPassword': 8},
        'age': 'adultAge',
      });
      expect(_errors(validator.validate({'password': 'x', 'age': 10})), {
        'password': 'WEAK_PASSWORD',
        'age': 'TOO_LOW',
      });
      expect(Validator.defaultRules, contains('strong_password'));
    });

    test('rules of a validator take precedence', () {
      Validator.registerDefaultRules({
        'my_rule': (args, context) =>
            (value, allValues) => RuleResult.error('DEFAULT'),
      });
      final validator = Validator.untyped(
        {'a': 'my_rule'},
        rules: {
          'my_rule': (args, context) =>
              (value, allValues) => RuleResult.error('OWN'),
        },
      );
      expect(_errors(validator.validate({'a': 1})), {'a': 'OWN'});
    });

    test('a default rule can override a built-in one', () {
      Validator.registerDefaultRules({
        'email': (args, context) =>
            (value, allValues) => RuleResult.valid,
      });
      expect(
        Validator.untyped({'a': 'email'}).validate({'a': 'not email'}).isValid,
        isTrue,
      );
    });
  });
}
