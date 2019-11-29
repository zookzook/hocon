defmodule Hocon.Parser do

  alias Hocon.Tokenizer

  def decode(string) do

    with {:ok, ast} <- Tokenizer.decode(string) do

      #IO.puts "Ast #{inspect ast}"
      #IO.puts "\n\nFixed ast #{inspect contact_rule(ast, [])}"

      with {[], result } <- ast
      |> contact_rule([])
      |> parse_root() do
        {:ok, result}
      end
    end
  end

  def contact_rule([], result) do
    result
    |> Enum.reject(fn
      :new_line -> true
      _other    -> false
    end)
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
  def contact_rule([other_a, :ws, other_b|rest], result) do
    contact_rule(rest, [other_b, other_a |result])
  end
  def contact_rule([:ws|rest], result) do
    contact_rule(rest, result)
  end
  def contact_rule([other|rest], result) do
    contact_rule(rest, [other | result])
  end

  def parse_root([:open_curly | rest]) do
    parse_object(rest, %{})
  end
  def parse_root(tokens) do
    parse_object(tokens, %{}, true)
  end

  def parse_value([]) do
    {[], nil}
  end
  def parse([:open_curly | rest]) do
    parse_object(rest, %{})
  end
  def parse([:open_square | rest]) do
    parse_array(rest, [])
  end
  def parse([{:string, str} | rest]) do
    {rest, str}
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

  def parse_object(tokens, result, is_root \\ false)

  def parse_object([], result, true) do
    {[], result}
  end
  def parse_object([:close_curly | rest], result, false) do
    {rest, result}
  end
  def parse_object([:comma | rest], result, root) do
    parse_object(rest, result, root)
  end
  def parse_object([{:string, key}, :open_curly | rest], result, root) do
    {rest, value} = parse_object(rest, %{})
    parse_object(rest, Map.put(result, key, value), root)
  end
  def parse_object([{:string, key}, :colon | rest], result, root) do
    {rest, value} = parse(rest)
    parse_object(rest, Map.put(result, key, value), root)
  end

  def parse_array([:close_square| rest], result) do
    {rest, Enum.reverse(result)}
  end
  def parse_array([:comma, :close_square | rest], result) do
    {rest, Enum.reverse(result)}
  end
  def parse_array([:comma | rest], result) do
    parse_array(rest, result)
  end
  def parse_array(value, result) do
    {rest, value} = parse(value)
    parse_array(rest, [value | result])
  end

  def merge_unquoted_strings([{:unquoted_string, key} | rest], result) do
    merge_unquoted_strings(rest, [key | result])
  end
  def merge_unquoted_strings(rest, result) do
    {rest, join_strings(result)}
  end

  defp join_strings(strings) do
    strings
    |>Enum.reverse()
    |> Enum.join(" ")
  end


end