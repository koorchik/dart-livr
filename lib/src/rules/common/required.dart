import '../../rule.dart';
import '../../util.dart';

/// `required`: the value must be present, not `null` and not an empty
/// string. `0` and `false` are valid values.
LivrRule required(List<Object?> args, RuleContext context) => _required;

RuleResult _required(Object? value, Map<Object?, Object?> allValues) =>
    isNoValue(value) ? RuleResult.error('REQUIRED') : RuleResult.valid;
