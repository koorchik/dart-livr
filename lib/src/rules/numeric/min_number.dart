import '../../rule.dart';
import '../../util.dart';

/// `min_number`: the number must be at least the argument. Strings with a
/// number are accepted, and the output is the number.
LivrRule minNumber(List<Object?> args, RuleContext context) {
  final minNumber = numberArg(args, 0, 'min_number');

  return (value, allValues) {
    if (value is num) {
      if (!value.isFinite) return RuleResult.error('FORMAT_ERROR');
      return value < minNumber ? RuleResult.error('TOO_LOW') : RuleResult.valid;
    }
    if (isNoValue(value)) return RuleResult.valid;
    if (!isPrimitive(value)) return RuleResult.error('FORMAT_ERROR');

    // Booleans are not numbers
    final number = value is String ? parseNumber(value) : null;
    if (number == null) return RuleResult.error('NOT_NUMBER');
    if (number < minNumber) return RuleResult.error('TOO_LOW');

    return RuleResult.value(number);
  };
}
