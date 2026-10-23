import '../../rule.dart';
import '../../util.dart';

/// `length_between`: the string must have from `min` to `max` characters
/// (Unicode code points), inclusive. The output is the value as a string.
LivrRule lengthBetween(List<Object?> args, RuleContext context) {
  final minLength = numberArg(args, 0, 'length_between');
  final maxLength = numberArg(args, 1, 'length_between');

  return (value, allValues) {
    if (isNoValue(value)) return RuleResult.valid;
    if (!isPrimitive(value)) return RuleResult.error('FORMAT_ERROR');

    final str = livrToString(value);
    // A string has at most as many characters as UTF-16 code units, and at
    // least half as many: count the characters only when it matters
    final length = str.length;
    if (length < minLength) return RuleResult.error('TOO_SHORT');
    if (length > maxLength || length < minLength * 2) {
      final strLength = codePointLength(str);
      if (strLength < minLength) return RuleResult.error('TOO_SHORT');
      if (strLength > maxLength) return RuleResult.error('TOO_LONG');
    }

    return value is String ? RuleResult.valid : RuleResult.value(str);
  };
}
