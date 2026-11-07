import 'dart:convert';
import 'dart:io';

/// A case of the LIVR test suite: a directory with rules.json, input.json and
/// output.json or errors.json, plus aliases.json in the alias suites and
/// options.json in some cases of the 2.5 suite. A case of schema_errors has
/// only rules.json and aliases.json.
final class SuiteCase {
  SuiteCase(
    this.name,
    this.rules,
    this.input,
    this.expected,
    this.aliases,
    this.options,
  );

  final String name;
  final Map<String, Object?> rules;
  final Object? input;

  /// output.json for positive cases, errors.json for negative ones
  final Object? expected;
  final List<Object?>? aliases;

  /// options.json: `{"now": "2026-10-18T12:00:00Z"}` fixes the current time
  final Map<String, Object?>? options;
}

/// The copy of LIVR/test_suite
const String testSuiteDir = 'test/test_suite';

/// The copy of LIVR/test_suite_2.5
const String testSuite25Dir = 'test/test_suite_2.5';

/// The cases of a suite in [dir], sorted by name. Files next to the cases,
/// like a README, are skipped.
List<SuiteCase> loadSuite(String suite, {String dir = testSuiteDir}) {
  final caseDirs =
      Directory('$dir/$suite').listSync().whereType<Directory>().toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  return [
    for (final caseDir in caseDirs)
      SuiteCase(
        caseDir.uri.pathSegments.lastWhere((s) => s.isNotEmpty),
        _readJson(caseDir, 'rules') as Map<String, Object?>,
        _readJson(caseDir, 'input'),
        _readJson(caseDir, 'output') ?? _readJson(caseDir, 'errors'),
        _readJson(caseDir, 'aliases') as List<Object?>?,
        _readJson(caseDir, 'options') as Map<String, Object?>?,
      ),
  ];
}

Object? _readJson(Directory dir, String name) {
  final file = File('${dir.path}/$name.json');
  if (!file.existsSync()) return null;
  return jsonDecode(file.readAsStringSync());
}
