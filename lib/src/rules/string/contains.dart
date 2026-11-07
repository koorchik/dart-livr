import '../../rule.dart';
import '../../util.dart';

/// `contains`: the value must contain one of the arguments, non-empty
/// strings: `{contains: '@'}`. The comparison is exact and
/// case-sensitive. The output is the value as a string.
LivrRule contains(List<Object?> args, RuleContext context) {
  if (args.isEmpty) {
    throw const LivrSchemaException(
      'Rule [contains] expects one or more non-empty strings',
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
        'Rule [contains] expects non-empty strings, got [$arg]',
      );
    }
    return str;
  }, growable: false);

  return (value, allValues) {
    if (isNoValue(value)) return RuleResult.valid;
    if (!isPrimitive(value)) return RuleResult.error('FORMAT_ERROR');

    final str = livrToString(value);
    for (var i = 0; i < strings.length; i++) {
      if (str.contains(strings[i])) {
        return value is String ? RuleResult.valid : RuleResult.value(str);
      }
    }
    return RuleResult.error('WRONG_FORMAT');
  };
}
