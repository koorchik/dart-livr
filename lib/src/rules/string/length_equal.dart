import '../../rule.dart';
import '../../util.dart';

/// `length_equal`: the string must have exactly the given number of
/// characters (Unicode code points). The output is the value as a string.
LivrRule lengthEqual(List<Object?> args, RuleContext context) {
  final length = numberArg(args, 0, 'length_equal');

  return (value, allValues) {
    if (isNoValue(value)) return RuleResult.valid;
    if (!isPrimitive(value)) return RuleResult.error('FORMAT_ERROR');

    final str = livrToString(value);
    // A string has at most as many characters as UTF-16 code units
    if (str.length < length) return RuleResult.error('TOO_SHORT');

    final strLength = codePointLength(str);
    if (strLength < length) return RuleResult.error('TOO_SHORT');
    if (strLength > length) return RuleResult.error('TOO_LONG');

    return value is String ? RuleResult.valid : RuleResult.value(str);
  };
}
