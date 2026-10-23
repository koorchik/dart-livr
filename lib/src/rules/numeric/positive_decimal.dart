import '../../rule.dart';
import '../../util.dart';

/// `positive_decimal`: the value must be a number greater than zero.
/// Strings are accepted in the form `12` or `12.34`, and the output is
/// always a `double`.
LivrRule positiveDecimal(List<Object?> args, RuleContext context) =>
    _positiveDecimal;

RuleResult _positiveDecimal(Object? value, Map<Object?, Object?> allValues) {
  if (value is double) {
    if (!value.isFinite) return RuleResult.error('FORMAT_ERROR');
    return value > 0
        ? RuleResult.valid
        : RuleResult.error('NOT_POSITIVE_DECIMAL');
  }
  if (value is int) {
    if (value <= 0) return RuleResult.error('NOT_POSITIVE_DECIMAL');
    return RuleResult.value(value.toDouble());
  }
  if (isNoValue(value)) return RuleResult.valid;
  if (!isPrimitive(value)) return RuleResult.error('FORMAT_ERROR');

  final number = value is String ? _parseDecimal(value) : null;
  if (number == null || number <= 0) {
    return RuleResult.error('NOT_POSITIVE_DECIMAL');
  }

  return RuleResult.value(number);
}

// Parses /^-?[0-9]+(\.[0-9]+)?$/, like the decimal rule
double? _parseDecimal(String str) {
  final length = str.length;
  var i = 0;
  if (i < length && str.codeUnitAt(i) == 0x2D) i++; // "-"

  final integerStart = i;
  while (i < length && _isDigit(str.codeUnitAt(i))) {
    i++;
  }
  if (i == integerStart) return null;

  if (i < length && str.codeUnitAt(i) == 0x2E) {
    // "."
    i++;
    final fractionStart = i;
    while (i < length && _isDigit(str.codeUnitAt(i))) {
      i++;
    }
    if (i == fractionStart) return null;
  }
  if (i != length) return null;

  final number = double.parse(str);
  return number.isFinite ? number : null;
}

bool _isDigit(int char) => char >= 0x30 && char <= 0x39;
