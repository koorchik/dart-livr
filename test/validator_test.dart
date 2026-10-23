import 'dart:convert';

import 'package:livr/livr.dart';
import 'package:test/test.dart';

Object _errors(ValidationResult<Object?> result) =>
    (result as ValidationFailure).errors;
Map<String, Object?> _output(ValidationResult<Map<String, Object?>> result) =>
    (result as ValidationSuccess<Map<String, Object?>>).output;

void main() {
  group('validate()', () {
    test('data that is not a map is a FORMAT_ERROR', () {
      final validator = Validator.untyped({'a': 'required'});
      for (final data in [null, 'a', 1, <Object?>[]]) {
        expect(_errors(validator.validate(data)), 'FORMAT_ERROR');
      }
    });

    test('maps of any type are accepted', () {
      final validator = Validator.untyped({
        'a': 'required',
        'b': {
          'nested_object': {'c': 'positive_integer'}
        },
      });
      final Map<dynamic, dynamic> data = <dynamic, dynamic>{
        'a': 1,
        'b': <dynamic, dynamic>{'c': '2'},
        3: 'not a field',
      };
      expect(_output(validator.validate(data)), {
        'a': 1,
        'b': {'c': 2},
      });
    });

    test('works with jsonDecode() output', () {
      final validator = Validator.untyped(
        jsonDecode('{"tags": {"list_of": "trim"}}') as Map<String, Object?>,
      );
      expect(
        _output(validator.validate(jsonDecode('{"tags": [" a ", "b"]}'))),
        {
          'tags': ['a', 'b']
        },
      );
    });

    test('missing fields stay missing, null fields stay null', () {
      final validator =
          Validator.untyped({'a': 'string', 'b': 'string', 'c': 'trim'});
      expect(_output(validator.validate({'a': null})), {'a': null});
    });

    test('validateOrThrow', () {
      final validator = Validator.untyped({'a': 'required'});
      expect(validator.validateOrThrow({'a': 1}), {'a': 1});
      expect(
        () => validator.validateOrThrow({}),
        throwsA(isA<LivrValidationException>()
            .having((e) => e.errors, 'errors', {'a': 'REQUIRED'})),
      );
    });

    test('a validator is reusable', () {
      final validator = Validator.untyped({
        'a': ['required', 'to_uc']
      });
      expect(_output(validator.validate({'a': 'x'})), {'a': 'X'});
      expect(_errors(validator.validate({})), {'a': 'REQUIRED'});
      expect(_output(validator.validate({'a': 'y'})), {'a': 'Y'});
    });
  });

  group('output types', () {
    final validator = Validator.untyped({
      'integer': 'integer',
      'positive_integer': 'positive_integer',
      'decimal': 'decimal',
      'positive_decimal': 'positive_decimal',
      'min_number': {'min_number': 0},
      'string': 'string',
    });

    test('integer rules return int', () {
      final output = _output(validator.validate({
        'integer': '-10',
        'positive_integer': 10.0,
      }));
      expect(output['integer'], isA<int>());
      expect(output['positive_integer'], isA<int>());
      expect(_output(validator.validate({'integer': '1e3'}))['integer'], 1000);
    });

    test('decimal rules return double', () {
      final output = _output(validator.validate({
        'decimal': '10',
        'positive_decimal': 3,
      }));
      expect(output['decimal'], isA<double>());
      expect(output['positive_decimal'], isA<double>());
    });

    test('number rules return the number as parsed', () {
      expect(_output(validator.validate({'min_number': '10'}))['min_number'],
          isA<int>());
      expect(_output(validator.validate({'min_number': '1.5'}))['min_number'],
          1.5);
    });

    test('numbers are converted to strings like in JavaScript', () {
      expect(_output(validator.validate({'string': 10.0}))['string'], '10');
    });

    test('booleans are not numbers', () {
      expect(
        _errors(validator.validate({
          'integer': true,
          'positive_integer': true,
          'decimal': false,
          'positive_decimal': true,
          'min_number': true,
        })),
        {
          'integer': 'NOT_INTEGER',
          'positive_integer': 'NOT_POSITIVE_INTEGER',
          'decimal': 'NOT_DECIMAL',
          'positive_decimal': 'NOT_POSITIVE_DECIMAL',
          'min_number': 'NOT_NUMBER',
        },
      );
    });

    test('non-finite numbers are a FORMAT_ERROR', () {
      expect(
        _errors(validator.validate({
          'integer': double.nan,
          'decimal': double.infinity,
        })),
        {'integer': 'FORMAT_ERROR', 'decimal': 'FORMAT_ERROR'},
      );
    });
  });

  group('strings', () {
    test('lengths are counted in characters', () {
      final validator = Validator.untyped({
        'max': {'max_length': 3},
        'min': {'min_length': 3},
        'equal': {'length_equal': 3},
        'between': {
          'length_between': [2, 3]
        },
      });
      expect(
        validator.validate({
          'max': '😀😀😀',
          'min': '😀😀😀',
          'equal': '😀😀😀',
          'between': '😀😀',
        }).isValid,
        isTrue,
      );
      expect(
        _errors(validator.validate({
          'max': '😀😀😀😀',
          'min': '😀😀',
          'equal': '😀😀',
          'between': '😀',
        })),
        {
          'max': 'TOO_LONG',
          'min': 'TOO_SHORT',
          'equal': 'TOO_SHORT',
          'between': 'TOO_SHORT',
        },
      );
    });

    test('remove and leave_only handle characters outside of ASCII', () {
      final validator = Validator.untyped({
        'remove': {'remove': 'ё😀'},
        'leave_only': {'leave_only': 'ё😀'},
      });
      expect(
        _output(validator.validate({
          'remove': 'ёлка😀!',
          'leave_only': 'ёлка😀!',
        })),
        {'remove': 'лка!', 'leave_only': 'ё😀'},
      );
    });

    test('one_of with a long list works like with a short one', () {
      final allowedValues = [for (var i = 0; i < 40; i++) i, '1'];
      final validator = Validator.untyped({
        'value': {
          'one_of': [allowedValues]
        },
      });
      expect(_output(validator.validate({'value': '39'})), {'value': 39});
      expect(_output(validator.validate({'value': 1})), {'value': 1});
      expect(_errors(validator.validate({'value': 40})),
          {'value': 'NOT_ALLOWED_VALUE'});
      expect(_errors(validator.validate({'value': <String, Object?>{}})),
          {'value': 'FORMAT_ERROR'});
    });
  });

  group('immutability', () {
    test('defaults are copied for every output', () {
      final validator = Validator.untyped({
        'list': {
          'default': [<Object?>[]]
        },
      });
      final first = _output(validator.validate({}))['list'] as List<Object?>;
      first.add(1);
      expect(_output(validator.validate({}))['list'], isEmpty);
    });

    test('the input is never changed, outputs are new objects', () {
      final input = {
        'name': ' Name ',
        'tags': ['a', 'b'],
        'address': {'city': 'Kyiv'},
      };
      final validator = Validator.untyped(
        {
          'name': 'to_uc',
          'tags': {'list_of': 'string'},
          'address': {
            'nested_object': {'city': 'required'}
          },
        },
        autoTrim: true,
      );
      final output = _output(validator.validate(input));

      expect(output, {
        'name': 'NAME',
        'tags': ['a', 'b'],
        'address': {'city': 'Kyiv'},
      });
      expect(output['tags'], isNot(same(input['tags'])));
      expect(output['address'], isNot(same(input['address'])));
      expect(input['name'], ' Name ');
    });
  });

  group('autoTrim', () {
    final schema = {
      'code': 'required',
      'password': [
        'required',
        {'min_length': 3}
      ],
      'password2': {'equal_to_field': 'password'},
      'list': {
        'list_of': ['string']
      },
      'address': {
        'nested_object': {
          'street': {'min_length': 5}
        }
      },
    };

    test('trims strings before validation', () {
      final validator = Validator.untyped(schema, autoTrim: true);
      expect(
        _errors(validator.validate({
          'code': '  ',
          'password': ' 12  ',
          'address': {'street': '  hell '},
        })),
        {
          'code': 'REQUIRED',
          'password': 'TOO_SHORT',
          'address': {'street': 'TOO_SHORT'},
        },
      );
      expect(
        _output(validator.validate({
          'code': ' A ',
          'password': ' 123  ',
          'password2': '123 ',
          'list': [' aaa ', ' bbb '],
          'address': {'street': '  hello '},
        })),
        {
          'code': 'A',
          'password': '123',
          'password2': '123',
          'list': ['aaa', 'bbb'],
          'address': {'street': 'hello'},
        },
      );
    });

    test('defaultAutoTrim applies to validators created afterwards', () {
      addTearDown(() => Validator.defaultAutoTrim = false);
      Validator.defaultAutoTrim = true;
      expect(_output(Validator.untyped({'a': 'string'}).validate({'a': ' x '})),
          {'a': 'x'});
      expect(
        _output(Validator.untyped({'a': 'string'}, autoTrim: false)
            .validate({'a': ' x '})),
        {'a': ' x '},
      );
    });
  });

  group('schema errors', () {
    void expectSchemaError(Map<String, Object?> schema, Matcher message) {
      expect(
        () => Validator.untyped(schema),
        throwsA(isA<LivrSchemaException>()
            .having((e) => e.message, 'message', message)),
      );
    }

    test('are thrown by the constructor', () {
      expectSchemaError(
          {'a': 'unknown'}, contains('Rule [unknown] not registered'));
      expectSchemaError({
        'a': {
          'nested_object': {'b': 'unknown'}
        }
      }, contains('[unknown]'));
      expectSchemaError(
          {'a': <String, Object?>{}}, contains('must have a name'));
      expectSchemaError({'a': 1}, contains('must be a name'));
      expectSchemaError({
        'a': {'like': '('}
      }, contains('invalid regular expression'));
      expectSchemaError({
        'a': {'min_length': 'abc'}
      }, contains('expects a number'));
      expectSchemaError({
        'a': {
          'length_between': [1]
        }
      }, contains('at least 2'));
      expectSchemaError({
        'a': {'nested_object': 'x'}
      }, contains('expects a schema'));
      expectSchemaError({
        'a': {
          'eq': <Object?>[<Object?>[]]
        }
      }, contains('primitive'));
    });

    test('aliases need a name', () {
      expect(() => LivrAlias.fromJson({'rules': 'required'}),
          throwsA(isA<LivrSchemaException>()));
      expect(
          () => Validator.untyped({},
              aliases: [const LivrAlias(name: '', rules: 'required')]),
          throwsA(isA<LivrSchemaException>()));
    });
  });
}
