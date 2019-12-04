defmodule Hocon do
  @moduledoc"""

  This module paresed and decodes a hocon configuration string.

  ## [specification](https://github.com/lightbend/config/blob/master/HOCON.md) coverages:

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

  ## Example

      iex(1)> conf = ~s(animal { favorite : "dog" }, key : \"\"\"${animal.favorite} is my favorite animal\"\"\")
      "animal { favorite : \\"dog\\" }, key : \\"\\"\\"${animal.favorite} is my favorite animal\\"\\"\\""
      iex(2)> Hocon.decode(conf)
      {:ok,
      %{"animal" => %{"favorite" => "dog"}, "key" => "dog is my favorite animal"}}

  """

  alias Hocon.Parser

  @doc"""

  Parses and decodes a hocon string and returns a map

  ## options

    * `:convert_numerically_indexed` - if set to true then numerically-indexed objects are converted to arrays
    * `:strict_conversion` - if set to `true` then numerically-indexed objects are only converted to arrays
       if all keys are numbers

  ## Example

      iex(1)> conf = ~s(animal { favorite : "dog" }, key : \"\"\"${animal.favorite} is my favorite animal\"\"\")
      "animal { favorite : \\"dog\\" }, key : \\"\\"\\"${animal.favorite} is my favorite animal\\"\\"\\""
      iex(2)> Hocon.decode(conf)
      {:ok,
      %{"animal" => %{"favorite" => "dog"}, "key" => "dog is my favorite animal"}}
  """
  def decode(string, opts \\ []) do
    Parser.decode(string, opts)
  end

end
