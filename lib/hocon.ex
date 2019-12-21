defmodule Hocon do
  @moduledoc"""

  This module pareses and decodes a [hocon](https://github.com/lightbend/config/blob/master/HOCON.md) configuration string.

  ## Example

      iex(1)> conf = ~s(animal { favorite : "dog" }, key : \"\"\"${animal.favorite} is my favorite animal\"\"\")
      iex(2)> Hocon.decode(conf)
      {:ok,
      %{"animal" => %{"favorite" => "dog"}, "key" => "dog is my favorite animal"}}

  ## Units format

  The parser returns a map, because in Elixir it is a common use case to use pattern matching on maps to
  extract specific values and keys. Therefore the `Hocon.decode/2` function returns a map. To support
  interpreting a value with some family of units, you can call some conversion functions like `as_bytes/1`.

  ## Example

       iex> conf = ~s(limit : "512KB")
       iex> {:ok, %{"limit" => limit}} = Hocon.decode(conf)
       iex> Hocon.as_bytes(limit)
       524288

  It is possible to access the unit formats by a keypath, as well:
  ## Example

       iex> conf = ~s(a { b { c { limit : "512KB" } } })
       iex> {:ok, map} = Hocon.decode(conf)
       iex> Hocon.get_bytes(map, "a.b.c.limit")
       524288
       iex> Hocon.get_size(map, "a.b.c.limit")
       512000

  ## Include

  HOCON supports including of other configuration files. The default implmentation uses the file systems, which
  seems to be the most known use case. For other use cases you can implement the `Hocon.Resolver` behaviour and
  call the `decode/2` function with `file_resolver: MyResolver` as an option.

  ## Example

  The file `include-1.conf` exists and has the following content:

      { x : 10, y : ${a.x} }

  In the case we use the `Hocon.FileResolver` (which is the default as well):

      iex> conf = ~s({ a : { include "./test/data/include-1" } })
      iex> Hocon.decode(conf, file_resolver: Hocon.FileResolver)
      {:ok, %{"a" => %{"x" => 10, "y" => 10}}}

  To minimize the dependencies of other packages, you need to include the `HoconUrlResolver` if you want to load
  configuration from the internet:

      def deps do
      [
        {:hocon_url_resolver, "~> 0.1.0"}
      ]
      end

  or just implement a resolver like:

  ## URL-Resolver with HTTPoison

        defmodule HoconUrlResolver do
        @behaviour Hocon.Resolver

        @spec exists?(Path.t()) :: boolean
        def exists?(url) do
          case HTTPoison.head(url) do
            {:ok, %HTTPoison.Response{status_code: 200}} -> true
            {:ok, %HTTPoison.Response{status_code: 404}} -> false
            {:error, _}                                  -> false
          end
        end

        def load(url) do
          case HTTPoison.get(url) do
            {:ok, %HTTPoison.Response{status_code: 200, body: body}} -> {:ok, body}
            {:ok, %HTTPoison.Response{status_code: 404}}             -> {:error, "not found"}
            {:error, %HTTPoison.Error{reason: reason}}               -> {:error, reason}
          end
        end

      end
  """

  alias Hocon.Parser
  alias Hocon.Period

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

  ## time units, the base is millisconds
  @ns 0.000001
  @us 0.001
  @ms 1
  @s @ms * 1000
  @m @s * 60
  @h @m * 60
  @d @h * 24

  @doc"""

  Parses and decodes a hocon string and returns a map

  ## options

    * `:convert_numerically_indexed` - if set to true then numerically-indexed objects are converted to arrays
    * `:strict_conversion` - if set to `true` then numerically-indexed objects are only converted to arrays
       if all keys are numbers
    * `:file_resolver` - set to the module, which is responsible for loading the file resources. The default is `Hocon.FileResolver`
    * `:url_resolver` - set to the module, which is responsible for loading the url resources. The default is `Hocon.FileResolver`

  ## Example

      iex> conf = ~s(animal { favorite : "dog" }, key : \"\"\"${animal.favorite} is my favorite animal\"\"\")
      iex> Hocon.decode(conf)
      {:ok,
      %{"animal" => %{"favorite" => "dog"}, "key" => "dog is my favorite animal"}}

  ## Runtime-Configuration with HOCON

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
      iex> Hocon.get_size(conf, "a.b.c")
      10000
      iex> Hocon.get_size(conf, "a.b.d")
      nil
      iex> Hocon.get_size(conf, "a.b.d", 1000)
      1000
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
  Same a `get/3` but the value is interpreted like a duration format in milliseconds.

  ## Example
      iex> conf = Hocon.decode!(~s(a { b { c : "30s" } }))
      %{"a" => %{"b" => %{"c" => "30s"}}}
      iex> Hocon.get_milliseconds(conf, "a.b.c")
      30000
      iex> Hocon.get_milliseconds(conf, "a.b.d")
      nil
      iex> Hocon.get_milliseconds(conf, "a.b.d", 1000)
      1000
  """
  def get_milliseconds(root, keypath, default \\ nil) do
    keypath = keypath
              |> String.split(".")
              |> Enum.map(fn str -> String.trim(str) end)
    case get_in(root, keypath) do
      nil -> default
      other -> as_milliseconds(other)
    end
  end

  @doc """
  Same a `get/3` but the value is interpreted like a duration format in `Hocon.Period`.

  ## Example
      iex> conf = Hocon.decode!(~s(a { b { c : "3 weeks" } }))
      %{"a" => %{"b" => %{"c" => "30s"}}}
      iex> Hocon.get_period(conf, "a.b.c")
      %Hocon.Period{days: 21, months: 0, years: 0}
      iex> Hocon.get_period(conf, "a.b.d")
      nil
      iex> Hocon.get_period(conf, "a.b.d", 7)
      7
  """
  def get_period(root, keypath, default \\ nil) do
    keypath = keypath
              |> String.split(".")
              |> Enum.map(fn str -> String.trim(str) end)
    case get_in(root, keypath) do
      nil -> default
      other -> as_period(other)
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

  @doc """
  Returns the time of the `string` as milliseconds.

  ## Example
      iex> Hocon.as_milliseconds("30s")
      30000
      iex> Hocon.as_milliseconds("10us")
      0.01
  """
  def as_milliseconds(value) when is_number(value), do: value
  def as_milliseconds(string) when is_binary(string) do
    as_milliseconds(Regex.named_captures(~r/(?<value>\d+)(\W)?(?<unit>[[:alpha:]]+)?/, String.downcase(string)))
  end
  def as_milliseconds(%{"unit" => "", "value" => value}), do: parse_integer(value, 1)
  def as_milliseconds(%{"unit" => unit, "value" => value}) when unit in ~w(ns nano nanos nanosecond nanoseconds), do: parse_integer(value, @ns)
  def as_milliseconds(%{"unit" => unit, "value" => value}) when unit in ~w(us micro micros microsecond microseconds), do: parse_integer(value, @us)
  def as_milliseconds(%{"unit" => unit, "value" => value}) when unit in ~w(ms milli millis millisecond millisecond), do: parse_integer(value, @ms)
  def as_milliseconds(%{"unit" => unit, "value" => value}) when unit in ~w(s second seconds), do: parse_integer(value, @s)
  def as_milliseconds(%{"unit" => unit, "value" => value}) when unit in ~w(m minute minutes), do: parse_integer(value, @m)
  def as_milliseconds(%{"unit" => unit, "value" => value}) when unit in ~w(h hour hours), do: parse_integer(value, @h)
  def as_milliseconds(%{"unit" => unit, "value" => value}) when unit in ~w(d day days), do: parse_integer(value, @d)

  @doc """
  Returns the duration of the `string` as `Hocon.Period`.

  ## Example
      iex> Hocon.as_period("3 weeks")
      %Hocon.Period{days: 21, months: 0, years: 0}
      iex> Hocon.as_period("14d")
      %Hocon.Period{days: 14, months: 0, years: 0}
  """
  def as_period(value) when is_number(value), do: Period.days(value)
  def as_period(string) when is_binary(string) do
    as_period(Regex.named_captures(~r/(?<value>\d+)(\W)?(?<unit>[[:alpha:]]+)?/, String.downcase(string)))
  end
  def as_period(%{"unit" => "", "value" => value}), do: value |> parse_integer() |> Period.days()
  def as_period(%{"unit" => unit, "value" => value}) when unit in ~w(d day days), do: value |> parse_integer() |> Period.days()
  def as_period(%{"unit" => unit, "value" => value}) when unit in ~w(w week weeks), do: value |> parse_integer() |> Period.weeks()
  def as_period(%{"unit" => unit, "value" => value}) when unit in ~w(m mo month months), do: value |> parse_integer() |> Period.months()
  def as_period(%{"unit" => unit, "value" => value}) when unit in ~w(y year years), do: value |> parse_integer() |> Period.years()

  defp parse_integer(string) do
    with {result, ""} <- Integer.parse(string) do
      result
    end
  end
  defp parse_integer(string, factor) do
    with {result, ""} <- Integer.parse(string) do
      result * factor
    end
  end

end
