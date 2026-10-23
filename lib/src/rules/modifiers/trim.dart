import '../../rule.dart';
import '../../util.dart';

/// `trim`: Removes leading and trailing whitespace. Numbers and booleans are converted to
/// strings, objects and lists are left as they are.
LivrRule trim(List<Object?> args, RuleContext context) => _trim;

RuleResult _trim(Object? value, Map<Object?, Object?> allValues) {
  if (isNoValue(value) || !isPrimitive(value)) return RuleResult.valid;

  return RuleResult.value(livrToString(value).trim());
}
