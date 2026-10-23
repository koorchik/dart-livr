import '../../rule.dart';
import '../../util.dart';

/// `to_uc`: Converts the string to upper case. Numbers and booleans are converted to
/// strings, objects and lists are left as they are.
LivrRule toUc(List<Object?> args, RuleContext context) => _toUc;

RuleResult _toUc(Object? value, Map<Object?, Object?> allValues) {
  if (isNoValue(value) || !isPrimitive(value)) return RuleResult.valid;

  return RuleResult.value(livrToString(value).toUpperCase());
}
