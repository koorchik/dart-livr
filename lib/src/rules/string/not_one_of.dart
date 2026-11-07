import 'dart:collection';

import '../../rule.dart';
import '../../util.dart';

// Up to this length, a scan over the strings is as fast as a set and cheaper
// to prepare, which matters when a validator is created for every validation
const int _maxListForScan = 16;

/// `not_one_of`: the value must not be one of the arguments:
/// `{not_one_of: ['admin', 'root']}`. Values are compared as strings, so `1`
/// equals `'1'`. The output is the value unchanged.
LivrRule notOneOf(List<Object?> args, RuleContext context) {
  if (args.isEmpty) {
    throw const LivrSchemaException(
      'Rule [not_one_of] expects one or more values',
    );
  }

  // Forbidden values as strings, converted once
  final forbiddenValues = List<String>.generate(args.length, (i) {
    final arg = args[i];
    if (!isPrimitive(arg)) {
      throw LivrSchemaException(
        'Rule [not_one_of] expects primitive values, got [$arg]',
      );
    }
    return livrToString(arg);
  }, growable: false);

  if (forbiddenValues.length <= _maxListForScan) {
    return (value, allValues) {
      if (isNoValue(value)) return RuleResult.valid;
      if (!isPrimitive(value)) return RuleResult.error('FORMAT_ERROR');

      final strValue = livrToString(value);
      for (var i = 0; i < forbiddenValues.length; i++) {
        if (forbiddenValues[i] == strValue) {
          return RuleResult.error('NOT_ALLOWED_VALUE');
        }
      }
      return RuleResult.valid;
    };
  }

  final forbiddenSet = HashSet<String>.of(forbiddenValues);
  return (value, allValues) {
    if (isNoValue(value)) return RuleResult.valid;
    if (!isPrimitive(value)) return RuleResult.error('FORMAT_ERROR');

    return forbiddenSet.contains(livrToString(value))
        ? RuleResult.error('NOT_ALLOWED_VALUE')
        : RuleResult.valid;
  };
}
