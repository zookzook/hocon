defmodule Parser.IncludeTest do
  use ExUnit.Case, async: true

  alias Hocon.Tokenizer

  test "Tokenize include statement" do
    assert {:ok, [:open_curly, {:unquoted_string, "a"}, :colon, :open_curly, :include, {:string, "foo.conf"}, :close_curly, :close_curly]} == Tokenizer.decode(~s({ a : { include "foo.conf" } }))
  end

  test "Parse include statement - empty" do
    conf = Hocon.decode!(~s({ a : { include "foo.conf" } }))
    assert %{"a" => %{}} == conf
  end

  test "Parse include statement" do
    conf = Hocon.decode!(~s({ a : { include "./test/data/include-1.conf" } }))
    assert %{"a" => %{"x" => 10, "y" => 10}} == conf
    conf = Hocon.decode!(~s({ a : { include "./test/data/include-1.conf"}\n a : { x : 42}}))
    assert %{"a" => %{"x" => 42, "y" => 42}} == conf
  end

  test "Parse include statement - syntax error" do
    assert catch_throw(Hocon.decode!(~s({ a : { include "./test/data/syntax-error.conf" } }))) == {:error, "syntax error"}
  end

  test "Parse include statement - without extensions" do
    conf = Hocon.decode!(~s({ a : { include "./test/data/include-1" } }))
    assert %{"a" => %{"x" => 10, "y" => 10}} == conf
    conf = Hocon.decode!(~s({ a : { include "./test/data/include-2" } }))
    assert %{"a" => %{"x" => 10, "y" => 10}} == conf
    conf = Hocon.decode!(~s({ a : { include "./test/data/include-3" } }))
    assert %{"a" => %{"x" => 10, "y" => 10}} == conf
  end

  test "Parse include file location statement - ) missing" do
    assert catch_throw(Hocon.decode!(~s({ a : { include file\("./test/data/include-1" } }))) == {:error, "syntax error: file location required"}
    assert catch_throw(Hocon.decode!(~s({ a : { include url\("./test/data/include-1" } }))) == {:error, "syntax error: file location required"}
  end

end
