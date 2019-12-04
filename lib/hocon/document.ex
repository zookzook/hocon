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
    %Document{root: put_path(root, path, value, [])}
  end

  defp put_path(root, [key], nil, _visited) do
    with {_, result} <- Map.pop(root, key) do
      result
    end
  end
  defp put_path(root, [key], value, visited) do
    case Map.get(root, key) do
      nil   -> Map.put(root, key, value)
      other ->
        # Here we need to check for self references.
        # In this case we have to look forward for the current value.
        abs_path = Enum.reverse([key|visited]) |> Enum.join(".")
        value    = resolve_possible_self_references(root, abs_path, value)
        merge(root, key, other, value)
    end
  end
  defp put_path(root, [head|tail], value, visited) do
    Map.put(root, head, put_path(Map.get(root, head, %{}), tail, value, [head|visited]))
  end

  ##
  # Resolving the current value in cases of self references.
  # abs_path: the current absolute key path is used to identify a self reference substitution
  #
  ##
  defp resolve_possible_self_references(root, abs_path, {:unquoted_string, value}) do
    case find_substitutions(value) do
       []      -> value               # case: no subsitutions
       [found] when found == value -> # case: exact one substitution
         {:ok, value} = resolve_possible_self_reference(root, abs_path, found)
         value

       found ->                       # case: multiple substitution within a string like "${foo} ${bar}"
         value = found
         |> Enum.map(fn subs -> {subs, resolve_possible_self_reference(root, abs_path, subs)} end)
         |> Enum.filter(fn {key, {:ok, value}} -> was_resolved(key, value) end) # only replaces what we have found
         |> Enum.reduce(value, fn {key, {:ok, value}}, result -> String.replace(result, key, value |> fetch_value() |> to_string()) end)
         {:unquoted_string, value}
    end
  end
  defp resolve_possible_self_references(_root, _abs_path, value)  do
    value
  end

  defp was_resolved(key, {:unquoted_string, value}), do: value != key
  defp was_resolved(_, _), do: true

  defp fetch_value({:unquoted_string, value}), do: value
  defp fetch_value(value), do: value

  defp resolve_possible_self_reference(root, abs_path, subs) do
    subs_path = get_path(subs)
    case String.starts_with?(subs_path, abs_path) do# is this a good idea?
      false -> {:ok, {:unquoted_string, subs}} # case: not self reference - keep it unmodified
      true  -> get_raw(root, subs_path)        # case: self reference - get current value
    end
  end

  defp find_substitutions(value) do
    Regex.scan(~r/\$\{.*?\}/, value)
    |> Enum.map(fn [subs] -> subs end)
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
    convert_map(this, this, [], opts)
  end

  defp convert_map(original, current, visited, opts) do
    Map.to_list(current)
    |> Enum.map(fn {key, value} -> convert_numerically_indexed(key, value, opts) end)
    |> Enum.map(fn
      {key, {:unquoted_string, value}} -> replace_all_substitutions(original, key, value, visited)
       other                           -> other
    end)
    |> Enum.map(fn {key, value} -> convert_nested_maps(original, key, value, push_key(key, visited), opts) end)
    |> Enum.map(fn {key, value} -> resolve_unquoted_strings_in_arrays(original, key, value, visited) end)
    |> Enum.into(%{})
  end

  defp resolve_unquoted_strings_in_arrays(original, key, value, visited) when is_list(value) do
    value = Enum.map(value, fn
      {:unquoted_string, subs} -> with {_, value} <- replace_all_substitutions(original, key, subs, visited) do
                                    value
                                  end
      other -> other
    end)
    {key, value}
  end
  defp resolve_unquoted_strings_in_arrays(_original, key, value, _visited) do
    {key, value}
  end

  defp convert_nested_maps(original, key, value, visited, opts) when is_map(value) do
    {key, convert_map(original, value, visited, opts)}
  end
  defp convert_nested_maps(_original, key, value, _visited, _opts) do
    {key, value}
  end

  def push_key(key, []) do
    [key]
  end
  def push_key(key, [head|_] = stack) do
    [head <> "." <> key|stack]
  end

  defp replace_all_substitutions(original, key, value, visited) do
    with {:ok, value} <- resolve_substitutions(original, value, visited) do
      {key, value}
    end
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

  defp get(root, keypath, visited) when is_binary(keypath) do
    keypath = keypath
          |> String.split(".")
          |> Enum.map(fn str -> String.trim(str) end)
    get(root, root, keypath, visited)
  end

  defp get(root, {:unquoted_string, value}, [], visited) do
    resolve_substitutions(root, value, visited)
  end

  defp get(_root, nil, keypath, visited) do
    {:not_found, (Enum.reverse(visited) ++ keypath) |> Enum.join(".")}
  end

  defp get(_root, value, [], _visited) do
    {:ok, value}
  end

  defp get(root, object, [key|rest], visited) when is_map(object) do
    get(root, Map.get(object, key), rest, push_key(key, visited))
  end

  defp get_raw(root, keypath, visited \\ []) when is_binary(keypath) do
    keypath = keypath
              |> String.split(".")
              |> Enum.map(fn str -> String.trim(str) end)
    get_raw(root, root, keypath, visited)
  end

  defp get_raw(_root, nil, keypath, visited) do
    {:not_found, (Enum.reverse(visited) ++ keypath) |> Enum.join(".")}
  end

  defp get_raw(_root, value, [], _visited) do
    {:ok, value}
  end

  defp get_raw(root, object, [key|rest], visited) when is_map(object) do
    get_raw(root, Map.get(object, key), rest, push_key(key, visited))
  end

  ##
  # resolve the substitutions in the `value` one after the other
  ##
  defp resolve_substitutions(root, value, visited) do

    with [substituions] <- Regex.run(~r/\$\{.*?\}/, value),
         path <- get_path(substituions),
          :ok <- check_circle(path, visited),
         {:ok, new_value} <- get(root, path, visited) do

      case value == substituions do
         true  -> {:ok, new_value}  ## Single substitution: ${foo} == ${foo}
         false ->                   ## Multiple substitutions within a string: ${foo} ${bar} == ${foo}
           value = String.replace(value, substituions, to_string(new_value))
           resolve_substitutions(root, value, visited)
      end
    else
      nil                      -> {:ok, value}
      {:not_found, path}       -> throw {:not_found, path}
      {:circle_detected, path} -> throw {:circle_detected, path}
    end

  end

  ##
  # Checks for circles.
  # Example:
  #
  # bar : ${foo}
  # foo : ${bar}
  #
  # creates a visited path list:
  # ["foo.bar", "foo"]
  #
  # in case of resolving ${foo} again, we found this path in the visited path list:
  # ["foo.bar", "foo"]
  #
  # and this is a circle
  ##
  defp check_circle(_path, []) do
    :ok
  end
  defp check_circle(path, visited) do
    visited = visited |> Enum.reverse() |> Enum.any?(fn visiting -> path == visiting end)
    case visited do
      false -> :ok
      true  -> {:circle_detected, path}
    end
  end

  ##
  # transform `${key.path}` to `key.path`
  ##
  defp get_path(substituions) do
    String.slice(substituions, 2, String.length(substituions) - 3)
  end

end