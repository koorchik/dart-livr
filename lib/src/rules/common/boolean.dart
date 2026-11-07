import '../../rule.dart';

/// `boolean`: the value must be `true`, `false`, `1`, `0`, `'1'`, `'0'`,
/// `'true'` or `'false'`, and the output is a `bool`. Strings are
/// case-sensitive: `'True'` is not a boolean.
LivrRule boolean(List<Object?> args, RuleContext context) {
  if (args.isNotEmpty) {
    throw const LivrSchemaException('Rule [boolean] takes no arguments');
  }
  return _boolean;
}

RuleResult _boolean(Object? value, Map<Object?, Object?> allValues) {
  if (value is bool) return RuleResult.valid;
  if (value is String) {
    switch (value) {
      case '':
        return RuleResult.valid;
      case '1' || 'true':
        return const RuleResult.value(true);
      case '0' || 'false':
        return const RuleResult.value(false);
    }
    return RuleResult.error('NOT_BOOLEAN');
  }
  if (value is num) {
    // 1.0 is 1, -0.0 is 0
    if (value == 1) return const RuleResult.value(true);
    if (value == 0) return const RuleResult.value(false);
    return RuleResult.error(value.isFinite ? 'NOT_BOOLEAN' : 'FORMAT_ERROR');
  }
  if (value == null) return RuleResult.valid;
  return RuleResult.error('FORMAT_ERROR');
}
