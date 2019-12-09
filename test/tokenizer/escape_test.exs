defmodule Tokenizer.EscapeTest do
  use ExUnit.Case, async: true

  alias Hocon.Tokenizer

  test "wrong escaped in quoted strings" do
    assert catch_throw(Tokenizer.decode(~s("\\x"))) == {:position, 2}
    assert catch_throw(Tokenizer.decode(~s("\\"))) == {:position, 3}
    assert catch_throw(Tokenizer.decode(~s("\\))) == {:position, 1}
    assert catch_throw(Tokenizer.decode(~s("\\u))) == {:position, 1}
    assert catch_throw(Tokenizer.decode(~s("\\uD834\\DD1E"))) == {:position, 7}
  end

  test "wrong escaped in unquoted strings" do
    assert catch_throw(Tokenizer.decode("\\x")) == {:position, 0}
    assert catch_throw(Tokenizer.decode("\\")) == {:position, 0}
  end

  test "simple escaped characters" do
    assert {:ok, [string: "Parsing escape string\b"]} == Tokenizer.decode(~s("Parsing escape string\\b"))
    assert {:ok, [string: "Parsing escape \b string"]} == Tokenizer.decode(~s("Parsing escape \\b string"))
    assert {:ok, [string: "Parsing escape string\t"]} == Tokenizer.decode(~s("Parsing escape string\\t"))
    assert {:ok, [string: "Parsing escape \t string"]} == Tokenizer.decode(~s("Parsing escape \\t string"))
    assert {:ok, [string: "Parsing escape string\n"]} == Tokenizer.decode(~s("Parsing escape string\\n"))
    assert {:ok, [string: "Parsing escape \n string"]} == Tokenizer.decode(~s("Parsing escape \\n string"))
    assert {:ok, [string: "Parsing escape string\f"]} == Tokenizer.decode(~s("Parsing escape string\\f"))
    assert {:ok, [string: "Parsing escape \f string"]} == Tokenizer.decode(~s("Parsing escape \\f string"))
    assert {:ok, [string: "Parsing escape string\r"]} == Tokenizer.decode(~s("Parsing escape string\\r"))
    assert {:ok, [string: "Parsing escape \r string"]} == Tokenizer.decode(~s("Parsing escape \\r string"))
    assert {:ok, [string: "Parsing escape string\/"]} == Tokenizer.decode(~s("Parsing escape string\\/"))
    assert {:ok, [string: "Parsing escape \/ string"]} == Tokenizer.decode(~s("Parsing escape \\/ string"))
    assert {:ok, [string: "Parsing escape string\\"]} == Tokenizer.decode(~s("Parsing escape string\\\\"))
    assert {:ok, [string: "Parsing escape \\ string"]} == Tokenizer.decode(~s("Parsing escape \\\\ string"))
  end

  test "escaped unicodes strings" do
    assert {:ok, [string: "𠜎 𠜱 𠝹"]} == Tokenizer.decode(~s("""𠜎 𠜱 𠝹"""))
    assert {:ok, [string: "€"]} == Tokenizer.decode(~s("""€"""))
    assert {:ok, [string: "ɐ"]} == Tokenizer.decode(~s("""ɐ"""))

    assert {:ok, [string: "abc € 𠜎 𠜱 𠝹 ɐ ⚛"]} == Tokenizer.decode(~s("abc \\u20ac 𠜎 𠜱 𠝹 ɐ ⚛"))

    assert {:ok, [string: "𠜎 𠜱 𠝹"]} == Tokenizer.decode("\"𠜎 𠜱 𠝹\"")
    assert {:ok, [string: "⚛"]} == Tokenizer.decode(~s("⚛"))
    assert {:ok, [string: "ɐ"]} == Tokenizer.decode(~s("ɐ"))
    assert {:ok, [string: "€"]} == Tokenizer.decode(~s("€"))
    assert {:ok, [string: "€"]} == Tokenizer.decode(~s("\\u20ac"))
    assert {:ok, [string: "☃"]} == Tokenizer.decode("\"☃\"")
    assert {:ok, [string: "☃"]} == Tokenizer.decode(~s("\\u2603"))
    assert {:ok, [string: "𝄞"]} == Tokenizer.decode(~s("\\uD834\\uDD1E"))
    assert {:ok, [string: "힙힙"]} == Tokenizer.decode(~s("\\uD799\\uD799"))
    assert {:ok, [string: "✔︎"]} == Tokenizer.decode(~s("✔︎"))
    assert {:ok, [string: "\u2028\u2029"]} == Tokenizer.decode(~s("\\u2028\\u2029"))
  end
end
