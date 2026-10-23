import '../../rule.dart';
import '../../util.dart';

/// `variable_object`: validates an object with one of several schemas. The
/// value of the selector field chooses the schema:
/// `{variable_object: ['type', {'material': {...}, 'service': {...}}]}`.
LivrRule variableObject(List<Object?> args, RuleContext context) {
  final selectorField = stringArg(args, 0, 'variable_object');
  final schemas = ruleArg(args, 1, 'variable_object');
  if (schemas is! Map<Object?, Object?>) {
    throw LivrSchemaException(
      'Rule [variable_object] expects schemas by selector value, got [$schemas]',
    );
  }

  final validators = <String, LivrRule>{};
  schemas.forEach((selectorValue, schema) {
    if (schema is! Map<Object?, Object?>) {
      throw LivrSchemaException(
        'Rule [variable_object] expects a schema for [$selectorValue], got [$schema]',
      );
    }
    validators[livrToString(selectorValue)] = context.compileObject(schema);
  });

  return (value, allValues) {
    if (isNoValue(value)) return RuleResult.valid;
    if (value is! Map<Object?, Object?>) {
      return RuleResult.error('FORMAT_ERROR');
    }

    // The selector value must be a primitive value listed in the schemas
    final selectorValue = value[selectorField];
    if (isNoValue(selectorValue) || !isPrimitive(selectorValue)) {
      return RuleResult.error('FORMAT_ERROR');
    }
    final validateObject = validators[livrToString(selectorValue)];
    if (validateObject == null) return RuleResult.error('FORMAT_ERROR');

    return validateObject(value, allValues);
  };
}
