import 'dart:collection';

import 'rule.dart';

/// Whether the value is empty for LIVR: missing (`null`) or an empty string.
/// All rules except `required`, `not_empty` and `not_empty_list` skip empty
/// values.
bool isNoValue(Object? value) =>
    value == null || (value is String && value.isEmpty);

/// Whether the value is a primitive value: a string, a boolean or a finite
/// number.
bool isPrimitive(Object? value) =>
    value is String || value is bool || (value is num && value.isFinite);

/// Converts a primitive value to a string like JavaScript does, so values
/// are compared the same way in all implementations: `10.0` becomes `'10'`
/// (not `'10.0'`), `-0.0` becomes `'0'`.
String livrToString(Object? value) {
  if (value is String) return value;
  if (value is double) return _doubleToString(value);
  return value.toString();
}

// 2^53: integral doubles below it are converted to int exactly
const double _maxSafeDouble = 9007199254740992.0;

String _doubleToString(double value) {
  if (value == value.truncateToDouble() && value.abs() < _maxSafeDouble) {
    return value.toInt().toString();
  }

  final str = value.toString();
  return str.endsWith('.0') ? str.substring(0, str.length - 2) : str;
}

/// Parses a decimal number: an optional sign, digits with an optional
/// fraction (`12`, `-1.5`, `.5`, `5.`) and an optional exponent (`1e3`).
/// Leading and trailing ASCII whitespace is allowed. Returns an `int` for
/// integers that fit, a `double` otherwise, and `null` if the string is not
/// a number. Hexadecimal numbers, `Infinity` and `NaN` are not numbers.
num? parseNumber(String str) {
  final length = str.length;
  var start = 0;
  while (start < length && _isSpace(str.codeUnitAt(start))) {
    start++;
  }
  var end = length;
  while (end > start && _isSpace(str.codeUnitAt(end - 1))) {
    end--;
  }
  if (start == end) return null;

  var i = start;
  var isNegative = false;
  final char = str.codeUnitAt(i);
  if (char == 0x2D || char == 0x2B) {
    // "-" or "+"
    isNegative = char == 0x2D;
    i++;
  }

  // Digits are accumulated while the value is exact: the fast path for the
  // common case of a short integer, without substring() and tryParse()
  var intValue = 0;
  var digits = 0;
  while (i < end) {
    final digit = str.codeUnitAt(i) - 0x30;
    if (digit < 0 || digit > 9) break;
    if (digits < 15) intValue = intValue * 10 + digit;
    digits++;
    i++;
  }

  var isInteger = true;
  var fractionDigits = 0;
  if (i < end && str.codeUnitAt(i) == 0x2E) {
    // "."
    isInteger = false;
    i++;
    while (i < end && _isDigit(str.codeUnitAt(i))) {
      fractionDigits++;
      i++;
    }
  }
  if (digits == 0 && fractionDigits == 0) return null;

  if (i < end && (str.codeUnitAt(i) | 0x20) == 0x65) {
    // "e" or "E"
    isInteger = false;
    i++;
    if (i < end && (str.codeUnitAt(i) == 0x2D || str.codeUnitAt(i) == 0x2B)) {
      i++;
    }
    var exponentDigits = 0;
    while (i < end && _isDigit(str.codeUnitAt(i))) {
      exponentDigits++;
      i++;
    }
    if (exponentDigits == 0) return null;
  }
  if (i != end) return null;

  if (isInteger && digits <= 15) return isNegative ? -intValue : intValue;

  final numberStr = start == 0 && end == length
      ? str
      : str.substring(start, end);
  if (isInteger) {
    final parsed = int.tryParse(numberStr);
    if (parsed != null) return parsed;
  }

  final parsed = double.tryParse(numberStr);
  return parsed != null && parsed.isFinite ? parsed : null;
}

bool _isDigit(int char) => char >= 0x30 && char <= 0x39;

// Space, \t, \n, \v, \f, \r
bool _isSpace(int char) => char == 0x20 || (char >= 0x09 && char <= 0x0D);

