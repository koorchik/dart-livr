# livr

Fast, zero-dependency Dart validator for the [LIVR specification](https://livr-spec.org) (Language Independent Validation Rules, v2.0). Rules are plain data: store them in JSON, send them over the wire and validate the same way, with the same error codes, in Dart, JavaScript, Perl, Python, Go and [other languages](https://livr-spec.org/introduction/implementations.html).

- Returns only the fields that have rules, everything else is dropped.
- Reports errors for all fields at once, as codes shaped like the data.
- Cleans the data on the way: trims strings, converts `"25"` to `25`, sets defaults.
- Passes the whole LIVR test suite, on the Dart VM, AOT and the web.

## Install

```sh
dart pub add livr
```

## Quick start

A validator needs the schema and the type of its output. Describe the type by hand, for example as an extension type over the output map: it costs nothing at run time, the output is not copied.

```dart
import 'package:livr/livr.dart';

extension type SignUp(Map<String, Object?> _) {
  String get name => _['name'] as String;
  String get email => _['email'] as String;
  String? get gender => _['gender'] as String?;
  int get age => _['age'] as int;
  String get password => _['password'] as String;
}

final signUpValidator = Validator({
  'name': 'required',
  'email': ['required', 'email'],
  'gender': {'one_of': ['male', 'female']},
  'age': ['required', 'positiveInteger', {'minNumber': 18}],
  'password': ['required', {'min_length': 10}],
  'password2': {'equal_to_field': 'password'},
}, SignUp.new);

switch (signUpValidator.validate(input)) {
  case ValidationSuccess(:final output):
    save(output.email, output.age); // String, int
  case ValidationFailure(:final errors):
    respond422(errors); // {'email': 'WRONG_EMAIL', 'age': 'TOO_LOW'}
}
```

- `Validator(schema, convert)` compiles the schema once. An invalid schema (an unknown rule, an invalid regular expression) throws `LivrSchemaException` right away. A validator is immutable: create it once and validate any number of inputs.
- The type of the output comes from `convert`: `SignUp.new` of an extension type, or `User.fromJson` of a model class (`json_serializable`, `freezed`).
- `validate()` never changes its input. It accepts any `Map`, for example the output of `jsonDecode()`; data that is not a map is a `ValidationFailure('FORMAT_ERROR')`.
- `validateOrThrow()` returns the output or throws `LivrValidationException`.
- Rule names work as in the specification (`min_length`) and in camelCase (`minLength`). Field names are data and are never converted.
- `autoTrim: true` (or `Validator.defaultAutoTrim = true`) trims all strings of the input before validation.

## Types of the output

Nothing checks that the type matches the schema, so write the types the rules return:

| Rules | Type |
|---|---|
| `integer`, `positive_integer` | `int` |
| `decimal`, `positive_decimal` | `double` |
| `min_number`, `max_number`, `number_between` | `num` |
| string rules, `email`, `url`, `iso_date`, modifiers | `String` |
| `nested_object`, `variable_object` | `Map<String, Object?>`, or an extension type over it |
| `list_of`, `list_of_objects`, `list_of_different_objects` | `List<Object?>` |

A field without `required` or `default` can be missing, so its type is nullable. A mismatch is a `TypeError` when the field is read, or in `fromJson`.

### Schemas without a type

When the schema is not known at compile time (loaded from a database, different for every customer) or a service only checks data, `Validator.untyped()` returns the output as a `Map<String, Object?>`:

```dart
final validator = Validator.untyped(rulesFromDatabase);
```

`result.map(User.fromJson)` converts the output of one result.

## Custom rules

Everything is a rule: the built-in rules in `lib/src/rules/` are written exactly like your own, one rule per file, each with its own error codes. A rule builder gets the arguments of the rule from the schema and returns the rule. The rule returns a `RuleResult`: `RuleResult.valid`, a new value with `RuleResult.value(v)`, or an error with `RuleResult.error('CODE')`. The compiler checks that every path returns one.

```dart
import 'package:livr/livr.dart';
import 'package:livr/util.dart';

LivrRule strongPassword(List<Object?> args, RuleContext context) {
  final minLength = numberArg(args, 0, 'strong_password'); // {strong_password: 8}

  return (value, allValues) {
    if (isNoValue(value)) return RuleResult.valid; // leave empty values to 'required'
    if (value is! String) return RuleResult.error('FORMAT_ERROR');
    if (value.length < minLength) return RuleResult.error('WEAK_PASSWORD');
    return RuleResult.valid;
  };
}

extension type Account(Map<String, Object?> _) {
  String get password => _['password'] as String;
}

final accountValidator = Validator(
  {'password': ['required', {'strong_password': 8}]},
  Account.new,
  rules: {'strong_password': strongPassword}, // also found as strongPassword
);
```

- `Validator.registerDefaultRules({...})` registers rules for all validators created afterwards.
- Do the expensive work in the builder (parse arguments, compile regular expressions), so the rule only checks values.
- `allValues` is the object the value belongs to, for rules that compare fields.
- `package:livr/util.dart` has the helpers the built-in rules use: `isNoValue`, `isPrimitive`, `livrToString`, `parseNumber`, argument readers.
- Metarules compile nested rules through the `RuleContext`: `context.compileField(rules)` and `context.compileObject(schema)` return rules that validate a value or an object. All built-in metarules are written this way.

### Aliases

An alias names a set of rules, with an optional error code, without code:

```dart
extension type Person(Map<String, Object?> _) {
  int get age => _['age'] as int;
}

final personValidator = Validator(
  {'age': ['required', 'adult_age']},
  Person.new,
  aliases: [
    const LivrAlias(
      name: 'adult_age',
      rules: ['positive_integer', {'min_number': 18}],
      error: 'WRONG_AGE',
    ),
  ],
);
```

`LivrAlias.fromJson()` reads the JSON form, and `Validator.registerAliasedDefaultRule()` registers an alias for all validators.

## Rules

| Group | Rules |
|---|---|
| Common | `required`, `not_empty`, `not_empty_list`, `any_object` |
| String | `string`, `eq`, `one_of`, `min_length`, `max_length`, `length_equal`, `length_between`, `like` |
| Numeric | `integer`, `positive_integer`, `decimal`, `positive_decimal`, `min_number`, `max_number`, `number_between` |
| Special | `email`, `url`, `iso_date`, `equal_to_field` |
| Modifiers | `trim`, `to_lc`, `to_uc`, `remove`, `leave_only`, `default` |
| Metarules | `nested_object`, `variable_object`, `list_of`, `list_of_objects`, `list_of_different_objects`, `or` |

See [livr-spec.org](https://livr-spec.org/validation-rules.html) for every rule and its error codes.

## Dart specifics

The specification leaves some details to the language. This implementation chooses:

- **Output types follow the rule**, see [Types of the output](#types-of-the-output).
- **Numbers as strings** are formatted like in JavaScript, so values compare the same way in all implementations: `10.0` is `"10"`.
- **Booleans are not numbers**: numeric rules return their error for `true`.
- **Strings of numbers** are decimal numbers only, so no hexadecimal, `Infinity` or `NaN`.
- **String lengths are counted in characters** (Unicode code points): an emoji is one character.
- **Empty values**: a missing field, `null` and `''` are all empty. A field with `null` stays in the output as `null`; a missing field stays missing.
- **`like`** uses Dart regular expressions, which have the syntax of JavaScript ones. Only the `i` flag is supported, as in the specification.

## Performance

Schemas are compiled into closures once, never into source code. Validation is a loop over the compiled rules that allocates little: the output map is laid out by the schema, so it is filled by index without hashing.

The scenarios of the [LIVR benchmarks](https://js.livr-spec.org/why/performance) (a five-field form; an object with two levels of nesting and a list), with a validator created once (static) and a new validator per validation (dynamic), on one core:

| Scenario | Dart AOT | Dart JIT |
|---|---|---|
| Simple, static | 5.6 M ops/sec | 7.0 M ops/sec |
| Simple, dynamic | 2.0 M ops/sec | 2.6 M ops/sec |
| Nested, static | 3.3 M ops/sec | 3.2 M ops/sec |
| Nested, dynamic | 1.2 M ops/sec | 1.3 M ops/sec |

On the same machine, the JavaScript implementation (Node.js 26) does 4.4, 1.9, 2.5 and 0.95 M ops/sec. Run the benchmark yourself:

```sh
dart run benchmark/benchmark.dart
dart compile exe benchmark/benchmark.dart -o build/benchmark && build/benchmark
```

## Development

```sh
dart test                          # unit tests and the LIVR test suite
dart test -p node test/validator_test.dart   # unit tests on the web (dart2js), needs Node.js
dart analyze --fatal-infos && dart format --set-exit-if-changed .
```

`test/test_suite` is a copy of the LIVR [test suite](https://livr-spec.org/how-to-contribute/test-suite.html); the page has the command that replaces it with the current one.
