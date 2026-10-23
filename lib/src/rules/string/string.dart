import '../../rule.dart';
import '../../util.dart';

/// `string`: the value must be a primitive value, it is converted to a
/// string.
LivrRule string(List<Object?> args, RuleContext context) => _string;

RuleResult _string(Object? value, Map<Object?, Object?> allValues) {
  if (isNoValue(value)) return RuleResult.valid;
  if (!isPrimitive(value)) return RuleResult.error('FORMAT_ERROR');

  return value is String
      ? RuleResult.valid
      : RuleResult.value(livrToString(value));
}
