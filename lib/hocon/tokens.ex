defmodule Hocon.Tokens do
  @moduledoc """
  This module is responsible for pushing tokens to the list of tokens. It handles the cases of whitespaces and new lines.

  Whitespaces are important in cases of unquoted strings und new lines are important for merging objects and arrays.

  * whitespace are almost ignored
  * only allowed in context of unquoted strings and simple values [see](https://github.com/lightbend/config/blob/master/HOCON.md#unquoted-strings)
  * new lines are used to  [see](https://github.com/lightbend/config/blob/master/HOCON.md#array-and-object-concatenation)

  See also the `tokens_test.exs` for more information.
  """

  alias Hocon.Tokens

  # coveralls-ignore-start
  defstruct acc: [],  ws: false
  # coveralls-ignore-stop

  @doc """
  Create a new `Tokens` struct.

  ## Example
  ```elixir
    iex(1)> Hocon.Tokens.new()
    %Hocon.Tokens{acc: [], ws: false}
  ```
  """
  def new() do
    %Tokens{}
  end

  @doc """
  Push a token to the Tokens struct.

  ## Example
  ```elixir
    tokens = Tokens.new()

    seq = tokens
          |> Tokens.push(1)
          |> Tokens.push(:ws)
          |> Tokens.push({:unquoted_string, "2"})
          |> Tokens.push(:ws)
          |> Tokens.push(3)
          |> Tokens.push(:ws)
          |> Tokens.push({:unquoted_string, "4"})

    assert [{:unquoted_string, "4"}, :ws, 3, :ws, {:unquoted_string, "2"}, :ws, 1] == seq.acc
  ```
  """
  def push(%Tokens{} = result, :ws) do
    %Tokens{result | ws: true}
  end

  def push(%Tokens{acc: []} = result, :nl) do
    result
  end
  def push(%Tokens{acc: [:nl|_]} = result, :nl) do
    result
  end

  def push(%Tokens{acc: [{:unquoted_string, _}|_] = acc, ws: true} = result, {:unquoted_string, _} = value) do
    %Tokens{result | acc: [value, :ws | acc], ws: false}
  end
  def push(%Tokens{acc: [{:unquoted_string, _}|_] = acc, ws: true} = result, number) when is_number(number) do
    %Tokens{result | acc: [number, :ws | acc], ws: false}
  end
  def push(%Tokens{acc: [last_number|_] = acc, ws: true} = result, {:unquoted_string, _} = value) when is_number(last_number) do
    %Tokens{result | acc: [value, :ws | acc], ws: false}
  end
  def push(%Tokens{acc: [last_number|_] = acc, ws: true} = result, number) when is_number(number) and is_number(last_number) do
    %Tokens{result | acc: [number, :ws | acc], ws: false}
  end

  def push(%Tokens{acc: acc} = result, token) do
    %Tokens{result | acc: [token | acc], ws: false}
  end

end