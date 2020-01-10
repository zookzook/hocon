defmodule Parser.QuotedStringTest do
  use ExUnit.Case, async: true

  test "Parsing quoted strings as keys" do
    assert {:ok, %{"a.b.c" => 1}} == Hocon.decode(~s("a.b.c" : 1))
    assert {:ok, %{"a" => %{"a.b.c" => 1}}} == Hocon.decode(~s( a : { "a.b.c" : 1 }))
    assert {:ok, %{"a" => %{"b" => %{"c" => %{"a.b.c" => 1}}}}} == Hocon.decode(~s( a.b.c : { "a.b.c" : 1 }))
  end

end
