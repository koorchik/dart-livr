/// A prepared rule: checks one value and returns a [RuleResult].
///
/// [allValues] is the object the value belongs to, so rules like
/// `equal_to_field` can read other fields. It is the input as given, never
/// modified.
typedef LivrRule =
    RuleResult Function(Object? value, Map<Object?, Object?> allValues);

/// Builds a [LivrRule] from the arguments in the schema.
///
/// `{ length_between: [1, 10] }` calls the builder with `[1, 10]`,
/// `{ max_length: 5 }` with `[5]` and `'required'` with `[]`. The builder does
/// the expensive work once (parses arguments, compiles regular expressions,
/// compiles nested rules through [context]) and returns a rule that only
/// checks values.
typedef RuleBuilder =
    LivrRule Function(List<Object?> args, RuleContext context);

/// What a rule returns: the value is valid and unchanged ([valid]), valid
/// with a new value ([RuleResult.value]), or invalid ([RuleResult.error]).
///
/// ```dart
/// LivrRule toCents(List<Object?> args, RuleContext context) {
///   return (value, allValues) {
///     if (isNoValue(value)) return RuleResult.valid;
///     if (value is! num) return RuleResult.error('FORMAT_ERROR');
///     return RuleResult.value((value * 100).round());
///   };
/// }
/// ```
///
/// It is an extension type: at run time a result is the new value itself, or
/// a constant for [valid], so a valid result allocates nothing. A rule must
/// return a result on every path, the compiler checks it.
extension type const RuleResult._(Object? _result) {
  /// A valid value, unchanged.
  static const RuleResult valid = RuleResult._(_Valid.instance);

  /// A valid value, with [value] as the output: modifiers, type coercion and
  /// metarules return it.
  const RuleResult.value(Object? value) : _result = value;

  /// An invalid value: [error] is an error code like `'TOO_SHORT'`, or the
  /// nested errors of a metarule (a `Map` for an object, a `List` for a
  /// list).
  RuleResult.error(Object error) : _result = _LivrError(error);

  /// Whether the value is valid and unchanged.
  bool get isValid => identical(_result, _Valid.instance);

  /// Whether the value is invalid.
  bool get isError => _result is _LivrError;

  /// Whether the value is valid and the rule returned a new value.
  bool get hasValue => !isValid && !isError;

  /// The error of an invalid value.
  Object get error => (_result as _LivrError).error;

  /// The new value of a valid value ([hasValue]).
  Object? get value => _result;

  /// The new value, or [original] when the rule did not change it. Meant for
  /// valid results.
  Object? valueOr(Object? original) => isValid ? original : _result;
}

// The error of an invalid RuleResult: an error code, or the nested errors of
// a metarule
final class _LivrError {
  _LivrError(this.error);

  final Object error;
}

// The marker of RuleResult.valid. A private class, so no rule can return it
// as a value
final class _Valid {
  const _Valid._();

  static const _Valid instance = _Valid._();
}

/// Compiles nested rules for metarules, with the rules registered for the
/// validator being built.
abstract interface class RuleContext {
  /// Compiles the rules of one field (a rule, or a list of rules applied one
  /// after another) into one rule. The rule returns the first error, or a new
  /// value when some rule changed the value.
  LivrRule compileField(Object? livrRules);

  /// Compiles a schema of an object into a rule. The rule returns
  /// the error `FORMAT_ERROR` for a value that is not a `Map`, the errors of
  /// the fields, or the validated object as the new value. Empty values are
  /// not skipped: that is up to the caller.
  LivrRule compileObject(Map<Object?, Object?> schema);
}

/// Thrown when a schema, a rule argument or an alias is invalid: an unknown
/// rule, a missing argument, an invalid regular expression and so on.
///
/// Schemas are compiled when a validator is created, so the constructor
/// throws it, never `validate()`.
final class LivrSchemaException implements Exception {
  const LivrSchemaException(this.message);

  final String message;

  @override
  String toString() => 'LivrSchemaException: $message';
}
