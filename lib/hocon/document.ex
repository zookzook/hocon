defmodule Hocon.Document do
  @moduledoc """

  """

  alias Hocon.Document

  defstruct root: %{}

  def new() do
    %Document{}
  end

  def put(doc, key, %Document{root: value}) do
    put(doc, key, value)
  end
  def put(%Document{root: root}, key, value) do
   path = key
          |> String.split(".")
          |> Enum.map(fn str -> String.trim(str) end)
          |> Enum.filter(fn str -> str != nil end)
    %Document{root: put_path(root, path, value)}
  end

  def put_path(root, [key], nil) do
    with {_, result} <- Map.pop(root, key) do
      result
    end
  end
  def put_path(root, [key], value) do
    case Map.get(root, key) do
      nil   -> Map.put(root, key, value)
      other -> merge(root, key, other, value)
    end
  end
  def put_path(root, [head|tail], value) do
    Map.put(root, head, put_path(Map.get(root, head, %{}), tail, value))
  end

  def merge(root, key, %{} = original, %{} = value) do
    Map.put(root, key, Map.merge(original, value))
  end
  def merge(root, key, _original, value) do
    Map.put(root, key, value)
  end

  def merge(%Document{root: this}, %Document{root: that}) do
    %Document{root: Map.merge(this, that)}
  end

  def convert(%Document{root: this}, opts \\ []) do
    convert_map(this, %{}, opts)
  end

  def convert_map(original, result, opts) do
    Map.to_list(original)
    |> Enum.map(fn {key, value} -> convert_numerically_indexed(key, value, opts) end)
    |> Enum.into(result)
  end

  def convert_numerically_indexed(key, value, opts) when is_map(value) do

    case Keyword.get(opts, :convert_numerically_indexed, false) do
      true ->
        case convert_to_array(value, opts) do
          {:converted, array } -> {key, array}
          _                    -> {key, value}
        end
      false -> {key, value}
    end

  end
  def convert_numerically_indexed(key, value, _opts) do
    {key, value}
  end
  def convert_to_array(root, opts) do

    is_strict = Keyword.get(opts, :strict_conversion, true)

    convertable = case is_strict do
      true  -> root
               |> Map.keys()
               |> Enum.all?(fn key -> String.match?(key, ~r/^\d$/) end)
      false -> root
               |> Map.keys()
               |> Enum.any?(fn key -> String.match?(key, ~r/^\d$/) end)
    end

    case convertable do
      true  -> {:converted, to_array(root)}
      false -> :not_converted
    end

  end

  defp to_array(map) do
    map
    |> Map.to_list()
    |> Enum.filter(fn {key, _} -> String.match?(key, ~r/^\d$/) end)
    |> Enum.map(fn {key, value} -> {String.to_integer(key), value} end)
    |> Enum.sort(fn a, b -> elem(a, 0) < elem(b, 0) end)
    |> Enum.map(fn {_,value} -> value end)
  end

end