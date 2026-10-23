import '../../rule.dart';

/// `not_empty`: the value must not be an empty string, if it is present.
LivrRule notEmpty(List<Object?> args, RuleContext context) => _notEmpty;

RuleResult _notEmpty(Object? value, Map<Object?, Object?> allValues) =>
    value is String && value.isEmpty
    ? RuleResult.error('CANNOT_BE_EMPTY')
    : RuleResult.valid;
