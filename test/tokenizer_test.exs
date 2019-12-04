defmodule TokenizerTest do
  use ExUnit.Case, async: true
  doctest Hocon

  alias Hocon.Tokenizer

  test "Tokenize some simple" do
    assert {:ok, [:open_curly, :close_curly]} == Tokenizer.decode("{}")
    assert {:ok, []} == Tokenizer.decode("")
  end

  test "Skipping BOM" do
    assert {:ok, [:open_curly, :close_curly]} == Tokenizer.decode(<<0xEF, 0xBB, 0xBF>> <>"{}")
    assert {:ok, []} == Tokenizer.decode(<<0xEF, 0xBB, 0xBF>> <> "")
  end

  test "Skipping comments" do
    assert {:ok, []} == Tokenizer.decode("# this is a comment")
    assert {:ok, []} == Tokenizer.decode("// this is a comment")
    assert {:ok, [:open_curly, {:unquoted_string, "a"}, :colon, 1, :close_curly]} == Tokenizer.decode("# comment 1\n{ a : 1 }# comment 2")
    assert {:ok, [:open_curly, {:unquoted_string, "a"}, :colon, 1, :nl, :close_curly]} == Tokenizer.decode("# comment 1\n{ a : 1 # comment 2\n }")
    assert {:ok, [:open_curly, :nl, {:unquoted_string, "a"}, :colon, 1, :close_curly]} == Tokenizer.decode("# comment 1\n{# comment 2\n a : 1}")
  end

  test "Skipping whitespaces and new lines" do

    assert {:ok, []} == Tokenizer.decode(<<0x1C, 0x1C>> <> "   ")
    assert {:ok, []} == Tokenizer.decode(<<0x1D, 0x1D>> <> "   ")
    assert {:ok, []} == Tokenizer.decode(<<0x1E, 0x1E>> <> "   ")
    assert {:ok, []} == Tokenizer.decode(<<0x1F, 0x1F>> <> "   ")
    assert {:ok, []} == Tokenizer.decode("        ")
    assert {:ok, []} == Tokenizer.decode("\n\n\n\n")
  end

  test "Tokenize simple values" do
    assert {:ok, [true]} == Tokenizer.decode("true")
    assert {:ok, [false]} == Tokenizer.decode("false")
    assert {:ok, [nil]} == Tokenizer.decode("null")
    assert {:ok, [true, 123]} == Tokenizer.decode("true123")
    assert {:ok, [false, 123]} == Tokenizer.decode("false123")
    assert {:ok, [nil, 123]} == Tokenizer.decode("null123")
    assert {:ok, [10, {:unquoted_string, "bar"}]} == Tokenizer.decode("10bar")
    assert {:ok, [10.5, {:unquoted_string, "bar"}]} == Tokenizer.decode("10.5bar")
    assert {:ok, [string: "this is a quoted string"]} == Tokenizer.decode(~s("this is a quoted string"))
    assert {:ok, [{:unquoted_string, "this"}, :ws, {:unquoted_string, "is"}, :ws, {:unquoted_string, "a"}, :ws,
                  {:unquoted_string, "unquoted"}, :ws, {:unquoted_string, "string"}]} == Tokenizer.decode(~s(this is a unquoted string))
  end

  test "multi-line strings" do
    assert {:ok, [string: "the answer is 42"]} == Tokenizer.decode(~s("""the answer is 42"""))
    assert {:ok, [string: "the answer is 42\n   * this\n    * is\n    * a\n   * test!"]} == Tokenizer.decode(~s("""the answer is 42\n   * this\n    * is\n    * a\n   * test!"""))
    assert {:ok, [string: "\"the answer is 42\""]} == Tokenizer.decode(~s(""""the answer is 42""""))
    assert {:ok, [string: "\"\"the answer is 42\"\""]} == Tokenizer.decode(~s("""""the answer is 42"""""))
    assert {:ok, [{:string, "the answer is \""}, 42]} == Tokenizer.decode(~s("""the answer is """" 42))
  end

  test "unquoted strings" do
    assert {:ok, [{:unquoted_string, "this"}, :open_square, :close_square, {:unquoted_string, "string"}]} == Tokenizer.decode(~s(this [] string))
    assert {:ok, [{:unquoted_string, "path/to/file"}]} == Tokenizer.decode(~s(/path/to/file))
    assert {:ok, [{:unquoted_string, "path/to"}]} == Tokenizer.decode(~s(/path/to// now we have a comment))
  end

  test "Tokenize numbers" do
    assert {:ok, [10]} == Tokenizer.decode("10")
    assert {:ok, [0]} == Tokenizer.decode("000")
    assert {:ok, [-10]} == Tokenizer.decode("-10")
    assert {:ok, [0]} == Tokenizer.decode("-000")

    assert {:ok, [10.0]} == Tokenizer.decode("10.0")
    assert {:ok, [0]} == Tokenizer.decode("0.0")
    assert {:ok, [-10.0]} == Tokenizer.decode("-10.0")
    assert {:ok, [0]} == Tokenizer.decode("-000")

    assert {:ok, [100]} == Tokenizer.decode("1.0E+2")
    assert {:ok, [100]} == Tokenizer.decode("1E+2")
    assert {:ok, [-100]} == Tokenizer.decode("-1.0E+2")
    assert {:ok, [-100]} == Tokenizer.decode("-1E+2")
  end

  test "Tokenize arrays" do
    assert {:ok, [:open_square, :close_square]} == Tokenizer.decode(~s([]))
    assert {:ok, [:open_square, 1, :comma, 2, :comma, 3, :comma, 4, :close_square]} == Tokenizer.decode(~s([1, 2, 3, 4]))
    assert {:ok, [:open_square, 1, :ws, 2, :ws, 3, :ws, 4, :close_square]} == Tokenizer.decode(~s([1 2 3 4]))
    assert {:ok, [:open_square, 1, :nl, 2, :nl, 3, :nl, 4, :close_square]} == Tokenizer.decode(~s([1\n2\n3\n4]))
  end
  test "Tokenize objects" do
    assert {:ok, [:open_curly, :close_curly]} == Tokenizer.decode(~s({}))
    assert {:ok, [:open_curly, {:unquoted_string, "key"}, :colon, {:unquoted_string, "value"}, :close_curly]} == Tokenizer.decode(~s({ key = value }))
    assert {:ok, [:open_curly, {:unquoted_string, "key"}, :colon, {:unquoted_string, "value"}, :comma,
                  {:unquoted_string, "key2"}, :colon, {:unquoted_string, "value"},
                  :close_curly]} == Tokenizer.decode(~s({ key = value, key2 : value }))
    assert {:ok, [:open_curly, {:unquoted_string, "key"}, :colon, :open_curly, {:unquoted_string, "a"}, :colon, 1, :close_curly, :close_curly]} == Tokenizer.decode(~s({ key = { a : 1 } }))
    assert {:ok, [:open_curly, {:unquoted_string, "key"}, :colon, :open_curly, {:unquoted_string, "a"}, :colon, 1, :close_curly, :close_curly]} == Tokenizer.decode(~s({ key : { a : 1 } }))
    assert {:ok, [:open_curly, {:unquoted_string, "key"}, :open_curly, {:unquoted_string, "a"}, :colon, 1, :close_curly, :close_curly]} == Tokenizer.decode(~s({ key { a : 1 } }))
  end

  test "forcing error" do
    assert catch_throw(Tokenizer.decode("-a")) == {:position, 1}
  end

  test "Tokenize substitutions" do
    assert {:ok, [{:unquoted_string, "key"}, :colon, {:string, "${animal.favorite} is my favorite animal"}]} == Tokenizer.decode(~s(key : """${animal.favorite} is my favorite animal"""))
    assert {:ok, [{:unquoted_string, "key"}, :colon, {:unquoted_string, "${animal.favorite}"}, :ws, {:unquoted_string, "is"}, :ws, {:unquoted_string, "my"}, :ws, {:unquoted_string, "favorite"}, :ws, {:unquoted_string, "animal"}]} == Tokenizer.decode(~s(key : ${animal.favorite} is my favorite animal))
    assert {:ok, [{:unquoted_string, "key"}, :colon, {:unquoted_string, "${animal.favorite}"}, {:string, " is my favorite animal"}]} == Tokenizer.decode(~s(key : ${animal.favorite}" is my favorite animal"))

    assert catch_throw(Tokenizer.decode(~s(key : ${animal.favorite))) == {:position, 6}
    assert catch_throw(Tokenizer.decode(~s(key : ${animal. favorite}))) == {:position, 6}
  end
end
