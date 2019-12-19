defmodule Parser.IncludeRecursionTest do
  use ExUnit.Case, async: true

  test "Tokenize include recursion" do
    assert catch_throw(Hocon.decode!(~s({ a : { include "./test/data/recursion-1.conf" } }))) == {:error, "File ./test/data/recursion-1.conf already included."}
  end

end
