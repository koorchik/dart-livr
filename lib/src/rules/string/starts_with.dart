import '../../rule.dart';
import '../../util.dart';

/// `starts_with`: the value must start with one of the arguments, non-empty
/// strings: `{starts_with: ['https://', 'http://']}`. The comparison is
/// exact and case-sensitive. The output is the value as a string.
LivrRule startsWith(List<Object?> args, RuleContext context) {
  if (args.isEmpty) {
    throw const LivrSchemaException(
      'Rule [starts_with] expects one or more non-empty strings',
    );
  }
  // A number is its string form; a boolean is not a string
  final strings = List<String>.generate(args.length, (i) {
    final arg = args[i];
    final str = arg is String || (arg is num && arg.isFinite)
        ? livrToString(arg)
        : '';
    if (str.isEmpty) {
      throw LivrSchemaException(
        'Rule [starts_with] expects non-empty strings, got [$arg]',
      );
    }
    return str;
  }, growable: false);

  return (value, allValues) {
    if (isNoValue(value)) return RuleResult.valid;
    if (!isPrimitive(value)) return RuleResult.error('FORMAT_ERROR');

    final str = livrToString(value);
    for (var i = 0; i < strings.length; i++) {
      if (str.startsWith(strings[i])) {
        return value is String ? RuleResult.valid : RuleResult.value(str);
      }
    }
    return RuleResult.error('WRONG_FORMAT');
  };
}
