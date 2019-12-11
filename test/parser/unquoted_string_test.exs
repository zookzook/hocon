defmodule Parser.UnquotedStringTest do
  use ExUnit.Case, async: true

  alias Hocon.Parser
  alias Hocon.Tokenizer

  test "parsing various unquoted string combinations" do
    {:ok, ast} = Tokenizer.decode(~s(a : 10kb))
    assert [{:unquoted_string, "a"}, :colon, {:unquoted_string, "10kb"}] == Parser.contact_rule(ast, [])
    assert {:ok, %{"a" => "10kb"}} == Hocon.decode(~s({a : b\n a : 10kb}))
  end

  test "Parsing unquoted strings as values" do
    assert {:ok, %{"a" => "c"}} == Hocon.decode(~s({a : b\n a : c}))
  end

  test "Parsing quoted strings as keys" do
    assert {:ok, %{"a" => %{"b" => %{"c" => 1}}}} == Hocon.decode(~s({"a" { "b" { c : 1 }}}))
  end

  test "Contact unquoted strings to one string" do
    {:ok, ast} = Tokenizer.decode(~s({}))
    assert [:open_curly, :close_curly] == Parser.contact_rule(ast, [])

    {:ok, ast} = Tokenizer.decode(~s({a b c}))
    assert [:open_curly, {:unquoted_string, "a b c"}, :close_curly] == Parser.contact_rule(ast, [])

    {:ok, ast} = Tokenizer.decode(~s({a 3 c}))
    assert [:open_curly, {:unquoted_string, "a 3 c"}, :close_curly] == Parser.contact_rule(ast, [])

    {:ok, ast} = Tokenizer.decode(~s({1 3 c}))
    assert [:open_curly, {:unquoted_string, "1 3 c"}, :close_curly] == Parser.contact_rule(ast, [])
  end

end
