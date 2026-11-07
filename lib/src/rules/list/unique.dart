import 'dart:collection';

import '../../rule.dart';
import '../../util.dart';

/// `unique`: the elements of the list must be unique. Without arguments the
/// elements are primitive values, compared as strings (`1` and `'1'` are
/// duplicates). With keys, `{unique: ['country', 'zip']}`, the elements are
/// objects, duplicates when the values of all the keys are equal. Empty
/// elements and objects with an empty key value are ignored. Duplicates are
/// one `NOT_UNIQUE_ITEMS` for the field, an element of a wrong type is
/// `FORMAT_ERROR`.
LivrRule unique(List<Object?> args, RuleContext context) {
  if (args.isEmpty) return _uniqueValues;

  // A number is its string form, a boolean is not a key name
  final keys = List<String>.generate(args.length, (i) {
    final key = args[i];
    if (key is! String && !(key is num && key.isFinite)) {
      throw LivrSchemaException('Rule [unique] expects key names, got [$key]');
    }
    return livrToString(key);
  }, growable: false);

  if (keys.length == 1) return _uniqueKey(keys[0]);
  return _uniqueKeys(keys);
}

// A type error wins over duplicates, wherever it is in the list
RuleResult _uniqueValues(Object? value, Map<Object?, Object?> allValues) {
  if (isNoValue(value)) return RuleResult.valid;
  if (value is! List) return RuleResult.error('FORMAT_ERROR');

  final seen = HashSet<String>();
  var hasDuplicates = false;
  for (final item in value) {
    if (isNoValue(item)) continue;
    if (!isPrimitive(item)) return RuleResult.error('FORMAT_ERROR');
    if (!seen.add(livrToString(item))) hasDuplicates = true;
  }

  return hasDuplicates
      ? RuleResult.error('NOT_UNIQUE_ITEMS')
      : RuleResult.valid;
}

LivrRule _uniqueKey(String key) {
  return (value, allValues) {
    if (isNoValue(value)) return RuleResult.valid;
    if (value is! List) return RuleResult.error('FORMAT_ERROR');

    final seen = HashSet<String>();
    var hasDuplicates = false;
    for (final item in value) {
      if (isNoValue(item)) continue;
      if (item is! Map) return RuleResult.error('FORMAT_ERROR');

      final keyValue = item[key];
      if (isNoValue(keyValue)) continue;
      if (!isPrimitive(keyValue)) return RuleResult.error('FORMAT_ERROR');
      if (!seen.add(livrToString(keyValue))) hasDuplicates = true;
    }

    return hasDuplicates
        ? RuleResult.error('NOT_UNIQUE_ITEMS')
        : RuleResult.valid;
  };
}

LivrRule _uniqueKeys(List<String> keys) {
  return (value, allValues) {
    if (isNoValue(value)) return RuleResult.valid;
    if (value is! List) return RuleResult.error('FORMAT_ERROR');

    final seen = HashSet<String>();
    final buffer = StringBuffer();
    var hasDuplicates = false;
    for (final item in value) {
      if (isNoValue(item)) continue;
      if (item is! Map) return RuleResult.error('FORMAT_ERROR');

      // An object with an empty key value is not compared, a key value of a
      // wrong type is an error
      var hasEmptyKeyValue = false;
      for (var i = 0; i < keys.length; i++) {
        final keyValue = item[keys[i]];
        if (isNoValue(keyValue)) {
          hasEmptyKeyValue = true;
        } else if (!isPrimitive(keyValue)) {
          return RuleResult.error('FORMAT_ERROR');
        }
      }
      if (hasEmptyKeyValue) continue;

      // The values with their lengths, so ['a,b', 'c'] and ['a', 'b,c'] differ
      buffer.clear();
      for (var i = 0; i < keys.length; i++) {
        final str = livrToString(item[keys[i]]);
        buffer
          ..write(str.length)
          ..write(':')
          ..write(str);
      }
      if (!seen.add(buffer.toString())) hasDuplicates = true;
    }

    return hasDuplicates
        ? RuleResult.error('NOT_UNIQUE_ITEMS')
        : RuleResult.valid;
  };
}
