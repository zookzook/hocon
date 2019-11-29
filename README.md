# hocon
Parse HOCON configuration files in Elixir following the HOCON specifications.

[![Build Status](https://travis-ci.org/zookzook/hocon.svg?branch=master)](https://travis-ci.org/zookzook/hocon)
[![Hex.pm](https://img.shields.io/hexpm/v/hocon.svg)](https://hex.pm/packages/hocon)
[![Hex.pm](https://img.shields.io/hexpm/dt/hocon.svg)](https://hex.pm/packages/hocon)
[![Hex.pm](https://img.shields.io/hexpm/dw/hocon.svg)](https://hex.pm/packages/hocon)
[![Hex.pm](https://img.shields.io/hexpm/dd/hocon.svg)](https://hex.pm/packages/hocon)
[![Coverage Status](https://coveralls.io/repos/github/zookzook/hocon/badge.svg?branch=master)](https://coveralls.io/github/zookzook/hocon?branch=master)

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