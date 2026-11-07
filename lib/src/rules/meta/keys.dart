import '../../rule.dart';
import '../../util.dart';

/// `keys`: the value must be an object, and every key of it is validated as
/// a string with the rules: `{keys: {'one_of': ['uk', 'en']}}`. A key that
/// fails is `WRONG_KEY` under that key. The rules only check: the keys and
/// the value do not change.
LivrRule keys(List<Object?> args, RuleContext context) {
  final first = args.isEmpty ? null : args[0];
  final rules = args.length == 1 && first is List ? first : args;
  if (rules.isEmpty) {
    throw const LivrSchemaException('Rule [keys] expects rules');
  }
  final validateKey = context.compileField(rules);

  return (value, allValues) {
    if (isNoValue(value)) return RuleResult.valid;
    if (value is! Map<Object?, Object?>) {
      return RuleResult.error('FORMAT_ERROR');
    }

    Map<String, Object?>? errors;
    for (final key in value.keys) {
      // Keys of JSON objects are strings
      if (key is! String) return RuleResult.error('FORMAT_ERROR');

      // A key has no object of its own: references in the rules see no
      // fields. Keys are never trimmed, autoTrim trims values only
      if (validateKey(key, noFields).isError) {
        (errors ??= <String, Object?>{})[key] = 'WRONG_KEY';
      }
    }

    return errors == null ? RuleResult.valid : RuleResult.error(errors);
  };
}
