import '../../rule.dart';
import '../../util.dart';

/// `to_lc`: Converts the string to lower case. Numbers and booleans are converted to
/// strings, objects and lists are left as they are.
LivrRule toLc(List<Object?> args, RuleContext context) => _toLc;

RuleResult _toLc(Object? value, Map<Object?, Object?> allValues) {
  if (isNoValue(value) || !isPrimitive(value)) return RuleResult.valid;

  return RuleResult.value(livrToString(value).toLowerCase());
}
