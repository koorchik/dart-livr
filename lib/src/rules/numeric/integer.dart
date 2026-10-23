import '../../rule.dart';
import '../../util.dart';

/// `integer`: the value must be an integer. Strings with an integer (`'10'`,
/// `'1e3'`) are accepted, and the output is always an `int`.
LivrRule integer(List<Object?> args, RuleContext context) => _integer;

// 2^53: larger doubles cannot be checked for being integers exactly
const double _maxSafeInteger = 9007199254740992.0;

RuleResult _integer(Object? value, Map<Object?, Object?> allValues) {
  if (value is int) return RuleResult.valid;
  if (isNoValue(value)) return RuleResult.valid;
  if (!isPrimitive(value)) return RuleResult.error('FORMAT_ERROR');

  final number = value is String ? parseNumber(value) : value;
  if (number is int) {
    return RuleResult.value(number);
  }
  if (number is double &&
      number == number.truncateToDouble() &&
      number.abs() <= _maxSafeInteger) {
    return RuleResult.value(number.toInt());
  }

  // Booleans are not numbers
  return RuleResult.error('NOT_INTEGER');
}
