import '../../rule.dart';
import '../../util.dart';

/// `nested_object`: validates a nested object with its own schema. Errors
/// have the shape of the object.
LivrRule nestedObject(List<Object?> args, RuleContext context) {
  final schema = ruleArg(args, 0, 'nested_object');
  if (schema is! Map<Object?, Object?>) {
    throw LivrSchemaException(
      'Rule [nested_object] expects a schema, got [$schema]',
    );
  }

  final validateObject = context.compileObject(schema);

  return (value, allValues) {
    if (isNoValue(value)) return RuleResult.valid;
    return validateObject(value, allValues);
  };
}
