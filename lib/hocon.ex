defmodule Hocon do
  @moduledoc"""

  This module paresed and decodes a hocon configuration string.

  ## [specification](https://github.com/lightbend/config/blob/master/HOCON.md) coverages:

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
  - [ ] duration unit format
  - [ ] period unit format
  - [x] size unit format


  ## Example

      iex(1)> conf = ~s(animal { favorite : "dog" }, key : \"\"\"${animal.favorite} is my favorite animal\"\"\")
      "animal { favorite : \\"dog\\" }, key : \\"\\"\\"${animal.favorite} is my favorite animal\\"\\"\\""
      iex(2)> Hocon.decode(conf)
      {:ok,
      %{"animal" => %{"favorite" => "dog"}, "key" => "dog is my favorite animal"}}

  ## Units format

  The Parser returns a map, because in Elixir it is a common use case to use pattern matching on maps to
  extract specific values and keys. Therefore the `Hocon.decode/2` function returns a map. To support
  interpreting a value with some family of units, you can call some conversion functions like `get_bytes/1`.

  ## Example

       iex> conf = ~s(limit : "512KB")
       iex> {:ok, %{"limit" => limit}} = Hocon.decode(conf)
       iex> Hocon.get_bytes(limit)
       524288

  """

  alias Hocon.Parser

  ## size units, power of 2
  @kb 1024
  @mb @kb * 1024
  @gb @mb * 1024
  @tb @gb * 1024
  @pb @tb * 1024
  @eb @pb * 1024
  @zb @eb * 1024
  @yb @zb * 1024

  ## size units, power of 10
  @kb_10 1000
  @mb_10 @kb_10 * 1000
  @gb_10 @mb_10 * 1000
  @tb_10 @gb_10 * 1000
  @pb_10 @tb_10 * 1000
  @eb_10 @pb_10 * 1000
  @zb_10 @eb_10 * 1000
  @yb_10 @zb_10 * 1000

  @doc"""

  Parses and decodes a hocon string and returns a map

  ## options

    * `:convert_numerically_indexed` - if set to true then numerically-indexed objects are converted to arrays
    * `:strict_conversion` - if set to `true` then numerically-indexed objects are only converted to arrays
       if all keys are numbers

  ## Example

      iex> conf = ~s(animal { favorite : "dog" }, key : \"\"\"${animal.favorite} is my favorite animal\"\"\")
      "animal { favorite : \\"dog\\" }, key : \\"\\"\\"${animal.favorite} is my favorite animal\\"\\"\\""
      iex> Hocon.decode(conf)
      {:ok,
      %{"animal" => %{"favorite" => "dog"}, "key" => "dog is my favorite animal"}}

  Use can use the HOCON-Parser as a `Config.Provider` to load configuration during boot:

      defmodule HOCONConfigProvider do
        @behaviour Config.Provider

        require Logger

        # Let's pass the path to the HOCON file as config
        def init(path) when is_binary(path), do: path

        def load(config, path) do
          # We need to start any app we may depend on.
          {:ok, _} = Application.ensure_all_started(:hocon)
          {:ok, _} = Application.ensure_all_started(:logger)

          Logger.info("Reading runtime config from \#{path}")

          conf = path |> File.read!() |> Hocon.decode!()

          runtime = [mailer_config(conf)] |> filter_nils()

          Config.Reader.merge(config, runtime)
        end

        defp mailer_config(%{"mailer" => %{"server" => server, "port" => port}}) do
          {JobsKliniken.Mailer, [server: server, port: port]}
        end
        defp mailer_config(%{}) do
          {JobsKliniken.Mailer, nil}
        end

        defp filter_nils(keyword) do
          Enum.reject(keyword, fn {_key, value} -> is_nil(value) end)
        end
      end

  """
  def decode(string, opts \\ []) do
    Parser.decode(string, opts)
  end

  @doc"""
  Similar to `decode/2` except it will unwrap the error tuple and raise
  in case of errors.
  """
  def decode!(string, opts \\ []) do
    with {:ok, result} <- Parser.decode(string, opts) do
      result
    end
  end


  @doc """
  Returns the size of the `string` by using the power of 2.

  ## Example
      iex> Hocon.get_bytes("512kb")
      524288
      iex> Hocon.get_bytes("125 gigabytes")
      134217728000
  """
  def get_bytes(value) when is_number(value), do: value
  def get_bytes(string) when is_binary(string) do
    get_bytes(Regex.named_captures(~r/(?<value>\d+)(\W)?(?<unit>[[:alpha:]]+)?/, String.downcase(string)))
  end
  def get_bytes(%{"unit" => "", "value" => value}), do: parse_integer(value, 1)
  def get_bytes(%{"unit" => unit, "value" => value}) when unit in ~w(b byte bytes), do: parse_integer(value, 1)
  def get_bytes(%{"unit" => unit, "value" => value}) when unit in ~w(k kb kilobyte kilobytes), do: parse_integer(value, @kb)
  def get_bytes(%{"unit" => unit, "value" => value}) when unit in ~w(m mb megabyte megabytes), do: parse_integer(value, @mb)
  def get_bytes(%{"unit" => unit, "value" => value}) when unit in ~w(g gb gigabyte gigabytes), do: parse_integer(value, @gb)
  def get_bytes(%{"unit" => unit, "value" => value}) when unit in ~w(t tb terabyte terabytes), do: parse_integer(value, @tb)
  def get_bytes(%{"unit" => unit, "value" => value}) when unit in ~w(p pb petabyte petabytes), do: parse_integer(value, @pb)
  def get_bytes(%{"unit" => unit, "value" => value}) when unit in ~w(e eb exabyte exabytes), do: parse_integer(value, @eb)
  def get_bytes(%{"unit" => unit, "value" => value}) when unit in ~w(z zb zettabyte zettabytes), do: parse_integer(value, @zb)
  def get_bytes(%{"unit" => unit, "value" => value}) when unit in ~w(y yb yottabyte yottabytes), do: parse_integer(value, @yb)

  @doc """
  Returns the size of the `string` by using the power of 10.

  ## Example
      iex> Hocon.get_size("512kb")
      512000
      iex> Hocon.get_size("125 gigabytes")
      125000000000
  """
  def get_size(value) when is_number(value), do: value
  def get_size(string) when is_binary(string) do
    get_size(Regex.named_captures(~r/(?<value>\d+)(\W)?(?<unit>[[:alpha:]]+)?/, String.downcase(string)))
  end
  def get_size(%{"unit" => "", "value" => value}), do: parse_integer(value, 1)
  def get_size(%{"unit" => unit, "value" => value}) when unit in ~w(b byte bytes), do: parse_integer(value, 1)
  def get_size(%{"unit" => unit, "value" => value}) when unit in ~w(k kb kilobyte kilobytes), do: parse_integer(value, @kb_10)
  def get_size(%{"unit" => unit, "value" => value}) when unit in ~w(m mb megabyte megabytes), do: parse_integer(value, @mb_10)
  def get_size(%{"unit" => unit, "value" => value}) when unit in ~w(g gb gigabyte gigabytes), do: parse_integer(value, @gb_10)
  def get_size(%{"unit" => unit, "value" => value}) when unit in ~w(t tb terabyte terabytes), do: parse_integer(value, @tb_10)
  def get_size(%{"unit" => unit, "value" => value}) when unit in ~w(p pb petabyte petabytes), do: parse_integer(value, @pb_10)
  def get_size(%{"unit" => unit, "value" => value}) when unit in ~w(e eb exabyte exabytes), do: parse_integer(value, @eb_10)
  def get_size(%{"unit" => unit, "value" => value}) when unit in ~w(z zb zettabyte zettabytes), do: parse_integer(value, @zb_10)
  def get_size(%{"unit" => unit, "value" => value}) when unit in ~w(y yb yottabyte yottabytes), do: parse_integer(value, @yb_10)

  defp parse_integer(string, factor) do
    with {result, ""} <- Integer.parse(string) do
      result * factor
    end
  end

end
