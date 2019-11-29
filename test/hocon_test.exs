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

    {:ok, ast} = Tokenizer.decode(~s({1 3 c}))
    assert [:open_curly, {:string, "1 3 c"}, :close_curly] == Parser.contact_rule(ast, [])
  end

  test "Parse simple array" do
    assert {:ok, %{"a" => [1, 2, 3, 4]}} == Parser.decode(~s( a = [1,2,3,4]))
    assert {:ok, %{"a" => ["1 2 3 4"]}} == Parser.decode(~s( a = [1 2 3 4]))
    assert {:ok, %{"a" => [1, 2, 3, 4]}} == Parser.decode(~s( a = [1\n2\n3\n4]))
  end

  test "Parse simple object" do
    assert {:ok, %{"a" => 1, "b" => 3, "c" => 4}} == Parser.decode(~s({a : 1, b : 2, b : 3, c : 4}))
    assert {:ok, %{"a" => 1, "b" => 3, "c" => 4}} == Parser.decode(~s({a : 1\nb : 2\nb : 3\nc : 4}))
    assert {:ok, %{"a" => 1, "b" => 3, "c" => 4}} == Parser.decode(~s({\na : 1\nb : 2\nb : 3\nc : 4\n}))
  end

  test "Parse nested objects" do
    assert {:ok, %{"a" => %{"b" => %{"c" => 1}}}} == Parser.decode(~s({a : { b : { c : 1 }}}))
    assert {:ok, %{"a" => %{"b" => %{"c" => 1}}}} == Parser.decode(~s({a { b { c : 1 }}}))
  end

  test "Parse configuration with BOM" do
    assert {:ok, %{"a" => %{"b" => %{"c" => 1}}}} == Parser.decode(<<0xEF, 0xBB, 0xBF>> <> ~s({a : { b : { c : 1 }}}))
    assert {:ok, %{"a" => %{"b" => %{"c" => 1}}}} == Parser.decode(<<0xEF, 0xBB, 0xBF>> <> ~s(a : { b : { c : 1 }}))
  end

  test "Parse path expressions" do

    assert {:ok, %{"foo" => %{"bar" => 42}}} == Parser.decode(~s(foo.bar : 42))

  end

  test "Parse json" do
    assert {:ok, %{"foo" => %{ "baz" => "bar"}}} == Parser.decode(~s({"foo": { "baz" : "bar"} }))
  end


end
