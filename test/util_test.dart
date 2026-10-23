import 'package:livr/util.dart';
import 'package:test/test.dart';

void main() {
  test('livrToString formats numbers like JavaScript', () {
    expect(livrToString(10), '10');
    expect(livrToString(10.0), '10');
    expect(livrToString(-0.0), '0');
    expect(livrToString(1.5), '1.5');
    expect(livrToString(1e20), '100000000000000000000');
    expect(livrToString(1e21), '1e+21');
    expect(livrToString(1e-7), '1e-7');
    expect(livrToString(true), 'true');
    expect(livrToString('abc'), 'abc');
  });

  test('parseNumber accepts decimal numbers only', () {
    expect(parseNumber('25'), same(25));
    expect(parseNumber('-25'), -25);
    expect(parseNumber('+25'), 25);
    expect(parseNumber(' 25 '), 25);
    expect(parseNumber('1.5'), 1.5);
    expect(parseNumber('.5'), 0.5);
    expect(parseNumber('5.'), 5.0);
    expect(parseNumber('1e3'), 1000.0);
    expect(parseNumber('1E-3'), 0.001);
    expect(parseNumber('9007199254740993'), int.parse('9007199254740993'));
    expect(parseNumber('123456789012345678901234'), 1.2345678901234568e23);

    for (final notNumber in [
      '',
      ' ',
      'abc',
      '1,5',
      '12.12.12',
      '0x10',
      'Infinity',
      'NaN',
      '1e',
      '.',
      '-',
      '1e400',
      '1 2',
    ]) {
      expect(parseNumber(notNumber), isNull, reason: notNumber);
    }
  });

  test('parseNumber returns an int for integers', () {
    expect(parseNumber('10'), isA<int>());
    expect(parseNumber('123456789012345678'), isA<int>());
    expect(parseNumber('10.0'), isA<double>());
  });

  test('codePointLength counts characters, not UTF-16 code units', () {
    expect(codePointLength(''), 0);
    expect(codePointLength('Васек'), 5);
    expect(codePointLength('😀a😀'), 3);
    // A lone surrogate is one character
    expect(codePointLength('\uD83D'), 1);
  });

  test('trimDeep returns the same value when there is nothing to trim', () {
    final data = {
      'a': 'x',
      'b': [
        1,
        'y',
        {'c': 'z'},
      ],
    };
    expect(trimDeep(data), same(data));
  });

  test('trimDeep copies only what it trims', () {
    final nested = {'c': 'z'};
    final data = {
      'a': ' x ',
      'b': [' y', nested],
    };
    final trimmed = trimDeep(data) as Map<Object?, Object?>;

    expect(trimmed, {
      'a': 'x',
      'b': [
        'y',
        {'c': 'z'},
      ],
    });
    expect((trimmed['b'] as List<Object?>)[1], same(nested));
    expect(data['a'], ' x ', reason: 'the input is not changed');
  });

  test('camelize', () {
    expect(camelize('min_length'), 'minLength');
    expect(camelize('list_of_different_objects'), 'listOfDifferentObjects');
    expect(camelize('required'), 'required');
  });
}
