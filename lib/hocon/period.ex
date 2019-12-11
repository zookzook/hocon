defmodule Hocon.Period do
  @moduledoc """

  This structure contains the period defined by years, months and days. It is the result of the `Hocon.get_period/2`
  and `Hocon.as_period/1` function. You can use it to calculate new dates. Unfortenly Elixir Date Library does not
  support adding other units like months or years. It supports only days:

  ## Example

      iex> conf = Hocon.decode!(~s(max_period = 3days))
      %{"max_period" => "3days"}
      iex> %Hocon.Period{days: days, months: _, years: _} = Hocon.get_period(conf, "max_period")
      %Hocon.Period{days: 3, months: 0, years: 0}
      iex> Date.add(~D[2000-02-27], days)
      ~D[2000-03-01]

  A better alternative is [timex](https://hexdocs.pm/timex/getting-started.html):

  ## Example
      iex> conf = Hocon.decode!(~s(max_period = 1m))
      %{"max_period" => "1m"}
      iex> %Hocon.Period{days: _, months: months, years: _} = Hocon.get_period(conf, "max_period")
      %Hocon.Period{days: 0, months: 1, years: 0}
      iex> Date.add(~D[2000-02-27], days)
      Timex.shift(~D[2000-11-29], months: 3)
      ~D[2001-02-28]

  """
  alias Hocon.Period

  defstruct years: 0, months: 0, days: 0

  @doc"""
  Returns a period for `days`.
  """
  def days(days) when is_number(days) do
    %Period{days: days}
  end

  @doc"""
  Returns a period for `weeks`. The weeks are multiplied by 7.
  """
  def weeks(weeks) when is_number(weeks) do
    %Period{days: weeks * 7}
  end

  @doc"""
  Returns a period for `months`.
  """
  def months(months) when is_number(months) do
    %Period{months: months}
  end

  @doc"""
  Returns a period for `years`.
  """
  def years(years) when is_number(years) do
    %Period{years: years}
  end

end