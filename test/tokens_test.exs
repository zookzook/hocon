defmodule TokensTest do
  use ExUnit.Case
  #doctest Hocon

  alias Hocon.Tokens

  test "Create a Tokens struct" do
    assert  %Hocon.Tokens{acc: [], ws: false} == Tokens.new()
  end

  test "A sequence of :nl tokens should result in only one :nl token" do

    tokens = Tokens.new()

    %Hocon.Tokens{acc: [], ws: false}

    seq = tokens
          |> Tokens.push(:nl)
          |> Tokens.push(:nl)
          |> Tokens.push({:string, "x"})
          |> Tokens.push(:nl)
          |> Tokens.push(:nl)

    assert [:nl, {:string, "x"}] == seq.acc
  end

  test "A sequence of complex tokens should not have any whitespace token" do

    tokens = Tokens.new()

    seq = tokens
          |> Tokens.push(:open_curly)
          |> Tokens.push(:ws)
          |> Tokens.push({:string, "x"})
          |> Tokens.push(:close_curly)
          |> Tokens.push(:ws)
          |> Tokens.push(:open_curly)
          |> Tokens.push(:ws)
          |> Tokens.push(:close_curly)

    assert [:close_curly, :open_curly, :close_curly, {:string, "x"}, :open_curly] == seq.acc
  end

  test "A sequence of complex tokens should not have any whitespace tokens" do

    tokens = Tokens.new()

    seq = tokens
          |> Tokens.push(:open_curly)
          |> Tokens.push(:ws)
          |> Tokens.push({:string, "x"})
          |> Tokens.push(:close_curly)
          |> Tokens.push(:ws)
          |> Tokens.push(:open_curly)
          |> Tokens.push(:ws)
          |> Tokens.push(:close_curly)

    assert [:close_curly, :open_curly, :close_curly, {:string, "x"}, :open_curly] == seq.acc
  end

  test "A squence of strings should not have any whitespace tokens" do

    tokens = Tokens.new()

    seq = tokens
          |> Tokens.push({:string, "1"})
          |> Tokens.push(:ws)
          |> Tokens.push({:string, "2"})
          |> Tokens.push(:ws)
          |> Tokens.push({:string, "3"})
          |> Tokens.push(:ws)
          |> Tokens.push({:string, "4"})


    assert [string: "4", string: "3", string: "2", string: "1"] == seq.acc

  end

  test "A squence of unquoted strings can be surrounded with whitespace tokens" do

    tokens = Tokens.new()

    seq = tokens
          |> Tokens.push(:ws)
          |> Tokens.push({:unquoted_string, "1"})
          |> Tokens.push(:ws)
          |> Tokens.push({:unquoted_string, "2"})
          |> Tokens.push(:ws)
          |> Tokens.push({:unquoted_string, "3"})
          |> Tokens.push(:ws)
          |> Tokens.push({:unquoted_string, "4"})
          |> Tokens.push(:ws)


    assert [{:unquoted_string, "4"}, :ws, {:unquoted_string, "3"}, :ws, {:unquoted_string, "2"}, :ws, {:unquoted_string, "1"}] == seq.acc

  end

  test "A squence of int numbers can have whitespace tokens" do

    tokens = Tokens.new()

    seq = tokens
          |> Tokens.push(1)
          |> Tokens.push(:ws)
          |> Tokens.push(2)
          |> Tokens.push(:ws)
          |> Tokens.push(3)
          |> Tokens.push(:ws)
          |> Tokens.push(4)


    assert [4, :ws, 3, :ws, 2, :ws, 1] == seq.acc

  end

  test "A squence of mixed numbers and unquoted strings can have whitespace tokens" do

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

  end

end
