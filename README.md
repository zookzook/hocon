# hocon
Parse [HOCON](https://github.com/lightbend/config/blob/master/HOCON.md) configuration files in Elixir following the HOCON specifications.

[![Build Status](https://travis-ci.org/zookzook/hocon.svg?branch=master)](https://travis-ci.org/zookzook/hocon)
[![Coverage Status](https://coveralls.io/repos/github/zookzook/hocon/badge.svg?branch=master)](https://coveralls.io/github/zookzook/hocon?branch=master)
[![Hex.pm](https://img.shields.io/hexpm/v/hocon.svg)](https://hex.pm/packages/hocon)
[![Hex.pm](https://img.shields.io/hexpm/dt/hocon.svg)](https://hex.pm/packages/hocon)
[![Hex.pm](https://img.shields.io/hexpm/dw/hocon.svg)](https://hex.pm/packages/hocon)
[![Hex.pm](https://img.shields.io/hexpm/dd/hocon.svg)](https://hex.pm/packages/hocon)

## Basic usage

Assume the file `my-configuration.conf` exists and has the following content:
```hocon
{
  home : /path/to/home
  timeout : 300
  logger {
    level = "DEBUG"
  }
}
```

Then you can read and parse the HOCON-Configuration file:

```elixir

    {:ok, body} = File.read("my-configuration.conf")
    result = Parser.decode(body)

    IO.puts inspect result

    {:ok, %{"home" => "path/to/home", "logger" => %{"level" => "DEBUG"}, "timeout" => 300}}   

```

## Under development

Currently it is still being developed until all features of the specification are completed. 
That means the API may change from version to version.

## Spec Coverage

https://github.com/lightbend/config/blob/master/HOCON.md

- [ ] parsing JSON
- [x] comments
- [x] omit root braces
- [x] key-value separator
- [x] commas are optional if newline is present
- [x] whitespace
- [x] duplicate keys and object merging
- [x] unquoted strings
- [x] multi-line strings
- [x] value concatenation
- [x] object concatenation
- [x] array concatenation
- [x] path expressions
- [x] path as keys
- [ ] substitutions
- [ ] includes
- [x] conversion of numerically-indexed objects to arrays
- [ ] allow URL for included files
- [ ] duration unit format
- [ ] period unit format
- [ ] size unit format