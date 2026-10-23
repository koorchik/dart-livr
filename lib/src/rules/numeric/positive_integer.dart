import '../../rule.dart';
import '../../util.dart';

/// `positive_integer`: the value must be an integer greater than zero.
/// Strings with an integer are accepted, and the output is always an `int`.
LivrRule positiveInteger(List<Object?> args, RuleContext context) =>
    _positiveInteger;

// 2^53: larger doubles cannot be checked for being integers exactly
const double _maxSafeInteger = 9007199254740992.0;

RuleResult _positiveInteger(Object? value, Map<Object?, Object?> allValues) {
  if (value is int) {
    return value < 1
        ? RuleResult.error('NOT_POSITIVE_INTEGER')
        : RuleResult.valid;
  }
  if (isNoValue(value)) return RuleResult.valid;
  if (!isPrimitive(value)) return RuleResult.error('FORMAT_ERROR');

  final number = value is String ? parseNumber(value) : value;
  if (number is int) {
    if (number < 1) return RuleResult.error('NOT_POSITIVE_INTEGER');
    return RuleResult.value(number);
  }
  if (number is double &&
      number >= 1 &&
      number == number.truncateToDouble() &&
      number <= _maxSafeInteger) {
    return RuleResult.value(number.toInt());
  }

  // Booleans are not numbers
  return RuleResult.error('NOT_POSITIVE_INTEGER');
}
