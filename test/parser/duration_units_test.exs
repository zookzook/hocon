defmodule Parser.DurationUnitsTest do
  use ExUnit.Case, async: true

  ## time units, the base is millisconds
  @ns 0.000001
  @us 0.001
  @ms 1
  @s @ms * 1000
  @m @s * 60
  @h @m * 60
  @d @h * 24

  test "as_milliseconds/1" do
    assert Hocon.as_milliseconds(10) == 10
    assert Hocon.as_milliseconds("10") == 10
    assert assert_milliseconds(~w(ns nano nanos nanosecond nanoseconds), @ns) == true
    assert assert_milliseconds(~w(us micro micros microsecond microseconds), @us) == true
    assert assert_milliseconds(~w(ms milli millis millisecond millisecond), @ms) == true
    assert assert_milliseconds(~w(s second seconds), @s) == true
    assert assert_milliseconds(~w(m minute minutes), @m) == true
    assert assert_milliseconds(~w(h hour hours), @h) == true
    assert assert_milliseconds(~w(d day days), @d) == true
  end

  defp assert_milliseconds(units, factor) do
    Enum.all?(units, fn unit ->
      value = :rand.uniform(1000)
      result = value * factor
      string_1 = to_string(value) <> " " <> unit
      string_2 = to_string(value) <> unit
      Hocon.as_milliseconds(string_1) == result &&
        Hocon.as_milliseconds(string_2) == result
    end)
  end

end
