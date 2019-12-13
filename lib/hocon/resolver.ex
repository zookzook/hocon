defmodule Hocon.Resolver do
  @moduledoc """
  This module is responsible for loading file configuration. The configuration is
  specified by a path (filepath, url).

  By implementing this behaviour you can pass the module by the `:resolver` keyword as an option.

  ## Example

      iex> conf = ~s({ a : { include required\("./test/data/include-3"\) } }
      iex> Hocon.decode(conf), resolver: Hocon.FileResolver)
      {:ok, %{"a" => %{"x" => 10, "y" => 10}}}
  """

  @doc """
  Returns `true` if the given path exists.
  """
  @callback exists?(Path.t()) :: boolean


  @doc """
  Returns `{:ok, binary}`, where `binary` is a binary data object that contains the contents
  of `path`, or `{:error, reason}` if an error occurs.
  """
  @callback load(Path.t()) :: {:ok, binary} | {:error, File.posix}
end

defmodule Hocon.FileResolver do
  @moduledoc """
  This module is responsible for loading file resources.

  By implementing the behaviour `Hocon.Resolver` it is possible to replace this module. For example to load the resource
  from a database or from an url.
  """

  @behaviour Hocon.Resolver

  @doc """
  Returns `true` if `resource` exists.

  ## Example
      iex> Hocon.FileResolver.exists?("app.conf")
      false
      iex> Hocon.FileResolver.exists?("./test/data/include-1.conf")
      true

  """
  @spec exists?(Path.t()) :: boolean
  def exists?(resource) do
    File.exists?(resource)
  end

  @doc """
  Returns a tuple with the content of the `resource`

  ## Example
      iex> Hocon.FileResolver.load("app.conf")
      {:error, :enoent}
      iex> Hocon.FileResolver.load("./test/data/include-1.conf")
      {:ok, "{ x : 10, y : ${a.x} }"}
  """
  @spec load(Path.t()) :: {:ok, binary} | {:error, File.posix}
  def load(resource) do
    File.read(resource)
  end

end