/// The number of characters (Unicode code points) of the string. Unlike
/// `String.length`, a character outside of the Basic Multilingual Plane, like
/// most emoji, counts once.
int codePointLength(String str) {
  final length = str.length;
  var count = length;
  for (var i = 0; i < length - 1; i++) {
    final char = str.codeUnitAt(i);
    if (char >= 0xD800 &&
        char <= 0xDBFF &&
        (str.codeUnitAt(i + 1) & 0xFC00) == 0xDC00) {
      count--;
      i++;
    }
  }
  return count;
}

/// Trims all strings in the value, in nested maps and lists too. Returns the
/// value itself when there is nothing to trim, and a trimmed copy otherwise:
/// the value is never changed.
Object? trimDeep(Object? value) {
  if (value is String) return value.trim();

  if (value is Map<Object?, Object?>) {
    Map<Object?, Object?>? copy;
    value.forEach((key, item) {
      final trimmed = trimDeep(item);
      if (!identical(trimmed, item)) (copy ??= Map.of(value))[key] = trimmed;
    });
    return copy ?? value;
  }

  if (value is List<Object?>) {
    List<Object?>? copy;
    for (var i = 0; i < value.length; i++) {
      final item = value[i];
      final trimmed = trimDeep(item);
      if (!identical(trimmed, item)) (copy ??= List.of(value))[i] = trimmed;
    }
    return copy ?? value;
  }

  return value;
}

/// A deep copy of maps and lists, other values as they are.
Object? deepCopy(Object? value) {
  if (value is Map<String, Object?>) {
    return <String, Object?>{
      for (final entry in value.entries) entry.key: deepCopy(entry.value),
    };
  }
  if (value is Map<Object?, Object?>) {
    return <Object?, Object?>{
      for (final entry in value.entries) entry.key: deepCopy(entry.value),
    };
  }
  if (value is List<Object?>) return [for (final item in value) deepCopy(item)];
  return value;
}

final RegExp _underscoreRe = RegExp(r'_(\w|$)');

/// The camelCase form of an underscore rule name: `min_length` becomes
/// `minLength`.
String camelize(String name) =>
    name.replaceAllMapped(_underscoreRe, (m) => m[1]!.toUpperCase());

/// The argument of a rule at [index], for rule builders. Throws
/// [LivrSchemaException] when the schema does not have it.
Object? ruleArg(List<Object?> args, int index, String ruleName) {
  if (index >= args.length) {
    throw LivrSchemaException(
      'Rule [$ruleName] expects at least ${index + 1} argument(s), '
      'got ${args.length}',
    );
  }
  return args[index];
}

/// A number argument of a rule at [index]: a number or a string with a
/// number. Throws [LivrSchemaException] otherwise.
num numberArg(List<Object?> args, int index, String ruleName) {
  final arg = ruleArg(args, index, ruleName);
  if (arg is num) return arg;
  if (arg is String) {
    final parsed = parseNumber(arg);
    if (parsed != null) return parsed;
  }
  throw LivrSchemaException('Rule [$ruleName] expects a number, got [$arg]');
}

/// A string argument of a rule at [index]. Numbers and booleans are
/// converted with [livrToString]. Throws [LivrSchemaException] for other
/// values.
String stringArg(List<Object?> args, int index, String ruleName) {
  final arg = ruleArg(args, index, ruleName);
  if (isPrimitive(arg)) return livrToString(arg);
  throw LivrSchemaException('Rule [$ruleName] expects a string, got [$arg]');
}

/// An unmodifiable map with one entry: the data of a value validated on its
/// own (list items, `or` and aliases), cheaper than a map literal.
final class SingleFieldMap extends UnmodifiableMapBase<Object?, Object?> {
  SingleFieldMap(this._key, this._value);

  final String _key;
  final Object? _value;

  @override
  Object? operator [](Object? key) => key == _key ? _value : null;

  @override
  bool containsKey(Object? key) => key == _key;

  @override
  Iterable<Object?> get keys => [_key];

  @override
  int get length => 1;

  @override
  bool get isEmpty => false;

  @override
  bool get isNotEmpty => true;
}
