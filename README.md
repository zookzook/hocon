# hocon
Parse [HOCON](https://github.com/lightbend/config/blob/master/HOCON.md) configuration files in Elixir following the HOCON specifications.

[![Build Status](https://travis-ci.org/zookzook/hocon.svg?branch=master)](https://travis-ci.org/zookzook/hocon)
[![Coverage Status](https://coveralls.io/repos/github/zookzook/hocon/badge.svg?branch=master)](https://coveralls.io/github/zookzook/hocon?branch=master)
[![codebeat badge](https://codebeat.co/badges/9b57f8e9-09b2-487d-8432-b00b1a13a47a)](https://codebeat.co/projects/github-com-zookzook-hocon-master)
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
    result = Hocon.decode(body)

    IO.puts inspect result

    {:ok, %{"home" => "path/to/home", "logger" => %{"level" => "DEBUG"}, "timeout" => 300}}   

```

The HOCON configuration is very powerfull and has a lot of nice features

```hocon
{
  // you can use comments
  
  # you can concat arrays like this
  dirs += ${PWD}
  dirs += /working-folder
  
  # you can concat strings like this
  path : ${PWD}
  path : ${path}"/working-folder"
  
  # Here are several ways to define `a` to the same array value:
  // one array
  a : [ 1, 2, 3, 4 ]
  // two arrays that are concatenated
  a : [ 1, 2 ] [ 3, 4 ]
  // with self-referential substitutions
  a : [ 1, 2 ]
  a : ${a} [ 3, 4 ]
 
  # some nested objects:
  foo { bar { baz : 42 } }
  
  # you can build values with substitutions
  foo : { a : { c : 1 } }
  foo : ${foo.a}
  foo : { a : 2 }
}
```

After parsing you get this map as result (where PWD=/Users/micha/projects/elixir/hocon):

```elixir

  %{
    "dirs" => ["/Users/micha/projects/elixir/hocon", "working-folder"],
    "path" => "/Users/micha/projects/elixir/hocon/working-folder"},
    "a" => [1, 2, 3, 4], 
    "foo" => %{"a" => 2, "bar" => %{"baz" => 42}, "c" => 1} 
  }

```

## Spec Coverage

https://github.com/lightbend/config/blob/master/HOCON.md

- [x] parsing JSON
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
- [x] substitutions
- [ ] includes
- [x] conversion of numerically-indexed objects to arrays
- [ ] allow URL for included files
- [x] duration unit format
- [x] period unit format
- [x] size unit format