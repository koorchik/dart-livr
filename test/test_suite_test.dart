// Reads the test suites from test/test_suite and test/test_suite_2.5 with
// dart:io
@TestOn('vm')
library;

import 'package:livr/livr.dart';
import 'package:test/test.dart';

import 'support/test_suite.dart';

// Runs the LIVR test suite (a copy of LIVR/test_suite) and the suite of the
// LIVR 2.5 (a copy of LIVR/test_suite_2.5). Maps are compared ignoring
// the order of keys, and values by type: '1' does not equal 1, while 10
// equals 10.0, as in Dart
void main() {
  for (final (version, dir) in [
    ('2.0', testSuiteDir),
    ('2.5', testSuite25Dir),
  ]) {
    group('LIVR $version', () {
      for (final suite in ['positive', 'aliases_positive']) {
        group(suite, () {
          for (final suiteCase in loadSuite(suite, dir: dir)) {
            test(suiteCase.name, () {
              final result = _validator(suiteCase).validate(suiteCase.input);

              expect(result, isA<ValidationSuccess<Map<String, Object?>>>());
              expect(
                (result as ValidationSuccess<Map<String, Object?>>).output,
                suiteCase.expected,
              );
            });
          }
        });
      }

      for (final suite in ['negative', 'aliases_negative']) {
        group(suite, () {
          for (final suiteCase in loadSuite(suite, dir: dir)) {
            test(suiteCase.name, () {
              final result = _validator(suiteCase).validate(suiteCase.input);

              expect(result, isA<ValidationFailure>());
              expect((result as ValidationFailure).errors, suiteCase.expected);
            });
          }
        });
      }
    });
  }

  // Schemas that must not build: the validator throws, with the aliases of
  // the case registered
  group('LIVR 2.5 schema_errors', () {
    for (final suiteCase in loadSuite('schema_errors', dir: testSuite25Dir)) {
      test(suiteCase.name, () {
        expect(
          () => _validator(suiteCase),
          throwsA(isA<LivrSchemaException>()),
        );
      });
    }
  });
}

Validator<Map<String, Object?>> _validator(SuiteCase suiteCase) {
  // options.json fixes the current time of iso_date and iso_datetime bounds
  final now = suiteCase.options?['now'] as String?;
  final fixedNow = now == null ? null : DateTime.parse(now);

  return Validator.untyped(
    suiteCase.rules,
    aliases: suiteCase.aliases?.map(
      (alias) => LivrAlias.fromJson(alias as Map<String, Object?>),
    ),
    now: fixedNow == null ? null : () => fixedNow,
  );
}
