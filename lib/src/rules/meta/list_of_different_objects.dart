import '../../rule.dart';
import '../../util.dart';

/// `list_of_different_objects`: validates every element of a list with one
/// of several object schemas. The value of the selector field of an element
/// chooses the schema, like in `variable_object`.
LivrRule listOfDifferentObjects(List<Object?> args, RuleContext context) {
  final selectorField = stringArg(args, 0, 'list_of_different_objects');
  final schemas = ruleArg(args, 1, 'list_of_different_objects');
  if (schemas is! Map<Object?, Object?>) {
    throw LivrSchemaException(
      'Rule [list_of_different_objects] expects schemas by selector value, '
      'got [$schemas]',
    );
  }

  final validators = <String, LivrRule>{};
  schemas.forEach((selectorValue, schema) {
    if (schema is! Map<Object?, Object?>) {
      throw LivrSchemaException(
        'Rule [list_of_different_objects] expects a schema for '
        '[$selectorValue], got [$schema]',
      );
    }
    validators[livrToString(selectorValue)] = context.compileObject(schema);
  });

  return (value, allValues) {
    if (isNoValue(value)) return RuleResult.valid;
    if (value is! List<Object?>) return RuleResult.error('FORMAT_ERROR');

    final length = value.length;
    final output = List<Object?>.filled(length, null, growable: true);
    List<Object?>? errors;

    for (var i = 0; i < length; i++) {
      final item = value[i];
      RuleResult? result;

      // The selector value must be a primitive value listed in the schemas
      if (item is Map<Object?, Object?>) {
        final selectorValue = item[selectorField];
        final validateObject =
            isNoValue(selectorValue) || !isPrimitive(selectorValue)
                ? null
                : validators[livrToString(selectorValue)];
        if (validateObject != null) result = validateObject(item, allValues);
      }
      result ??= RuleResult.error('FORMAT_ERROR');

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
