# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`livr` is a Dart implementation of the LIVR specification (Language Independent Validation Rules, https://livr-spec.org). Zero runtime dependencies; it runs on the VM, AOT and the web. Performance is a priority: measure changes on hot paths with the benchmark.

## Commands

```bash
dart test                                    # all tests, the LIVR test suite included
dart test test/test_suite_test.dart          # the test suite only
dart test -p node                            # the tests on dart2js (Node.js); files that read test/test_suite are @TestOn('vm')
dart analyze --fatal-infos && dart format --set-exit-if-changed .
dart compile exe benchmark/benchmark.dart -o build/benchmark && build/benchmark   # AOT benchmark
dart run benchmark/benchmark.dart                                                 # JIT benchmark
```

## Architecture (lib/)

- `livr.dart` - public API; `util.dart` - helpers for custom rules; `rules.dart` - builders of all built-in rules
- `src/rule.dart` - the rule contract: `LivrRule` (`RuleResult Function(value, allValues)`), `RuleBuilder` (`LivrRule Function(args, context)`), `RuleResult`, `RuleContext`, `LivrSchemaException`
- `src/validator.dart` - `Validator<T>` (compiles when created, immutable; the type of the output is required: `Validator(schema, User.new)` with an extension type over the output map, or `User.fromJson`; `Validator.untyped(schema)` returns the map, for schemas built at run time), `ValidationResult<T>` (sealed: `ValidationSuccess<T>` / `ValidationFailure`, which is a `ValidationResult<Never>`, so it fits any `T`; `map()` converts the output), `LivrAlias`, the global registry (`registerDefaultRules`, `registerAliasedDefaultRule`, `defaultAutoTrim`)
- `src/compiler.dart` - rule parsing, field chains, `CompiledObject`, `RuleContext` implementation, aliases, camelCase registration (`addRule`)
- `src/object_output.dart` - `ObjectOutput`, the output map of an object: values in a list by the index of the field in the schema (`Shape`), filled without hashing. It must behave like any mutable `Map` (`test/object_output_test.dart`)
- `src/util.dart` - `isNoValue`, `isPrimitive`, `livrToString` (JavaScript number formatting), `parseNumber`, `codePointLength`, `trimDeep` (copy-on-write), `SingleFieldMap`
- `src/rules/<group>/<rule>.dart` - one rule per file, `src/rules/built_in_rules.dart` - the name → builder map

### RuleResult

`RuleResult` is an extension type over `Object?`: `RuleResult.valid` is a private constant (valid, unchanged), a private `_LivrError` is an error, anything else is the new value. It allocates nothing on success, and a missing `return` in a rule is a compile error. The core knows no error codes: every rule returns its own with `RuleResult.error('CODE')` (one small allocation, on errors only), like a custom rule. Keep the core small: built-in rules are also the examples for custom ones.

### Rule files

- One rule per file: the snake_case spec name as the file name, one public `RuleBuilder` in lowerCamelCase (`minLength`; `default` is `defaultValue`). An argument-less rule returns a private top-level function (a constant tear-off, no allocation per validator)
- Every file is self-contained: it imports only `../../rule.dart` and `../../util.dart`. No imports between rule files and no shared rule-specific modules; repeat small code instead (`_parseDecimal` is in both decimal rules)
- Metarules use only `RuleContext.compileField` / `compileObject`, like third-party metarules
- Expensive work goes to the builder (arguments, `RegExp` - cached by pattern in `like`, lookup tables); the rule closure only checks values
- Rules skip empty values (`isNoValue`) except `required`, `not_empty`, `not_empty_list`; non-primitive values are `FORMAT_ERROR` for string, numeric and special rules; modifiers leave them as they are
- Invalid arguments throw `LivrSchemaException` from the builder (`ruleArg`, `numberArg`, `stringArg`)

### Semantics that differ from JavaScript

Numeric rules reject booleans; integer rules return `int`, decimal rules `double`; strings of numbers are decimal only (`parseNumber`); lengths are in code points; `null` and a missing field are the same empty value for rules, the engine keeps `null` fields in the output. They are listed in the README: keep it in sync.

## Tests (test/)

- `test_suite/` - a copy of the LIVR test suite, not formatted or analyzed; `test_suite_test.dart` runs it, `camel_case_test.dart` runs it again with camelCase rule names
- `email_test.dart` - the `email` rule is a scanner for the regular expression of the JavaScript implementation; the test compares both on the suite, edge cases and random strings
- Tests that change the global registry or `defaultAutoTrim` restore it or live in their own file (every test file runs in its own isolate)

## CI

`.github/workflows/test.yml` runs analyze, the format check, the VM tests and the Node.js tests on the lowest supported SDK (`environment.sdk` in `pubspec.yaml`, keep them in sync) and on the latest stable one. The lowest SDK is the lowest one the dev dependencies allow (`lints ^6` needs 3.8).

## Code style

`dart format` (default settings), `package:lints/recommended` plus the rules in `analysis_options.yaml`, strict casts, inference and raw types. Comments explain why, in plain sentences.
