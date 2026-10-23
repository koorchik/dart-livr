import '../../rule.dart';
import '../../util.dart';

/// `list_of`: validates every element of a list with the same rules. Errors
/// are a list with the error of every element, `null` for valid elements.
/// Both the new syntax `{list_of: ['required', 'email']}` and the old one
/// `{list_of: [['required', 'email']]}` work.
LivrRule listOf(List<Object?> args, RuleContext context) {
  final first = args.isEmpty ? null : args[0];
  final validateItem = context.compileField(
    args.length == 1 && first is List ? first : args,
  );

  return (value, allValues) {
    if (isNoValue(value)) return RuleResult.valid;
    if (value is! List<Object?>) return RuleResult.error('FORMAT_ERROR');

    final length = value.length;
    final output = List<Object?>.filled(length, null, growable: true);
    List<Object?>? errors;

    for (var i = 0; i < length; i++) {
      final item = value[i];
      // Rules of an item see it as the only field of the data
      final result = validateItem(item, SingleFieldMap('field', item));

      if (result.isError) {
        (errors ??= List<Object?>.filled(length, null, growable: true))[i] =
            result.error;
      } else {
        output[i] = result.valueOr(item);
      }
    }

    if (errors != null) return RuleResult.error(errors);
    return RuleResult.value(output);
  };
}
