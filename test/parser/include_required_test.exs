defmodule Parser.IncludeRequiredTest do
  use ExUnit.Case, async: true

  alias Hocon.Tokenizer

  test "Tokenize include required statement" do
    assert {:ok, [:open_curly, {:unquoted_string, "a"}, :colon, :open_curly, :include, :required, :open_round, {:string, "foo.conf"}, :close_round, :close_curly, :close_curly]} == Tokenizer.decode(~s({ a : { include required\("foo.conf"\) } }))
  end

  test "Parse include required statement - empty" do
    assert catch_throw(Hocon.decode!(~s({ a : { include required\("foo.conf"\) } }))) == {:error, "file foo.conf was not found"}
  end

  test "Parse include statement - without extensions" do
    conf = Hocon.decode!(~s({ a : { include required\("./test/data/include-1"\) } }))
    assert %{"a" => %{"x" => 10, "y" => 10}} == conf
    conf = Hocon.decode!(~s({ a : { include required\("./test/data/include-2"\) } }))
    assert %{"a" => %{"x" => 10, "y" => 10}} == conf
    conf = Hocon.decode!(~s({ a : { include required\("./test/data/include-3"\) } }))
    assert %{"a" => %{"x" => 10, "y" => 10}} == conf
  end

  test "Parse include required statement - ) missing" do
    assert catch_throw(Hocon.decode!(~s({ a : { include required\("./test/data/include-1" } }))) == {:error, "syntax error: ')' required "}
    assert catch_throw(Hocon.decode!(~s({ a : { include required\(file\("./test/data/include-1" } }))) == {:error, "syntax error: file location required"}
    assert catch_throw(Hocon.decode!(~s({ a : { include required\(url\("./test/data/include-1" } }))) == {:error, "syntax error: file location required"}
  end

end
