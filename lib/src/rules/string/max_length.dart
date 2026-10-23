import '../../rule.dart';
import '../../util.dart';

/// `max_length`: the string must have at most the given number of
/// characters (Unicode code points). The output is the value as a string.
LivrRule maxLength(List<Object?> args, RuleContext context) {
  final maxLength = numberArg(args, 0, 'max_length');

  return (value, allValues) {
    if (isNoValue(value)) return RuleResult.valid;
    if (!isPrimitive(value)) return RuleResult.error('FORMAT_ERROR');

    final str = livrToString(value);
    // A string has at most as many characters as UTF-16 code units: count the
    // characters only when the code units are over the limit
    if (str.length > maxLength && codePointLength(str) > maxLength) {
      return RuleResult.error('TOO_LONG');
    }

    return value is String ? RuleResult.valid : RuleResult.value(str);
  };
}
