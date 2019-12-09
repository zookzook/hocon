defmodule Parser.ErrorTest do
  use ExUnit.Case, async: true

  test "parsing a wrong object" do
    assert catch_throw(Hocon.decode(~s({a : b :}))) ==  {:error, "syntax error"}
  end

end
