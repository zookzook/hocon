defmodule Parser.IncludeLocatingResourcesTest do
  use ExUnit.Case, async: true

  alias Hocon.Tokenizer

  test "Tokenize include required statement - file location" do
    assert {:ok, [:open_curly, {:unquoted_string, "a"}, :colon, :open_curly, :include, :required, :open_round, :file, :open_round, {:string, "foo.conf)"}, :close_round, :close_curly, :close_curly]} == Tokenizer.decode(~s({ a : { include required\(file\("foo.conf\)"\) } }))
    assert {:ok, [:open_curly, {:unquoted_string, "a"}, :colon, :open_curly, :include, :required, :open_round, :url, :open_round, {:string, "foo.conf)"}, :close_round, :close_curly, :close_curly]} == Tokenizer.decode(~s({ a : { include required\(url\("foo.conf\)"\) } }))
  end

end
