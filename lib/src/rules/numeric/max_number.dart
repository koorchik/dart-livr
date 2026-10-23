import '../../rule.dart';
import '../../util.dart';

/// `max_number`: the number must be at most the argument. Strings with a
/// number are accepted, and the output is the number.
LivrRule maxNumber(List<Object?> args, RuleContext context) {
  final maxNumber = numberArg(args, 0, 'max_number');

  return (value, allValues) {
    if (value is num) {
      if (!value.isFinite) return RuleResult.error('FORMAT_ERROR');
      return value > maxNumber
          ? RuleResult.error('TOO_HIGH')
          : RuleResult.valid;
    }
    if (isNoValue(value)) return RuleResult.valid;
    if (!isPrimitive(value)) return RuleResult.error('FORMAT_ERROR');

    // Booleans are not numbers
    final number = value is String ? parseNumber(value) : null;
    if (number == null) return RuleResult.error('NOT_NUMBER');
    if (number > maxNumber) return RuleResult.error('TOO_HIGH');

    return RuleResult.value(number);
  };
}
