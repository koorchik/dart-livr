import 'dart:convert';

import 'package:livr/livr.dart';
import 'package:test/test.dart';

Map<String, Object?> _output(
  Validator<Map<String, Object?>> validator,
  Object? input,
) =>
    (validator.validate(input) as ValidationSuccess<Map<String, Object?>>)
        .output;

void main() {
  final small =
      Validator.untyped({'a': 'string', 'b': 'string', 'c': 'string'});
  // More fields than a scan is used for: looked up through an index
  final large =
      Validator.untyped({for (var i = 0; i < 20; i++) 'f$i': 'string'});

  for (final (name, validator, keys) in [
    ('small schema', small, ['a', 'b', 'c']),
    ('large schema', large, [for (var i = 0; i < 20; i++) 'f$i']),
  ]) {
    group(name, () {
      final first = keys.first;
      final last = keys.last;

      test('has only the fields of the input, in schema order', () {
        final output = _output(validator, {last: 2, first: 1, 'x': 3});
        expect(output.keys, [first, last]);
        expect(output.values, ['1', '2']);
        expect(output.length, 2);
        expect(output.containsKey(first), isTrue);
        expect(output.containsKey(keys[1]), isFalse);
        expect(output[keys[1]], isNull);
        expect(output['x'], isNull);
        expect(output, {first: '1', last: '2'});
      });

      test('can be changed like any map', () {
        final output = _output(validator, {first: 1});

        output[keys[1]] = 'new';
        output['other'] = 'other value';
        expect(output, {first: '1', keys[1]: 'new', 'other': 'other value'});
        expect(output.keys, [first, keys[1], 'other']);
        expect(output.length, 3);

        expect(output.remove(first), '1');
        expect(output.remove(first), isNull);
        expect(output.remove('other'), 'other value');
        expect(output.remove('missing'), isNull);
        expect(output, {keys[1]: 'new'});

        output.putIfAbsent(first, () => 'again');
        output.update(keys[1], (value) => '$value!');
        expect(output, {first: 'again', keys[1]: 'new!'});

        output.clear();
        expect(output, isEmpty);
        output[last] = 'after clear';
        expect(output, {last: 'after clear'});
      });

      test('outputs do not share values', () {
        final output1 = _output(validator, {first: 1});
        final output2 = _output(validator, {first: 2});
        output1[first] = 'changed';
        expect(output2[first], '2');
      });

      test('null values are values', () {
        final output = _output(validator, {first: null});
        expect(output.containsKey(first), isTrue);
        expect(output, {first: null});
      });
    });
  }

  test('works with jsonEncode, Map.of and the equality of maps', () {
    final validator = Validator.untyped({
      'user': {
        'nested_object': {
          'name': 'required',
          'tags': {'list_of': 'string'}
        }
      },
    });
    final output = _output(validator, {
      'user': {
        'name': 'John',
        'tags': [1, 2]
      },
    });

    expect(jsonEncode(output), '{"user":{"name":"John","tags":["1","2"]}}');
    expect(Map.of(output), {
      'user': {
        'name': 'John',
        'tags': ['1', '2']
      },
    });
    expect(output.toString(), '{user: {name: John, tags: [1, 2]}}');
    expect(output.entries.single.key, 'user');
  });
}
