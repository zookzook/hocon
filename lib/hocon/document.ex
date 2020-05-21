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

  def put(doc, key, value, tokens \\ [], opts \\ [])
  def put(doc, key, %Document{root: value}, tokens, opts) do
    put(doc, key, value, tokens, opts)
  end
  def put(%Document{root: root}, {:string, key}, value, tokens, opts) do
    {rest, root} = put_path(root, [key], value, [], tokens, opts)
    {rest, %Document{root: root}}
  end
  def put(%Document{root: root}, key, value, tokens, opts) do
   path = key
          |> String.split(".")
          |> Enum.map(fn str -> String.trim(str) end)
          |> Enum.filter(fn str -> str != nil end)

   {rest, root} = put_path(root, path, value, [], tokens, opts)
   {rest, %Document{root: root}}
  end

  defp put_path(root, [key], nil, _visited, tokens, _opts) do
    with {_, result} <- Map.pop(root, key) do
      {tokens, result}
    end
  end
  defp put_path(root, [key], value, visited, tokens, opts) do
    case Map.get(root, key) do
      nil   -> {tokens, Map.put(root, key, value)}
      other ->
        # Here we need to check for self references.
        # In this case we have to look forward for the current value.
        abs_path = Enum.reverse([key|visited]) |> Enum.join(".")
        value    = resolve_possible_self_references(root, abs_path, value)
        # If we have now a list, then check if another list follows. In this case we merging both arrays
        {tokens, value} = case is_list(value) do
           true  -> Hocon.Parser.try_concat_array(tokens, value, opts)
           false -> {tokens, value}
        end

        {tokens, merge(root, key, other, value)}
    end
  end
  defp put_path(root, [head|tail], value, visited, tokens, opts) do
    {rest, value} = put_path(Map.get(root, head, %{}), tail, value, [head|visited], tokens, opts)
    {rest, Map.put(root, head, value)}
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
    {kind, subs_path} = get_path(subs)
    case String.starts_with?(subs_path, abs_path) do                               # is this a good idea?
      false -> {:ok, {:unquoted_string, subs}}                                     # case: not self reference - keep it unmodified
      true  -> root |> get_raw(subs_path) |> resolve_optional_self_reference(kind) # case: self reference - get current value
    end
  end

  defp resolve_optional_self_reference({:ok, _} = result, _) do
    result
  end
  defp resolve_optional_self_reference({:not_found, _path} = result, :mandatory) do
    throw result
  end
  defp resolve_optional_self_reference({:not_found, _}, :optional) do
    {:ok, ""}
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
      {key, {:unquoted_string, value}} -> replace_all_substitutions(original, key, value, visited, opts)
       other                           -> other
    end)
    |> Enum.map(fn {key, value} -> convert_nested_maps(original, key, value, push_key(key, visited), opts) end)
    |> Enum.map(fn {key, value} -> resolve_unquoted_strings_in_arrays(original, key, value, visited, opts) end)
    |> Enum.into(%{})
  end

  defp resolve_unquoted_strings_in_arrays(original, key, value, visited, opts) when is_list(value) do
    value = Enum.map(value, fn
      {:unquoted_string, subs} -> with {_, value} <- replace_all_substitutions(original, key, subs, visited, opts) do
                                    value
                                  end
      other -> other
    end)
    {key, value}
  end
  defp resolve_unquoted_strings_in_arrays(_original, key, value, _visited, _opts) do
    {key, value}
  end

  defp convert_nested_maps(original, key, value, visited, opts) when is_map(value) do
    {key, convert_map(original, value, visited, opts)}
  end
  defp convert_nested_maps(original, key, xs, visited, opts) when is_list(xs) do
    {key, Enum.map(xs, fn
      %Document{root: value}   -> convert_map(original, value, visited, opts)
      value when is_map(value) -> convert_map(original, value, visited, opts)
      value -> value
    end)}
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

  defp replace_all_substitutions(original, key, value, visited, opts) do
    with {:ok, value} <- resolve_substitutions(original, value, visited, opts) do
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

  defp get(root, keypath, visited, opts) when is_binary(keypath) do
    keypath = keypath
          |> String.split(".")
          |> Enum.map(fn str -> String.trim(str) end)
    get(root, root, keypath, visited, opts)
  end

  defp get(root, {:unquoted_string, value}, [], visited, opts) do
    resolve_substitutions(root, value, visited, opts)
  end

  defp get(_root, nil, keypath, visited, _opts) do
    {:not_found, (Enum.reverse(visited) ++ keypath) |> Enum.join(".")}
  end

  defp get(_root, value, [], _visited, _opts) do
    {:ok, value}
  end

  defp get(root, object, [key|rest], visited, opts) when is_map(object) do
    get(root, Map.get(object, key), rest, push_key(key, visited), opts)
  end

  def get_raw(root, keypath, visited \\ []) when is_binary(keypath) do
    keypath = keypath
              |> String.split(".")
              |> Enum.map(fn str -> String.trim(str) end)
    get_raw(root, root, keypath, visited)
  end

  def get_raw(_root, nil, keypath, visited) do
    {:not_found, (Enum.reverse(visited) ++ keypath) |> Enum.join(".")}
  end

  def get_raw(_root, value, [], _visited) do
    {:ok, value}
  end

  def get_raw(root, object, [key|rest], visited) when is_map(object) do
    get_raw(root, Map.get(object, key), rest, push_key(key, visited))
  end

  ##
  # resolve the substitutions in the `value` one after the other
  ##
  defp resolve_substitutions(root, value, visited, opts) do

    with [substituions] <- Regex.run(~r/\$\{.*?\}/, value),   ## find first substitution string
         {kind, path} <- get_path(substituions),                      ## extracts content
         :ok <- check_circle(path, visited),                  ## check for circles
         {:ok, new_value} <- get_or_fetch_env(get(root, path, visited, opts), path, kind, opts) do ## fetch value or try to find an environment variable

        case value == substituions do
         true  -> {:ok, new_value}  ## Single substitution: ${foo} == ${foo}
         false ->                   ## Multiple substitutions within a string: ${foo} ${bar} == ${foo}
           value = String.replace(value, substituions, to_string(new_value))
           resolve_substitutions(root, value, visited, opts)
      end
    else
      nil                      -> {:ok, value}
      {:not_found, path}       -> throw {:not_found, path}
      {:circle_detected, path} -> throw {:circle_detected, path}
    end

  end

  defp get_or_fetch_env({:ok, _} = result, _path, _kind, _opts), do: result
  defp get_or_fetch_env({:not_found, _}, key, :mandatory, opts) do
    case System.fetch_env(key) do
      {:ok, result} -> {:ok, result}
        _           -> get_or_fetch_assign(key, :mandatory, Keyword.get(opts, :assigns))
    end
  end
  defp get_or_fetch_env({:not_found, _}, key, :optional, opts) do
    case System.fetch_env(key) do
      {:ok, result} -> {:ok, result}
      _             -> get_or_fetch_assign(key, :optional, Keyword.get(opts, :assigns))
    end
  end

  ## Looks for the key in the assigns map/keyword
  defp get_or_fetch_assign(key, :mandatory, assigns) when is_map(assigns) do
    case Map.fetch(assigns, key) do
      {:ok, result} -> {:ok, result}
      _             -> {:not_found, key}
    end
  end
  defp get_or_fetch_assign(key, :mandatory, _other) do
    {:not_found, key}
  end
  defp get_or_fetch_assign(key, :optional, assigns) when is_map(assigns) do
    case Map.fetch(assigns, key) do
      {:ok, result} -> {:ok, result}
      _             -> {:ok, ""}
    end
  end
  defp get_or_fetch_assign(_key, :optional, _other) do
    {:ok, ""}
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
  defp get_path(<<"${?", rest::bits>>) do
    {:optional, String.slice(rest, 0, String.length(rest) - 1)}
  end
  defp get_path(<<"${", rest::bits>>) do
    {:mandatory, String.slice(rest, 0, String.length(rest) - 1)}
  end
  # coveralls-ignore-start
  defp get_path(other) do
    throw {:unknown, other}
  end
  # coveralls-ignore-stop

end