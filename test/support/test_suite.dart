import 'dart:convert';
import 'dart:io';

/// A case of the LIVR test suite: a directory with rules.json, input.json and
/// output.json or errors.json, plus aliases.json in the alias suites.
final class SuiteCase {
  SuiteCase(this.name, this.rules, this.input, this.expected, this.aliases);

  final String name;
  final Map<String, Object?> rules;
  final Object? input;

  /// output.json for positive cases, errors.json for negative ones
  final Object? expected;
  final List<Object?>? aliases;
}

const String testSuiteDir = 'test/test_suite';

List<SuiteCase> loadSuite(String suite) {
  final dir = Directory('$testSuiteDir/$suite');
  final caseDirs = dir.listSync().whereType<Directory>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  return [
    for (final caseDir in caseDirs)
      SuiteCase(
        caseDir.uri.pathSegments.lastWhere((s) => s.isNotEmpty),
        _readJson(caseDir, 'rules') as Map<String, Object?>,
        _readJson(caseDir, 'input'),
        _readJson(caseDir, 'output') ?? _readJson(caseDir, 'errors'),
        _readJson(caseDir, 'aliases') as List<Object?>?,
      ),
  ];
}

Object? _readJson(Directory dir, String name) {
  final file = File('${dir.path}/$name.json');
  if (!file.existsSync()) return null;
  return jsonDecode(file.readAsStringSync());
}
