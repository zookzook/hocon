defmodule Parser.PeriodUnitsTest do
  use ExUnit.Case, async: true

  test "as_period/1" do
    assert Hocon.as_period(10) == %Hocon.Period{days: 10, months: 0, years: 0}
    assert Hocon.as_period("10") == %Hocon.Period{days: 10, months: 0, years: 0}
    assert assert_periods(~w(d day days), "10", %Hocon.Period{days: 10, months: 0, years: 0})
    assert assert_periods(~w(w week weeks), "10", %Hocon.Period{days: 10*7, months: 0, years: 0})
    assert assert_periods(~w(m mo month months), "10", %Hocon.Period{days: 0, months: 10, years: 0})
    assert assert_periods(~w(y year years), "10", %Hocon.Period{days: 0, months: 0, years: 10})
  end

  defp assert_periods(units, value, expected) do
    Enum.all?(units, fn unit ->
      string_1 = value <> " " <> unit
      string_2 = value <> unit
      Hocon.as_period(string_1) == expected &&
        Hocon.as_period(string_2) == expected
    end)
  end

end
