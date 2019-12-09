defmodule Tokenizer.NumberTest do
  use ExUnit.Case, async: true

  alias Hocon.Tokenizer

  test "wrong escaped in quoted strings" do
    assert parse!("0") == 0
    assert parse!("1") == 1
    assert parse!("-0") == 0
    assert parse!("-1") == -1
    assert parse!("0.1") == 0.1
    assert parse!("-0.1") == -0.1
    assert parse!("0e0") == 0
    assert parse!("0E0") == 0
    assert parse!("1e0") == 1
    assert parse!("1E0") == 1
    assert parse!("1.0e0") == 1.0
    assert parse!("1e+0") == 1
    assert parse!("1.0e+0") == 1.0
    assert parse!("0.1e1") == 0.1e1
    assert parse!("0.1e-1") == 0.1e-1
    assert parse!("99.99e99") == 99.99e99
    assert parse!("-99.99e-99") == -99.99e-99
    assert parse!("123456789.123456789e123") == 123456789.123456789e123
  end

  test "forcing error" do
    assert catch_throw(Tokenizer.decode("-a")) == {:position, 1}
    assert catch_throw(Tokenizer.decode("0.a")) == {:position, 2}
    assert catch_throw(Tokenizer.decode("-1Eg+2")) == {:position, 3}
    assert catch_throw(Tokenizer.decode("-1E+a")) == {:position, 4}
    assert catch_throw(Tokenizer.decode("1.")) == {:position, 2}
    assert catch_throw(Tokenizer.decode("-")) == {:position, 1}
    assert catch_throw(Tokenizer.decode("--1")) == {:position, 1}
    assert catch_throw(Tokenizer.decode("1e")) == {:position, 2}
    assert catch_throw(Tokenizer.decode("1.0e+")) == {:position, 5}
    assert catch_throw(Tokenizer.decode("99.99e")) == {:position, 6}
  end

  defp parse!(string) do
    with {:ok, [result]} <- Tokenizer.decode(string) do
      result
    end
  end

end