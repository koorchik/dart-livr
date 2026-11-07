import '../../rule.dart';
import '../../util.dart';

/// `max_decimals`: the number must have at most the given number of digits
/// after the decimal point: `{max_decimals: 2}`. Trailing zeros do not
/// count, so `'1.230'` and `1.230` have 2. Strings are accepted in the form
/// `-12` or `-12.34`, and the output is the number.
LivrRule maxDecimals(List<Object?> args, RuleContext context) {
  // Arguments after the first one are ignored. A string in the grammar of
  // decimal is the number: '2', '2.0', '02', not ' 2' or '1e1'
  final arg = args.isEmpty ? null : args[0];
  final number = arg is num
      ? arg
      : (arg is String && arg.isNotEmpty && _countDecimals(arg) >= 0
            ? parseNumber(arg)
            : null);
  if (number == null || number < 0 || number != number.truncateToDouble()) {
    throw LivrSchemaException(
      'Rule [max_decimals] expects a non-negative integer, got [$arg]',
    );
  }
  final maxDecimals = number.toInt();

  return (value, allValues) {
    if (value is String) {
      if (value.isEmpty) return RuleResult.valid;

      final decimals = _countDecimals(value);
      if (decimals < 0) return RuleResult.error('NOT_NUMBER');

      // Too large for a finite double: not a number, as JSON has no
      // infinity. Checked before the decimals: a bound code means a number
      final number = parseNumber(value);
      if (number == null) return RuleResult.error('NOT_NUMBER');
      if (decimals > maxDecimals) return RuleResult.error('TOO_MANY_DECIMALS');
      return RuleResult.value(number);
    }
    if (value is int) return RuleResult.valid;
    if (value is double) {
      if (!value.isFinite) return RuleResult.error('FORMAT_ERROR');
      return _countNumberDecimals(value) > maxDecimals
          ? RuleResult.error('TOO_MANY_DECIMALS')
          : RuleResult.valid;
    }
    if (value == null) return RuleResult.valid;
    return RuleResult.error(value is bool ? 'NOT_NUMBER' : 'FORMAT_ERROR');
  };
}

// The digits after the decimal point of /^-?[0-9]+(\.[0-9]+)?$/ without the
// trailing zeros: '1.230' has 2, '5.000' has 0. -1 for other strings.
// Counted as written, so '0.10000000000000000001' has 20, although it is
// not exact as a double
int _countDecimals(String str) {
  final length = str.length;
  var i = str.codeUnitAt(0) == 0x2D ? 1 : 0; // "-"

  final integerStart = i;
  while (i < length && _isDigit(str.codeUnitAt(i))) {
    i++;
  }
  if (i == integerStart) return -1;
  if (i == length) return 0;
  if (str.codeUnitAt(i) != 0x2E || i + 1 == length) return -1; // "."

  final fractionStart = i + 1;
  var significantEnd = fractionStart;
  for (i = fractionStart; i < length; i++) {
    final char = str.codeUnitAt(i);
    if (!_isDigit(char)) return -1;
    if (char != 0x30) significantEnd = i + 1;
  }
  return significantEnd - fractionStart;
}

// The decimals of the string form of a double: '0.125', or the exponent form
// of small numbers, '1e-7' and '1.5e-7'. The shortest form has no trailing
// zeros, except '.0' of an integral double
int _countNumberDecimals(double value) {
  if (value == value.truncateToDouble()) return 0;

  final str = value.toString();
  final dot = str.indexOf('.');
  final exponent = str.indexOf('e');
  final fractionEnd = exponent == -1 ? str.length : exponent;
  final fractionLength = dot == -1 ? 0 : fractionEnd - dot - 1;
  if (exponent == -1) return fractionLength;

  // "e-7"; "e+21" is integral
  final power = int.parse(str.substring(exponent + 1));
  final decimals = fractionLength - power;
  return decimals > 0 ? decimals : 0;
}

bool _isDigit(int char) => char >= 0x30 && char <= 0x39;
