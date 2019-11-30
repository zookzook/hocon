defmodule Hocon.Parser do

  alias Hocon.Tokenizer
  alias Hocon.Document

  @doc"""

  Parses and decodes a hocon string and returns a map

  ## options

    * `:convert_numerically_indexed` - if set to true then numerically-indexed objects are converted to arrays
    * `:strict_conversion` - if set to `true` then numerically-indexed objects are only converted to arrays
       if all keys are numbers

  """
  def decode(string, opts \\ []) do

    with {:ok, ast} <- Tokenizer.decode(string) do

      #IO.puts "Ast #{inspect ast}"
      #IO.puts "\n\nFixed ast #{inspect contact_rule(ast, [])}"

      with {[], result } <- ast
                            |> contact_rule([])
                            |> parse_root(),
                result   <- Document.convert(result) do
        {:ok, result}
      end
    end
  end

  def contact_rule([], result) do
    result
    |> Enum.map(fn
      {:unquoted_string, value} -> {:string, value}
      other                     -> other
    end)
    |> Enum.reverse()
  end
  def contact_rule([{:unquoted_string, simple_a}, :ws, {:unquoted_string, simple_b}|rest], result) do
    contact_rule([{:unquoted_string, simple_a <> " " <> simple_b} | rest], result)
  end
  def contact_rule([{:unquoted_string, simple_a}, :ws, int_b|rest], result) when is_number(int_b) do
    contact_rule([{:unquoted_string, simple_a <> " " <> to_string(int_b)} | rest], result)
  end
  def contact_rule([int_a, :ws, int_b|rest], result) when is_number(int_a) and is_number(int_b) do
    contact_rule([{:unquoted_string, to_string(int_a) <> " " <> to_string(int_b)} | rest], result)
  end
  def contact_rule([other|rest], result) do
    contact_rule(rest, [other | result])
  end

  def parse_root([:open_curly | rest]) do
    parse_object(rest, Document.new())
  end
  def parse_root(tokens) do
    parse_object(tokens, Document.new(), true)
  end

  def parse_value([]) do
    {[], nil}
  end
  def parse([:open_curly | rest]) do
    parse_object(rest, Document.new())
  end
  def parse([:open_square | rest]) do
    parse_array(rest, [])
  end
  def parse([{:string, str} | rest]) do
    {rest, str}
  end
  def parse([number | rest]) when is_number(number) do
    {rest, number}
  end
  def parse([true | rest]) do
    {rest, true}
  end
  def parse([false | rest]) do
    {rest, false}
  end
  def parse([nil | rest]) do
    {rest, nil}
  end

  defp parse_object(tokens, result, is_root \\ false)
  defp parse_object([], result, true) do
    {[], result}
  end
  defp parse_object([:close_curly | rest], result, false) do
    try_merge_object(rest, result)
  end
  defp parse_object([:comma | rest], result, root) do
    parse_object(rest, result, root)
  end
  defp parse_object([:nl | rest], result, root) do
    parse_object(rest, result, root)
  end
  defp parse_object([{:string, key}, :open_curly | rest], result, root) do
    {rest, value} = parse_object(rest, Document.new())
    parse_object(rest, Document.put(result, key, value), root)
  end
  defp parse_object([{:string, key}, :colon | rest], result, root) do
    {rest, value} = parse(rest)
    parse_object(rest, Document.put(result, key, value), root)
  end
  defp parse_object([key, :open_curly | rest], result, root) do
    {rest, value} = parse_object(rest, Document.new())
    parse_object(rest, Document.put(result, to_string(key), value), root)
  end
  defp parse_object([key, :colon | rest], result, root) do
    {rest, value} = parse(rest)
    parse_object(rest, Document.put(result, to_string(key), value), root)
  end

  def try_merge_object([:open_curly | rest] = tokens, result) do
    with {rest, other} <- parse_object(rest, Document.new()) do
         {rest, Document.merge(result, other)}
     end
  end
  def try_merge_object([:nl | rest], result) do
    {rest, result}
  end
  def try_merge_object(tokens, result) do
    {tokens, result}
  end

  defp parse_array([:close_square| rest], result) do
    try_concat_array(rest, Enum.reverse(result))
  end
  defp parse_array([:comma, :close_square | rest], result) do
    try_concat_array(rest, Enum.reverse(result))
  end
  defp parse_array([:comma | rest], result) do
    parse_array(rest, result)
  end
  defp parse_array([:nl, :close_square | rest], result) do
    try_concat_array(rest, Enum.reverse(result))
  end
  defp parse_array([:nl | rest], result) do
    parse_array(rest, result)
  end
  defp parse_array(value, result) do
    {rest, value} = parse(value)
    parse_array(rest, [value | result])
  end

  def try_concat_array([:open_square | rest] = tokens, result) do
    with {rest, other} <- parse_array(rest, []) do
      {rest, result ++ other}
    end
  end
  def try_concat_array([:nl | rest], result) do
    {rest, result}
  end
  def try_concat_array(tokens, result) do
    {tokens, result}
  end

end