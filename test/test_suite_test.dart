import 'package:livr/livr.dart';
import 'package:test/test.dart';

import 'support/test_suite.dart';

// Runs the LIVR test suite (a copy of LIVR/test_suite). Maps are compared
// ignoring the order of keys, and values by type: '1' does not equal 1, while
// 10 equals 10.0, as in Dart
void main() {
  for (final suite in ['positive', 'aliases_positive']) {
    group(suite, () {
      for (final suiteCase in loadSuite(suite)) {
        test(suiteCase.name, () {
          final result = _validator(suiteCase).validate(suiteCase.input);

          expect(result, isA<ValidationSuccess<Map<String, Object?>>>());
          expect((result as ValidationSuccess<Map<String, Object?>>).output,
              suiteCase.expected);
        });
      }
    });
  }

  for (final suite in ['negative', 'aliases_negative']) {
    group(suite, () {
      for (final suiteCase in loadSuite(suite)) {
        test(suiteCase.name, () {
          final result = _validator(suiteCase).validate(suiteCase.input);

          expect(result, isA<ValidationFailure>());
          expect((result as ValidationFailure).errors, suiteCase.expected);
        });
      }
    });
  }
}

Validator<Map<String, Object?>> _validator(SuiteCase suiteCase) =>
    Validator.untyped(
      suiteCase.rules,
      aliases: suiteCase.aliases
          ?.map((alias) => LivrAlias.fromJson(alias as Map<String, Object?>)),
    );
