import '../../rule.dart';
import '../../util.dart';

/// `when`: validates the value with rules that depend on another field.
///
/// - `{when: [reference, condition, rulesIfTrue, rulesIfFalse]}`: the
///   condition is true when the referenced value is not empty and passes the
///   `condition` rules (their output is discarded). `rulesIfFalse` is
///   optional.
/// - `{when: [reference, {'card': rules, 'bank': rules}]}`: the string form
///   of the referenced value chooses the rules. An empty or unknown
///   referenced value lets only an empty value pass, others are
///   `NOT_ALLOWED_VALUE`.
///
/// The reference is a field of the object, see [parseReference]. A branch
/// gets the value as it is, empty values too. An empty list of rules `[]` is
/// a schema error: `any` is a branch without rules. Arguments after the 4th
/// are ignored.
LivrRule when(List<Object?> args, RuleContext context) {
  if (args.length < 2) {
    throw LivrSchemaException(
      'Rule [when] expects a reference and cases, or a reference, a '
      'condition, rules if true and optional rules if false, got '
      '${args.length} argument(s)',
    );
  }

  final reference = parseReference(args[0], 'when');
  if (args.length == 2) return _switch(reference, args[1], context);

  final condition = _compileBranch(args[1], context);
  final rulesIfTrue = _compileBranch(args[2], context);
  final rulesIfFalse = args.length >= 4
      ? _compileBranch(args[3], context)
      : _noRules;

  return (value, allValues) {
    final refValue = reference(allValues);

    // The condition rules see the object of the field, like the branches
    final isTrue =
        !isNoValue(refValue) && !condition(refValue, allValues).isError;
    return (isTrue ? rulesIfTrue : rulesIfFalse)(value, allValues);
  };
}

LivrRule _switch(FieldReference reference, Object? cases, RuleContext context) {
  if (cases is! Map<Object?, Object?> || cases.isEmpty) {
    throw LivrSchemaException(
      'Rule [when] expects cases, an object of values to rules, got [$cases]',
    );
  }

  final rulesByValue = <String, LivrRule>{};
  cases.forEach((caseValue, rules) {
    rulesByValue[livrToString(caseValue)] = _compileBranch(rules, context);
  });

  return (value, allValues) {
    final refValue = reference(allValues);

    // An empty or unknown referenced value chooses no case. An empty value
    // passes unchanged (the referenced field reports its own errors), any
    // other value would pass unchecked
    final rules = isNoValue(refValue) || !isPrimitive(refValue)
        ? null
        : rulesByValue[livrToString(refValue)];
    if (rules == null) {
      return isNoValue(value)
          ? RuleResult.valid
          : RuleResult.error('NOT_ALLOWED_VALUE');
    }
    return rules(value, allValues);
  };
}

// The rules of the condition, a branch or a case. An empty list is almost
// always a mistake, and for a field it would mean "not in the output"
LivrRule _compileBranch(Object? rules, RuleContext context) {
  if (rules is List && rules.isEmpty) {
    throw const LivrSchemaException(
      'Rule [when] expects rules, got []: use "any" for no rules',
    );
  }
  return context.compileField(rules);
}

// A false condition without RULES_IF_FALSE: the value passes unchanged
RuleResult _noRules(Object? value, Map<Object?, Object?> allValues) =>
    RuleResult.valid;
