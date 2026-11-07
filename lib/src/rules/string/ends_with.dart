import '../../rule.dart';
import '../../util.dart';

/// `ends_with`: the value must end with one of the arguments, non-empty
/// strings: `{ends_with: '.pdf'}`. The comparison is exact and
/// case-sensitive. The output is the value as a string.
LivrRule endsWith(List<Object?> args, RuleContext context) {
  if (args.isEmpty) {
    throw const LivrSchemaException(
      'Rule [ends_with] expects one or more non-empty strings',
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
        'Rule [ends_with] expects non-empty strings, got [$arg]',
      );
    }
    return str;
  }, growable: false);

  return (value, allValues) {
    if (isNoValue(value)) return RuleResult.valid;
    if (!isPrimitive(value)) return RuleResult.error('FORMAT_ERROR');

    final str = livrToString(value);
    for (var i = 0; i < strings.length; i++) {
      if (str.endsWith(strings[i])) {
        return value is String ? RuleResult.valid : RuleResult.value(str);
      }
    }
    return RuleResult.error('WRONG_FORMAT');
  };
}
