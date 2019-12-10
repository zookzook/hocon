defmodule Hocon do
  @moduledoc"""

  This module paresed and decodes a [hocon](https://github.com/lightbend/config/blob/master/HOCON.md) configuration string.

  ## Example

      iex(1)> conf = ~s(animal { favorite : "dog" }, key : \"\"\"${animal.favorite} is my favorite animal\"\"\")
      "animal { favorite : \\"dog\\" }, key : \\"\\"\\"${animal.favorite} is my favorite animal\\"\\"\\""
      iex(2)> Hocon.decode(conf)
      {:ok,
      %{"animal" => %{"favorite" => "dog"}, "key" => "dog is my favorite animal"}}

  ## Units format

  The Parser returns a map, because in Elixir it is a common use case to use pattern matching on maps to
  extract specific values and keys. Therefore the `Hocon.decode/2` function returns a map. To support
  interpreting a value with some family of units, you can call some conversion functions like `as_bytes/1`.

  ## Example

       iex> conf = ~s(limit : "512KB")
       iex> {:ok, %{"limit" => limit}} = Hocon.decode(conf)
       iex> Hocon.as_bytes(limit)
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
    Parser.decode!(string, opts)
  end

  @doc """
  Returns a value for the `keypath` from a map or a successfull parse HOCON string.

  ## Example
      iex> conf = Hocon.decode!(~s(a { b { c : "10kb" } }))
      %{"a" => %{"b" => %{"c" => "10kb"}}}
      iex> Hocon.get(conf, "a.b.c")
      "10kb"
      iex> Hocon.get(conf, "a.b.d")
      nil
      iex> Hocon.get(conf, "a.b.d", "1kb")
      "1kb"
  """
  def get(root, keypath, default \\ nil) do
    keypath = keypath
              |> String.split(".")
              |> Enum.map(fn str -> String.trim(str) end)
    case get_in(root, keypath) do
       nil -> default
        other -> other
    end
  end

  @doc """
  Same a `get/3` but the value is interpreted like a number by using the power of 2.

  ## Example
      iex> conf = Hocon.decode!(~s(a { b { c : "10kb" } }))
      %{"a" => %{"b" => %{"c" => "10kb"}}}
      iex> Hocon.get_bytes(conf, "a.b.c")
      10240
      iex> Hocon.get_bytes(conf, "a.b.d")
      nil
      iex> Hocon.get_bytes(conf, "a.b.d", 1024)
      1024
  """
  def get_bytes(root, keypath, default \\ nil) do
    keypath = keypath
              |> String.split(".")
              |> Enum.map(fn str -> String.trim(str) end)
    case get_in(root, keypath) do
      nil -> default
      other -> as_bytes(other)
    end
  end

  @doc """
  Same a `get/3` but the value is interpreted like a number by using the power of 10.

  ## Example
      iex> conf = Hocon.decode!(~s(a { b { c : "10kb" } }))
      %{"a" => %{"b" => %{"c" => "10kb"}}}
      iex> Hocon.get_bytes(conf, "a.b.c")
      10240
      iex> Hocon.get_bytes(conf, "a.b.d")
      nil
      iex> Hocon.get_bytes(conf, "a.b.d", 1024)
      1024
  """
  def get_size(root, keypath, default \\ nil) do
    keypath = keypath
              |> String.split(".")
              |> Enum.map(fn str -> String.trim(str) end)
    case get_in(root, keypath) do
      nil -> default
      other -> as_size(other)
    end
  end

  @doc """
  Returns the size of the `string` by using the power of 2.

  ## Example
      iex> Hocon.as_bytes("512kb")
      524288
      iex> Hocon.as_bytes("125 gigabytes")
      134217728000
  """
  def as_bytes(value) when is_number(value), do: value
  def as_bytes(string) when is_binary(string) do
    as_bytes(Regex.named_captures(~r/(?<value>\d+)(\W)?(?<unit>[[:alpha:]]+)?/, String.downcase(string)))
  end
  def as_bytes(%{"unit" => "", "value" => value}), do: parse_integer(value, 1)
  def as_bytes(%{"unit" => unit, "value" => value}) when unit in ~w(b byte bytes), do: parse_integer(value, 1)
  def as_bytes(%{"unit" => unit, "value" => value}) when unit in ~w(k kb kilobyte kilobytes), do: parse_integer(value, @kb)
  def as_bytes(%{"unit" => unit, "value" => value}) when unit in ~w(m mb megabyte megabytes), do: parse_integer(value, @mb)
  def as_bytes(%{"unit" => unit, "value" => value}) when unit in ~w(g gb gigabyte gigabytes), do: parse_integer(value, @gb)
  def as_bytes(%{"unit" => unit, "value" => value}) when unit in ~w(t tb terabyte terabytes), do: parse_integer(value, @tb)
  def as_bytes(%{"unit" => unit, "value" => value}) when unit in ~w(p pb petabyte petabytes), do: parse_integer(value, @pb)
  def as_bytes(%{"unit" => unit, "value" => value}) when unit in ~w(e eb exabyte exabytes), do: parse_integer(value, @eb)
  def as_bytes(%{"unit" => unit, "value" => value}) when unit in ~w(z zb zettabyte zettabytes), do: parse_integer(value, @zb)
  def as_bytes(%{"unit" => unit, "value" => value}) when unit in ~w(y yb yottabyte yottabytes), do: parse_integer(value, @yb)

  @doc """
  Returns the size of the `string` by using the power of 10.

  ## Example
      iex> Hocon.as_size("512kb")
      512000
      iex> Hocon.as_size("125 gigabytes")
      125000000000
  """
  def as_size(value) when is_number(value), do: value
  def as_size(string) when is_binary(string) do
    as_size(Regex.named_captures(~r/(?<value>\d+)(\W)?(?<unit>[[:alpha:]]+)?/, String.downcase(string)))
  end
  def as_size(%{"unit" => "", "value" => value}), do: parse_integer(value, 1)
  def as_size(%{"unit" => unit, "value" => value}) when unit in ~w(b byte bytes), do: parse_integer(value, 1)
  def as_size(%{"unit" => unit, "value" => value}) when unit in ~w(k kb kilobyte kilobytes), do: parse_integer(value, @kb_10)
  def as_size(%{"unit" => unit, "value" => value}) when unit in ~w(m mb megabyte megabytes), do: parse_integer(value, @mb_10)
  def as_size(%{"unit" => unit, "value" => value}) when unit in ~w(g gb gigabyte gigabytes), do: parse_integer(value, @gb_10)
  def as_size(%{"unit" => unit, "value" => value}) when unit in ~w(t tb terabyte terabytes), do: parse_integer(value, @tb_10)
  def as_size(%{"unit" => unit, "value" => value}) when unit in ~w(p pb petabyte petabytes), do: parse_integer(value, @pb_10)
  def as_size(%{"unit" => unit, "value" => value}) when unit in ~w(e eb exabyte exabytes), do: parse_integer(value, @eb_10)
  def as_size(%{"unit" => unit, "value" => value}) when unit in ~w(z zb zettabyte zettabytes), do: parse_integer(value, @zb_10)
  def as_size(%{"unit" => unit, "value" => value}) when unit in ~w(y yb yottabyte yottabytes), do: parse_integer(value, @yb_10)

  defp parse_integer(string, factor) do
    with {result, ""} <- Integer.parse(string) do
      result * factor
    end
  end

end
