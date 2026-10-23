import '../../rule.dart';
import '../../util.dart';

/// `default`: sets the value when it is empty: missing, `null` or an empty
/// string. Other values, `0` included, are kept.
LivrRule defaultValue(List<Object?> args, RuleContext context) {
  final defaultValue = ruleArg(args, 0, 'default');

  // Every output gets its own copy of a list or a map, so changing the output
  // never changes the schema
  if (defaultValue is Map || defaultValue is List) {
    return (value, allValues) => isNoValue(value)
        ? RuleResult.value(deepCopy(defaultValue))
        : RuleResult.valid;
  }

  final defaultResult = RuleResult.value(defaultValue);
  return (value, allValues) =>
      isNoValue(value) ? defaultResult : RuleResult.valid;
}
