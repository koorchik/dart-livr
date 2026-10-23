import 'object_output.dart';
import 'rule.dart';
import 'util.dart';

/// Adds a rule and its camelCase name. The camelCase name follows the rule,
/// unless it was registered as a separate rule.
void addRule(Map<String, RuleBuilder> registry, String name, RuleBuilder rule) {
  final camelizedName = camelize(name);

  if (camelizedName != name &&
      (!registry.containsKey(camelizedName) ||
          identical(registry[camelizedName], registry[name]))) {
    registry[camelizedName] = rule;
  }

  registry[name] = rule;
}

/// Builds the rule of an alias: its rules run as one field, and [error], if
/// set, replaces their errors.
RuleBuilder buildAliasedRule(Object? rules, String? error) {
  return (args, context) {
    final validateValue = context.compileField(rules);
    if (error == null) {
      // Rules of an alias see the value as the only field of the data
      return (value, allValues) =>
          validateValue(value, SingleFieldMap('value', value));
    }

    final aliasError = RuleResult.error(error);
    return (value, allValues) {
      final result = validateValue(value, SingleFieldMap('value', value));
      return result.isError ? aliasError : result;
    };
  };
}

const List<Object?> _noArgs = [];

/// Compiles schemas with the rules of one validator. Nested schemas of
/// metarules and aliases are compiled with the same registry, it is never
/// copied.
final class Compiler implements RuleContext {
  Compiler(this._rules, this._defaultRules);

  // Rules of the validator (registered for it, and its aliases), or null
  final Map<String, RuleBuilder>? _rules;
  final Map<String, RuleBuilder> _defaultRules;

  CompiledObject compileSchema(Map<Object?, Object?> schema) {
    // Lists of the final size: fields with an empty list of rules are rare
    var length = schema.length;
    var names = List<String>.filled(length, '');
    var rules = List<LivrRule>.filled(length, _setMissing);
    var i = 0;

    schema.forEach((fieldName, fieldRules) {
      if (fieldName is! String) {
        throw LivrSchemaException(
          'Field names must be strings, got [$fieldName]',
        );
      }

      // A field with an empty list of rules is not validated and not in the
      // output, like a field that is not in the schema
      if (fieldRules is List && fieldRules.isEmpty) return;

      names[i] = fieldName;
      rules[i] = compileField(fieldRules);
      i++;
    });

    if (i < length) {
      length = i;
      names = List.of(names.take(length), growable: false);
      rules = List.of(rules.take(length), growable: false);
    }

    return CompiledObject(names, rules);
  }

  @override
  LivrRule compileField(Object? livrRules) {
    if (livrRules is! List) return _buildRule(livrRules);

    // No rules: the value becomes null, like the value of a field that is
    // not in the schema
    if (livrRules.isEmpty) return _setMissing;

    // One rule is the field rule itself, it needs no chain
    if (livrRules.length == 1) return _buildRule(livrRules[0]);

    if (livrRules.length == 2) {
      return _chainOfTwo(_buildRule(livrRules[0]), _buildRule(livrRules[1]));
    }

    return _chain(
      List.generate(
        livrRules.length,
        (i) => _buildRule(livrRules[i]),
        growable: false,
      ),
    );
  }

  @override
  LivrRule compileObject(Map<Object?, Object?> schema) =>
      compileSchema(schema).call;

  LivrRule _buildRule(Object? livrRule) {
    final String name;
    final List<Object?> args;

    if (livrRule is String) {
      // The most common form: a rule without arguments
      name = livrRule;
      args = _noArgs;
    } else if (livrRule is Map) {
      if (livrRule.isEmpty) {
        throw const LivrSchemaException('A rule must have a name, got {}');
      }

      // The first key is the rule name, like in all implementations
      final key = livrRule.keys.first;
      if (key is! String) {
        throw LivrSchemaException('Rule names must be strings, got [$key]');
      }

      final ruleArgs = livrRule[key];
      name = key;
      args = ruleArgs is List ? ruleArgs : [ruleArgs];
    } else {
      throw LivrSchemaException(
        'A rule must be a name or a map with arguments, got [$livrRule]',
      );
    }

    final ruleBuilder = _rules?[name] ?? _defaultRules[name];
    if (ruleBuilder == null) {
      throw LivrSchemaException('Rule [$name] not registered');
    }

    return ruleBuilder(args, this);
  }
}

RuleResult _setMissing(Object? value, Map<Object?, Object?> allValues) =>
    const RuleResult.value(null);

// Two rules of a field, like ['required', 'email']: the most common chain
LivrRule _chainOfTwo(LivrRule first, LivrRule second) {
  return (value, allValues) {
    final result = first(value, allValues);
    if (result.isError) return result;
    if (result.isValid) return second(value, allValues);

    final secondResult = second(result.value, allValues);
    return secondResult.isValid ? result : secondResult;
  };
}

/// The rules of a field, applied one after another: each one gets the value
/// returned by the previous one, and the first error stops the chain. Returns
/// a new value only when some rule changes the value.
LivrRule _chain(List<LivrRule> rules) {
  return (value, allValues) {
    var isChanged = false;

    for (var i = 0; i < rules.length; i++) {
      final result = rules[i](value, allValues);
      if (result.isValid) continue;
      if (result.isError) return result;

      value = result.value;
      isChanged = true;
    }

    return isChanged ? RuleResult.value(value) : RuleResult.valid;
  };
}

/// A compiled schema of an object: the rule of every field, by the index of
/// the field in the [Shape] of the schema.
final class CompiledObject {
  CompiledObject(List<String> names, this._rules) : _shape = Shape(names);

  final Shape _shape;
  final List<LivrRule> _rules;

  /// Validates [data]: returns the errors of the fields, or the validated
  /// object as the new value.
  RuleResult validate(Map<Object?, Object?> data) {
    final shape = _shape;
    final names = shape.names;
    final rules = _rules;
    final values = List<Object?>.filled(names.length, absent);
    var length = 0;
    Map<String, Object?>? errors;

    for (var i = 0; i < names.length; i++) {
      final name = names[i];
      final value = data[name];
      final result = rules[i](value, data);

      if (result.isValid) {
        // A missing field stays missing, a null value stays null
        if (value != null || data.containsKey(name)) {
          values[i] = value;
          length++;
        }
      } else if (result.isError) {
        (errors ??= <String, Object?>{})[name] = result.error;
      } else {
        values[i] = result.value;
        length++;
      }
    }

    if (errors != null) return RuleResult.error(errors);
    return RuleResult.value(ObjectOutput(shape, values, length));
  }

  /// The object as a rule, for metarules.
  RuleResult call(Object? value, Map<Object?, Object?> allValues) {
    if (value is! Map<Object?, Object?>) {
      return RuleResult.error('FORMAT_ERROR');
    }
    return validate(value);
  }
}
