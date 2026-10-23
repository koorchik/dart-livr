import '../../rule.dart';
import '../../util.dart';

/// `number_between`: the number must be from `min` to `max`, inclusive.
/// Strings with a number are accepted, and the output is the number.
LivrRule numberBetween(List<Object?> args, RuleContext context) {
  final minNumber = numberArg(args, 0, 'number_between');
  final maxNumber = numberArg(args, 1, 'number_between');

  return (value, allValues) {
    if (value is num) {
      if (!value.isFinite) return RuleResult.error('FORMAT_ERROR');
      if (value < minNumber) return RuleResult.error('TOO_LOW');
      return value > maxNumber
          ? RuleResult.error('TOO_HIGH')
          : RuleResult.valid;
    }
    if (isNoValue(value)) return RuleResult.valid;
    if (!isPrimitive(value)) return RuleResult.error('FORMAT_ERROR');

    // Booleans are not numbers
    final number = value is String ? parseNumber(value) : null;
    if (number == null) return RuleResult.error('NOT_NUMBER');
    if (number < minNumber) return RuleResult.error('TOO_LOW');
    if (number > maxNumber) return RuleResult.error('TOO_HIGH');

    return RuleResult.value(number);
  };
}
