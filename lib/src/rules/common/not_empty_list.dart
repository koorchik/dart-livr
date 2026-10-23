import '../../rule.dart';

/// `not_empty_list`: the value must be a list with at least one element.
LivrRule notEmptyList(List<Object?> args, RuleContext context) => _notEmptyList;

RuleResult _notEmptyList(Object? value, Map<Object?, Object?> allValues) {
  if (value == null || (value is String && value.isEmpty)) {
    return RuleResult.error('CANNOT_BE_EMPTY');
  }
  if (value is! List) return RuleResult.error('FORMAT_ERROR');
  if (value.isEmpty) return RuleResult.error('CANNOT_BE_EMPTY');
  return RuleResult.valid;
}
