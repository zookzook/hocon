defmodule HoconTest do
  use ExUnit.Case
  doctest Hocon

  alias Hocon.Parser
  alias Hocon.Tokenizer

#  test "file" do
#
#    {:ok, body} = File.read("./test/data/comments.conf")
#    result = Parser.run(body)
#
#    IO.puts "Ergebnis: \n\n#{inspect result}"
#
#    assert true
#  end

  test "Parse missing root curlys" do
    assert {:ok, %{"key" => "value"}} == Parser.decode(~s(#test missing root curlys\n{key = value}))
    assert {:ok, %{"key" => "value"}} == Parser.decode(~s({key = value}))
    assert {:ok, %{"key" => "value"}} == Parser.decode(~s(key = value))
  end

  test "Contact unquoted strings to one string" do

    {:ok, ast} = Tokenizer.decode(~s({}))
    assert [:open_curly, :close_curly] == Parser.contact_rule(ast, [])

    {:ok, ast} = Tokenizer.decode(~s({a b c}))
    assert [:open_curly, {:string, "a b c"}, :close_curly] == Parser.contact_rule(ast, [])

    {:ok, ast} = Tokenizer.decode(~s({a 3 c}))
    assert [:open_curly, {:string, "a 3 c"}, :close_curly] == Parser.contact_rule(ast, [])

  end


end
