import '../../rule.dart';
import '../../util.dart';

/// `list_of_objects`: validates every element of a list with the same
/// object schema. Errors are a list with the errors of every element, `null`
/// for valid elements.
LivrRule listOfObjects(List<Object?> args, RuleContext context) {
  final schema = ruleArg(args, 0, 'list_of_objects');
  if (schema is! Map<Object?, Object?>) {
    throw LivrSchemaException(
      'Rule [list_of_objects] expects a schema, got [$schema]',
    );
  }

  final validateObject = context.compileObject(schema);

  return (value, allValues) {
    if (isNoValue(value)) return RuleResult.valid;
    if (value is! List<Object?>) return RuleResult.error('FORMAT_ERROR');

    final length = value.length;
    final output = List<Object?>.filled(length, null, growable: true);
    List<Object?>? errors;

    for (var i = 0; i < length; i++) {
      final result = validateObject(value[i], allValues);

      if (result.isError) {
        (errors ??= List<Object?>.filled(length, null, growable: true))[i] =
            result.error;
      } else {
        output[i] = result.value;
      }
    }

    if (errors != null) return RuleResult.error(errors);
    return RuleResult.value(output);
  };
}
