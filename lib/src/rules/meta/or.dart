import '../../rule.dart';

/// `or`: applies the sets of rules one after another until one of them
/// succeeds: `{or: ['email', 'positive_integer']}`. When all of them fail,
/// the error of the last one is returned.
LivrRule or(List<Object?> args, RuleContext context) {
  final ruleSets = List<LivrRule>.generate(
    args.length,
    (i) => context.compileField(args[i]),
    growable: false,
  );

  return (value, allValues) {
    var result = RuleResult.valid;

    // The sets are transparent: their rules see the object of the field, so
    // equal_to_field and references compare with its siblings
    for (var i = 0; i < ruleSets.length; i++) {
      result = ruleSets[i](value, allValues);
      if (!result.isError) return result;
    }

    // The error of the last set, or valid when there are no sets
    return result;
  };
}
