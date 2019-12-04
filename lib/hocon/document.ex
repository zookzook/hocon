defmodule Hocon.Document do
  @moduledoc """
  This module represents the necessary functions for the creation of the final configuration. The configuration
  is built up with `put/3` function and as the final step the `convert` function is called, which resolves the
  substitutions to its current values in the current configuration object.
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

  @doc """
  Converts the document into a map by
  * converting numerically indexed maps into arrays
  * resolving substitutions to it's values

  ## Example
      iex> doc = %Document{root: %{"employee" => %{"firstname" => "Michael", "lastname" => "Maier"}, "fullname" => "${employee.firstname} ${employee.lastname}"}}
      iex> Document.convert(doc)

      %{
        "employee" => %{"firstname" => "Michael", "lastname" => "Maier"},
        "fullname" => "Michael Maier"
      }
  """
  def convert(%Document{root: this}, opts \\ []) do
    convert_map(this, %{}, opts)
  end

  defp convert_map(original, result, opts) do
    Map.to_list(original)
    |> Enum.map(fn {key, value} -> convert_numerically_indexed(key, value, opts) end)
    |> Enum.map(fn {key, value} -> replace_all_substitutions(original, key, value) end)
    |> Enum.into(result)
  end

  defp replace_all_substitutions(original, key, value) when is_binary(value) do
    with {:ok, value} <- resolve_substitutions(original, value) do
      {key, value}
    end
  end
  defp replace_all_substitutions(_original, key, value) do
    {key, value}
  end

  defp convert_numerically_indexed(key, value, opts) when is_map(value) do

    case Keyword.get(opts, :convert_numerically_indexed, false) do
      true ->
        case convert_to_array(value, opts) do
          {:converted, array } -> {key, array}
          _                    -> {key, value}
        end
      false -> {key, value}
    end

  end
  defp convert_numerically_indexed(key, value, _opts) do
    {key, value}
  end
  defp convert_to_array(root, opts) do

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

  defp get(root, path) when is_binary(path) do
    path = path
          |> String.split(".")
          |> Enum.map(fn str -> String.trim(str) end)
    get(root, root, path, [])
  end

  defp get(root, value, [], _visited) when is_binary(value) do
    resolve_substitutions(root, value)
  end

  defp get(_root, nil, path, visited) do
    {:not_found, (Enum.reverse(visited) ++ path) |> Enum.join(".")}
  end

  defp get(_root, value, [], _visited) do
    {:ok, value}
  end

  defp get(root, object, [key|rest], visited) when is_map(object) do
    get(root, Map.get(object, key), rest, [key | visited])
  end

  ##
  # resolve the substitutions in the `value` one after the other
  ##
  defp resolve_substitutions(root, value) do

    with [substituions] <- Regex.run(~r/\$\{.*?\}/, value),
         path <- get_path(substituions),
         # :ok <- check_circle(path, visited),
         {:ok, new_value} <- get(root, path) do
      value = String.replace(value, substituions, to_string(new_value))
      resolve_substitutions(root, value)
    else
      nil                      -> {:ok, value}
      {:not_found, path}       -> throw {:not_found, path}
      # todo {:circle_detected, path} -> throw {:circle_detected, path}
    end

  end

  ##
  # transform `${key.path}` to `key.path`
  ##
  defp get_path(substituions) do
    String.slice(substituions, 2, String.length(substituions) - 3)
  end

end