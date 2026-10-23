import '../../rule.dart';
import '../../util.dart';

/// `min_length`: the string must have at least the given number of
/// characters (Unicode code points). The output is the value as a string.
LivrRule minLength(List<Object?> args, RuleContext context) {
  final minLength = numberArg(args, 0, 'min_length');

  return (value, allValues) {
    if (isNoValue(value)) return RuleResult.valid;
    if (!isPrimitive(value)) return RuleResult.error('FORMAT_ERROR');

    final str = livrToString(value);
    // A string has at most as many characters as UTF-16 code units, and at
    // least half as many: count the characters only when it matters
    final length = str.length;
    if (length < minLength) return RuleResult.error('TOO_SHORT');
    if (length < minLength * 2 && codePointLength(str) < minLength) {
      return RuleResult.error('TOO_SHORT');
    }

    return value is String ? RuleResult.valid : RuleResult.value(str);
  };
}
