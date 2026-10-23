import 'compiler.dart';
import 'rule.dart';
import 'rules/built_in_rules.dart';
import 'util.dart';

/// An alias: a named set of rules, with an optional error code that replaces
/// the errors of the rules.
///
/// ```dart
/// const LivrAlias(
///   name: 'adult_age',
///   rules: ['positive_integer', {'min_number': 18}],
///   error: 'WRONG_AGE',
/// )
/// ```
final class LivrAlias {
  const LivrAlias({required this.name, required this.rules, this.error});

  /// An alias from its JSON form `{ name, rules, error? }`, like in the
  /// `aliases.json` files of the LIVR test suite.
  factory LivrAlias.fromJson(Map<Object?, Object?> json) {
    final name = json['name'];
    final error = json['error'];

    if (name is! String || name.isEmpty) {
      throw const LivrSchemaException('Alias name required');
    }
    if (!json.containsKey('rules')) {
      throw LivrSchemaException('Alias [$name] has no rules');
    }
    if (error != null && error is! String) {
      throw LivrSchemaException('Error of alias [$name] must be a string');
    }

    return LivrAlias(name: name, rules: json['rules'], error: error as String?);
  }

  final String name;

  /// The rules, like the rules of a field: a rule or a list of rules.
  final Object? rules;

  /// The error code returned instead of the errors of [rules].
  final String? error;
}

/// The result of a validation: [ValidationSuccess] with the output of type
/// [T], or [ValidationFailure] with the errors.
///
/// [map] converts the output of a result, for example of an untyped
/// validator, to a type of your own.
sealed class ValidationResult<T> {
  const ValidationResult();

  bool get isValid;

  /// Converts the output of a valid result with [convert], for example to a
  /// model with `fromJson`. An invalid result is returned as it is.
  ///
  /// ```dart
  /// final result = validator.validate(body).map(User.fromJson);
  /// ```
  ValidationResult<R> map<R>(R Function(T output) convert) {
    return switch (this) {
      ValidationSuccess(:final output) => ValidationSuccess(convert(output)),
      final ValidationFailure failure => failure,
    };
  }
}

/// Valid data: [output] has only the fields that have rules, with the values
/// changed by the rules.
final class ValidationSuccess<T> extends ValidationResult<T> {
  const ValidationSuccess(this.output);

  final T output;

  @override
  bool get isValid => true;

  @override
  String toString() => 'ValidationSuccess($output)';
}

/// Invalid data: [errors] has an error for every invalid field, in the shape
/// of the data (`{'address': {'zip': 'NOT_POSITIVE_INTEGER'}}`). For data
/// that is not a map, it is the error code `'FORMAT_ERROR'`.
///
/// Errors do not depend on the type of the output: `Never` is a subtype of
/// every type, so a failure is a `ValidationResult` of any type.
final class ValidationFailure extends ValidationResult<Never> {
  const ValidationFailure(this.errors);

  /// A `Map<String, Object?>` of field errors, or `'FORMAT_ERROR'`.
  final Object errors;

  @override
  bool get isValid => false;

  @override
  String toString() => 'ValidationFailure($errors)';
}

/// Thrown by [Validator.validateOrThrow] for invalid data.
final class LivrValidationException implements Exception {
  const LivrValidationException(this.errors);

  /// The same as [ValidationFailure.errors].
  final Object errors;

  @override
  String toString() => 'LivrValidationException: $errors';
}

/// Validates data with LIVR rules and returns the output as [T].
///
/// The schema is compiled once, when the validator is created, so an invalid
/// schema throws [LivrSchemaException] right away. A validator is immutable:
/// create it once and validate any number of inputs with it.
///
/// The type of the output is required: describe it, for example as an
/// extension type over the output map, which costs nothing at run time.
///
/// ```dart
/// extension type User(Map<String, Object?> _) {
///   String get email => _['email'] as String;
///   int get age => _['age'] as int;
/// }
///
/// final validator = Validator({
///   'email': ['required', 'email'],
///   'age': ['required', 'positiveInteger', {'minNumber': 18}],
/// }, User.new);
///
/// switch (validator.validate(input)) {
///   case ValidationSuccess(:final output): print(output.age); // int
///   case ValidationFailure(:final errors): print(errors);
/// }
/// ```
///
/// For schemas without a type known at compile time, like schemas loaded
/// from a database, [Validator.untyped] returns the output as a `Map`.
///
/// Rule names can be written as in the specification (`min_length`) or in
/// camelCase (`minLength`).
final class Validator<T> {
  /// Creates a validator for [schema] that converts the output with
  /// [convert]: `User.new` of an extension type over the output map, or
  /// `User.fromJson` of a model class. The type of the output comes from
  /// [convert].
  ///
  /// Nothing checks that the type matches the schema. The rules guarantee the
  /// types of the values (`positive_integer` returns an `int`), so write the
  /// types the rules return; a mismatch is a `TypeError` when a field is
  /// read, or in [convert]. Exceptions of [convert] are not caught.
  ///
  /// [rules] and [aliases] are registered for this validator only and take
  /// precedence over the default rules. With [autoTrim], all strings of the
  /// input are trimmed before validation; it defaults to [defaultAutoTrim].
  factory Validator(
    Map<Object?, Object?> schema,
    T Function(Map<String, Object?> output) convert, {
    Map<String, RuleBuilder>? rules,
    Iterable<LivrAlias>? aliases,
    bool? autoTrim,
  }) => Validator._(
    _compile(schema, rules, aliases),
    autoTrim ?? defaultAutoTrim,
    convert,
  );

