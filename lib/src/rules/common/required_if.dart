import '../../rule.dart';
import '../../util.dart';

/// `required_if`: the value is required when other fields have the given
/// values: `{required_if: {'type': 'company', 'address/country': ['UA']}}`.
/// Keys are references to fields of the object (see [parseReference]),
/// values are primitive values or lists of them, compared as strings with
/// the input of the referenced fields. When all of them match, an empty
/// value is `REQUIRED`.
LivrRule requiredIf(List<Object?> args, RuleContext context) {
  // Arguments after the object are ignored
  final conditions = args.isEmpty ? null : args[0];
  if (conditions is! Map<Object?, Object?> || conditions.isEmpty) {
    throw LivrSchemaException(
      'Rule [required_if] expects an object of references to values, '
      'got [$conditions]',
    );
  }

  final references = <FieldReference>[];
  // Expected values as strings: a String for one value, a List<String> for
  // a list of them
  final expectedValues = <Object>[];
  conditions.forEach((reference, expected) {
    references.add(parseReference(reference, 'required_if'));
    // An empty list never matches, like ""
    if (expected is List && expected.isEmpty) {
      throw LivrSchemaException(
        'Rule [required_if] expects a non-empty list of values for '
        '[$reference]',
      );
    }
    expectedValues.add(
      expected is List
          ? List<String>.generate(
              expected.length,
              (i) => _expectedValue(expected[i], reference),
              growable: false,
            )
          : _expectedValue(expected, reference),
    );
  });
  final length = references.length;

  return (value, allValues) {
    if (!isNoValue(value)) return RuleResult.valid;

    // Required when every referenced input value is a non-empty primitive
    // value that matches
    for (var i = 0; i < length; i++) {
      final refValue = references[i](allValues);
      if (isNoValue(refValue) || !isPrimitive(refValue)) {
        return RuleResult.valid;
      }

      final strRefValue = livrToString(refValue);
      final expected = expectedValues[i];
      final isMatch = expected is String
          ? expected == strRefValue
          : (expected as List<String>).contains(strRefValue);
      if (!isMatch) return RuleResult.valid;
    }

    return RuleResult.error('REQUIRED');
  };
}

// An expected value as a string. '' is a schema error: an empty referenced
// value never matches
String _expectedValue(Object? value, Object? reference) {
  if (!isPrimitive(value) || value == '') {
    throw LivrSchemaException(
      'Rule [required_if] expects a primitive value other than "" or a list '
      'of them for [$reference], got [$value]',
    );
  }
  return livrToString(value);
}
