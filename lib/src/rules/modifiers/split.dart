import '../../rule.dart';
import '../../util.dart';

/// `split`: Splits a string at every separator into a list of strings:
/// `{split: ','}` turns `'1,2,3'` into `['1', '2', '3']`, empty parts are
/// kept. A number or a boolean is split in its string form (`5` becomes
/// `['5']`), a list stays as it is, empty values and objects are left to the
/// next rules.
LivrRule split(List<Object?> args, RuleContext context) {
  // Arguments after the separator are ignored. A number is its string form,
  // a boolean is not a string
  final arg = args.isEmpty ? null : args[0];
  final separator = arg is String || (arg is num && arg.isFinite)
      ? livrToString(arg)
      : '';
  if (separator.isEmpty) {
    throw LivrSchemaException(
      'Rule [split] expects a non-empty separator string, got [$arg]',
    );
  }

  return (value, allValues) {
    if (value is String) {
      return value.isEmpty
          ? RuleResult.valid
          : RuleResult.value(value.split(separator));
    }
    if (value is num || value is bool) {
      return RuleResult.value(livrToString(value).split(separator));
    }
    return RuleResult.valid;
  };
}
