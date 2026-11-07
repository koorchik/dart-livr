import '../../rule.dart';

/// `any`: any value passes unchanged, objects, lists and empty values too.
/// Unlike a field without rules, the value stays in the output.
LivrRule any(List<Object?> args, RuleContext context) {
  if (args.isNotEmpty) {
    throw const LivrSchemaException('Rule [any] takes no arguments');
  }
  return _any;
}

RuleResult _any(Object? value, Map<Object?, Object?> allValues) =>
    RuleResult.valid;
