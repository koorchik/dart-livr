import '../../rule.dart';
import '../../util.dart';

/// `like`: the value must match the regular expression. Flags are the
/// second argument: `{like: ['^[a-z]+$', 'i']}`; only `i` (ignore case) is
/// supported. The output is the value as a string.
LivrRule like(List<Object?> args, RuleContext context) {
  final pattern = stringArg(args, 0, 'like');
  final flags = args.length > 1 ? args[1] : null;
  final isIgnoreCase = flags is String && flags.contains('i');

  final re = _compile(pattern, isIgnoreCase);

  return (value, allValues) {
    if (isNoValue(value)) return RuleResult.valid;
    if (!isPrimitive(value)) return RuleResult.error('FORMAT_ERROR');

    final str = livrToString(value);
    if (!re.hasMatch(str)) return RuleResult.error('WRONG_FORMAT');

    return value is String ? RuleResult.valid : RuleResult.value(str);
  };
}

// Compiled regular expressions by pattern. A RegExp is immutable, so
// validators created for every validation share them instead of compiling
// the same pattern again
final Map<String, RegExp> _caseSensitiveCache = {};
final Map<String, RegExp> _ignoreCaseCache = {};
const int _maxCacheSize = 256;

RegExp _compile(String pattern, bool isIgnoreCase) {
  final cache = isIgnoreCase ? _ignoreCaseCache : _caseSensitiveCache;
  final cached = cache[pattern];
  if (cached != null) return cached;

  final RegExp re;
  try {
    re = RegExp(pattern, caseSensitive: !isIgnoreCase);
  } on FormatException catch (e) {
    throw LivrSchemaException(
      'Rule [like] got an invalid regular expression [$pattern]: ${e.message}',
    );
  }

  // Patterns built from data must not fill the memory
  if (cache.length >= _maxCacheSize) cache.remove(cache.keys.first);
  return cache[pattern] = re;
}
