## 0.2.2 - 2026-11-08

- Security fix in `url`.
- `url` rejects a dot after the host (`https://example.com.`), host labels longer than 63 characters and ports above 65535, and accepts one-digit ports (`https://example.com:8`), as LIVR 2.5 specifies now. Unicode hosts, `localhost` and IPv4 addresses pass as before.

## 0.2.1 - 2026-11-07

- Docs: LIVR 2.5 is released, not a draft.

## 0.2.0 - 2026-11-07

- The rules added in LIVR 2.5: `boolean`, `not_one_of`, `max_decimals`, `digits`, `starts_with`, `ends_with`, `contains`, `iso_date` with `min` and `max`, `iso_datetime`, `iso_time`, `required_if`, `when`, `values`, `keys`, `any`, `list_length`, `unique`, `split`, `uuid`, `ip`, `cidr`, `hostname`, `base64`, `hex`, `digest`, `mongo_id`, `hex_color`, `mac`, `e164`, `semver`, `jwt`, `luhn`, `credit_card`, `iban`. A wrong argument of these rules, also `{"rule": null}`, throws `LivrSchemaException`.
- The `now` argument of `Validator` and `Validator.untyped` fixes the current time of the bounds `today`, `yesterday` and `tomorrow`, for tests; `context.clock` gives it to custom rules.
- `parseReference()` in `package:livr/util.dart` reads a field or a path of the object, as `required_if` and `when` do.
- Changed (2.0 details fixed by LIVR 2.5): aliases and `or` are transparent, so `equal_to_field` in them compares with a sibling of the field; in an element of `list_of` every other field is missing (the element was a field named `field`). `iso_date` throws `LivrSchemaException` for a first argument that is not an options object (`{"iso_date": "today"}`), which 2.0 ignored; `{"iso_date": null}` is still the plain `iso_date`.
- Passes the test suite of LIVR 2.5 and the new cases of the 2.0 suite.

## 0.1.0

- First version: all rules of LIVR 2.0, aliases, custom rules and metarules, camelCase rule names, `autoTrim`.
- Typed by default: `Validator(schema, User.new)` returns `ValidationResult<User>`, with an extension type over the output map or a model class (`User.fromJson`); `Validator.untyped(schema)` returns the output as a map; `result.map(convert)` converts one result.
- Passes the LIVR test suite on the Dart VM, AOT and the web.
