import 'dart:collection';

import '../../rule.dart';
import '../../util.dart';

// Up to this length, a scan over the strings is as fast as a map and cheaper
// to prepare, which matters when a validator is created for every validation
const int _maxListForScan = 16;

/// `one_of`: the value must be one of the arguments. Values are compared as
/// strings, and the output is the allowed value. Both the new syntax
/// `{one_of: ['a', 'b']}` and the old one `{one_of: [['a', 'b']]}` work.
LivrRule oneOf(List<Object?> args, RuleContext context) {
  final first = args.isEmpty ? null : args[0];
  // A copy, so changing the schema later does not change the validator
  final allowedValues = List<Object?>.of(
    args.length == 1 && first is List ? first : args,
    growable: false,
  );

  var isAllStrings = true;
  for (final allowedValue in allowedValues) {
    if (allowedValue is String) continue;
    isAllStrings = false;
    if (!isPrimitive(allowedValue)) {
      throw LivrSchemaException(
        'Rule [one_of] expects primitive values, got [$allowedValue]',
      );
    }
  }

  // Allowed values as strings, converted once
  final List<Object?> strAllowedValues = isAllStrings
      ? allowedValues
      : List<String>.generate(
          allowedValues.length,
          (i) => livrToString(allowedValues[i]),
          growable: false,
        );

  if (strAllowedValues.length <= _maxListForScan) {
    return (value, allValues) {
      if (isNoValue(value)) return RuleResult.valid;
      if (!isPrimitive(value)) return RuleResult.error('FORMAT_ERROR');

      final strValue = livrToString(value);
      for (var i = 0; i < strAllowedValues.length; i++) {
        if (strAllowedValues[i] == strValue) {
          return RuleResult.value(allowedValues[i]);
        }
      }

      return RuleResult.error('NOT_ALLOWED_VALUE');
    };
  }

  // The first occurrence wins, like in the scan
  final indexByStrValue = HashMap<String, int>();
  for (var i = 0; i < strAllowedValues.length; i++) {
    indexByStrValue.putIfAbsent(strAllowedValues[i] as String, () => i);
  }

  return (value, allValues) {
    if (isNoValue(value)) return RuleResult.valid;
    if (!isPrimitive(value)) return RuleResult.error('FORMAT_ERROR');

    final index = indexByStrValue[livrToString(value)];
    if (index == null) return RuleResult.error('NOT_ALLOWED_VALUE');

    return RuleResult.value(allowedValues[index]);
  };
}