  /// Creates a validator for [schema] that returns the output as a `Map`,
  /// without a type: for schemas built at run time (loaded from a database,
  /// different for every customer) and for services that only check data.
  /// Prefer [Validator.new] with a type when the schema is known.
  static Validator<Map<String, Object?>> untyped(
    Map<Object?, Object?> schema, {
    Map<String, RuleBuilder>? rules,
    Iterable<LivrAlias>? aliases,
    bool? autoTrim,
  }) => Validator._(
    _compile(schema, rules, aliases),
    autoTrim ?? defaultAutoTrim,
    null,
  );

  Validator._(this._schema, this.autoTrim, this._convert);

  static CompiledObject _compile(
    Map<Object?, Object?> schema,
    Map<String, RuleBuilder>? rules,
    Iterable<LivrAlias>? aliases,
  ) {
    Map<String, RuleBuilder>? validatorRules;

    if (rules != null || aliases != null) {
      validatorRules = {};
      rules?.forEach((name, rule) => addRule(validatorRules!, name, rule));
      for (final alias in aliases ?? const <LivrAlias>[]) {
        addRule(validatorRules, alias.name, _buildAlias(alias));
      }
    }

    return Compiler(validatorRules, _defaultRules).compileSchema(schema);
  }

  final CompiledObject _schema;

  // Null for untyped validators: their output is the map itself
  final T Function(Map<String, Object?> output)? _convert;

  /// Whether strings of the input are trimmed before validation.
  final bool autoTrim;

  /// Validates [data], usually a `Map` from `jsonDecode()`. The data is never
  /// changed.
  ValidationResult<T> validate(Object? data) {
    if (autoTrim) data = trimDeep(data);
    if (data is! Map<Object?, Object?>) {
      return const ValidationFailure('FORMAT_ERROR');
    }

    final result = _schema.validate(data);
    if (result.isError) return ValidationFailure(result.error);

    final output = result.value as Map<String, Object?>;
    final convert = _convert;
    return ValidationSuccess(convert == null ? output as T : convert(output));
  }

  /// Validates [data] and returns the output, or throws
  /// [LivrValidationException] with the errors.
  T validateOrThrow(Object? data) {
    return switch (validate(data)) {
      ValidationSuccess(:final output) => output,
      ValidationFailure(:final errors) => throw LivrValidationException(errors),
    };
  }

  /// Trims strings of the input for validators created without the
  /// `autoTrim` argument.
  static bool defaultAutoTrim = false;

  // Rules registered with registerDefaultRules() and
  // registerAliasedDefaultRule(), with their camelCase names
  static final Map<String, RuleBuilder> _sharedRules = {};

  // Built-in and shared rules in one map, so a rule is found with one lookup.
  // Rebuilt on every registration, which is rare
  static Map<String, RuleBuilder> _defaultRules = _buildDefaultRules();

  static Map<String, RuleBuilder> _buildDefaultRules() {
    final defaultRules = <String, RuleBuilder>{};
    builtInRules.forEach((name, rule) => addRule(defaultRules, name, rule));
    defaultRules.addAll(_sharedRules);
    return defaultRules;
  }

  /// All default rules: the built-in rules and the rules registered with
  /// [registerDefaultRules] and [registerAliasedDefaultRule], with their
  /// camelCase names.
  static Map<String, RuleBuilder> get defaultRules =>
      Map.unmodifiable(_defaultRules);

  /// Registers rules for all validators created afterwards. They take
  /// precedence over built-in rules with the same name.
  static void registerDefaultRules(Map<String, RuleBuilder> rules) {
    rules.forEach((name, rule) => addRule(_sharedRules, name, rule));
    _defaultRules = _buildDefaultRules();
  }

  /// Registers an alias for all validators created afterwards.
  static void registerAliasedDefaultRule(LivrAlias alias) {
    addRule(_sharedRules, alias.name, _buildAlias(alias));
    _defaultRules = _buildDefaultRules();
  }

  static RuleBuilder _buildAlias(LivrAlias alias) {
    if (alias.name.isEmpty) {
      throw const LivrSchemaException('Alias name required');
    }
    return buildAliasedRule(alias.rules, alias.error);
  }
}
