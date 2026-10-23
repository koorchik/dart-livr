/// Validation with LIVR (Language Independent Validation Rules): rules are
/// plain data, see https://livr-spec.org.
library;

export 'src/rule.dart'
    show LivrRule, RuleBuilder, RuleResult, RuleContext, LivrSchemaException;
export 'src/rules/built_in_rules.dart' show builtInRules;
export 'src/validator.dart'
    show
        Validator,
        LivrAlias,
        ValidationResult,
        ValidationSuccess,
        ValidationFailure,
        LivrValidationException;
