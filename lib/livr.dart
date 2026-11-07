/// Validation with LIVR (Language Independent Validation Rules): rules are
/// plain data, see https://livr-spec.org. Implements LIVR 2.0 and LIVR 2.5.
library;

export 'src/rule.dart'
    show
        LivrRule,
        RuleBuilder,
        RuleResult,
        RuleContext,
        RuleContextClock,
        LivrSchemaException;
export 'src/rules/built_in_rules.dart' show builtInRules;
export 'src/validator.dart'
    show
        Validator,
        LivrAlias,
        ValidationResult,
        ValidationSuccess,
        ValidationFailure,
        LivrValidationException;
