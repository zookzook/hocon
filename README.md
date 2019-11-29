# hocon
Parse HOCON configuration files in Elixir following the HOCON specifications.

## Spec Coverage

https://github.com/lightbend/config/blob/master/HOCON.md

- [ ] parsing JSON
- [x] comments
- [x] omit root braces
- [x] key-value separator
- [x] commas are optional if newline is present
- [x] whitespace
- [ ] duplicate keys and object merging
- [x] unquoted strings
- [ ] multi-line strings
- [x] value concatenation
- [ ] object concatenation
- [ ] array concatenation
- [x] path expressions
- [ ] path as keys
- [ ] substitutions
- [ ] includes
- [ ] conversion of numerically-indexed objects to arrays
- [ ] allow URL for included files
- [ ] duration unit format
- [ ] period unit format
- [ ] size unit format