import '../../rule.dart';
import '../../util.dart';

/// `values`: the value must be an object with any keys, and every value of
/// it is validated with the rules, as `list_of` validates every element:
/// `{values: ['required', 'positive_integer']}`. Errors are an object with
/// the failing keys only, the output is an object with the same keys.
LivrRule values(List<Object?> args, RuleContext context) {
  final first = args.isEmpty ? null : args[0];
  final rules = args.length == 1 && first is List ? first : args;
  if (rules.isEmpty) {
    throw const LivrSchemaException('Rule [values] expects rules');
  }
  final validateValue = context.compileField(rules);

  return (value, allValues) {
    if (isNoValue(value)) return RuleResult.valid;
    if (value is! Map<Object?, Object?>) {
      return RuleResult.error('FORMAT_ERROR');
    }

    final output = <String, Object?>{};
    Map<String, Object?>? errors;
    var isFormatError = false;

    // forEach() allocates no entries
    value.forEach((key, item) {
      // Keys of JSON objects are strings
      if (key is! String) {
        isFormatError = true;
        return;
      }

      // A value has no object of its own: equal_to_field and references in
      // its rules see no fields
      final result = validateValue(item, noFields);
      if (result.isError) {
        (errors ??= <String, Object?>{})[key] = result.error;
      } else if (errors == null) {
        output[key] = result.valueOr(item);
      }
    });

    if (isFormatError) return RuleResult.error('FORMAT_ERROR');
    final valueErrors = errors;
    if (valueErrors != null) return RuleResult.error(valueErrors);
    return RuleResult.value(output);
  };
}
