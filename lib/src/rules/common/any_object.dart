import '../../rule.dart';
import '../../util.dart';

/// `any_object`: the value must be an object (a `Map`). Its content is not
/// validated.
LivrRule anyObject(List<Object?> args, RuleContext context) => _anyObject;

RuleResult _anyObject(Object? value, Map<Object?, Object?> allValues) {
  if (isNoValue(value)) return RuleResult.valid;
  if (value is! Map) return RuleResult.error('FORMAT_ERROR');
  return RuleResult.valid;
}
