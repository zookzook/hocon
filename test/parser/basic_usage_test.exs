defmodule Parser.BasicUsageTest do
  use ExUnit.Case, async: true

  test "parsing a simple object" do
    assert {:ok, %{"key" => "value"}} == Hocon.decode(~s(key = value))
    assert %{"key" => "value"} == Hocon.decode!(~s(key = value))
    assert {:error, "syntax error"} == Hocon.decode(~s({a : b :}))
    assert catch_throw(Hocon.decode!(~s({a : b :}))) ==  {:error, "syntax error"}
    assert catch_throw(Hocon.decode!(~s({a : b :}))) ==  {:error, "syntax error"}
  end

end
