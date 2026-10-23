import '../../rule.dart';
import '../../util.dart';

/// `eq`: the value must be equal to the argument. Values are compared as
/// strings, and the output is the argument.
LivrRule eq(List<Object?> args, RuleContext context) {
  final allowedValue = ruleArg(args, 0, 'eq');
  if (!isPrimitive(allowedValue)) {
    throw LivrSchemaException(
      'Rule [eq] expects a primitive value, got [$allowedValue]',
    );
  }
  final strAllowedValue = livrToString(allowedValue);

  return (value, allValues) {
    if (isNoValue(value)) return RuleResult.valid;
    if (!isPrimitive(value)) return RuleResult.error('FORMAT_ERROR');

    if (livrToString(value) == strAllowedValue) {
      return RuleResult.value(allowedValue);
    }

    return RuleResult.error('NOT_ALLOWED_VALUE');
  };
}
