defmodule Parser.ByteUnitsTest do
  use ExUnit.Case, async: true

  ## size units, power of 2
  @kb 1024
  @mb @kb * 1024
  @gb @mb * 1024
  @tb @gb * 1024
  @pb @tb * 1024
  @eb @pb * 1024
  @zb @eb * 1024
  @yb @zb * 1024

  ## size units, power of 10
  @kb_10 1000
  @mb_10 @kb_10 * 1000
  @gb_10 @mb_10 * 1000
  @tb_10 @gb_10 * 1000
  @pb_10 @tb_10 * 1000
  @eb_10 @pb_10 * 1000
  @zb_10 @eb_10 * 1000
  @yb_10 @zb_10 * 1000

  test "as_bytes/1" do
    assert Hocon.as_bytes(10) == 10
    assert Hocon.as_bytes("10") == 10
    assert assert_bytes(~w(b byte bytes), 1) == true
    assert assert_bytes(~w(k kb kilobyte kilobytes), @kb) == true
    assert assert_bytes(~w(m mb megabyte megabytes), @mb) == true
    assert assert_bytes(~w(g gb gigabyte gigabytes), @gb) == true
    assert assert_bytes(~w(t tb terabyte terabytes), @tb) == true
    assert assert_bytes(~w(p pb petabyte petabytes), @pb) == true
    assert assert_bytes(~w(e eb exabyte exabytes), @eb) == true
    assert assert_bytes(~w(z zb zettabyte zettabytes), @zb) == true
    assert assert_bytes(~w(y yb yottabyte yottabytes), @yb) == true
  end

  test "as_size/1" do
    assert Hocon.as_size(10) == 10
    assert Hocon.as_size("10") == 10
    assert assert_size(~w(b byte bytes), 1) == true
    assert assert_size(~w(k kb kilobyte kilobytes), @kb_10) == true
    assert assert_size(~w(m mb megabyte megabytes), @mb_10) == true
    assert assert_size(~w(g gb gigabyte gigabytes), @gb_10) == true
    assert assert_size(~w(t tb terabyte terabytes), @tb_10) == true
    assert assert_size(~w(p pb petabyte petabytes), @pb_10) == true
    assert assert_size(~w(e eb exabyte exabytes), @eb_10) == true
    assert assert_size(~w(z zb zettabyte zettabytes), @zb_10) == true
    assert assert_size(~w(y yb yottabyte yottabytes), @yb_10) == true
  end

  defp assert_bytes(units, factor) do
    Enum.all?(units, fn unit ->
      value = :rand.uniform(1000)
      result = value * factor
      string_1 = to_string(value) <> " " <> unit
      string_2 = to_string(value) <> unit
      Hocon.as_bytes(string_1) == result &&
      Hocon.as_bytes(string_2) == result
    end)
  end

  defp assert_size(units, factor) do
    Enum.all?(units, fn unit ->
      value = :rand.uniform(1000)
      result = value * factor
      string_1 = to_string(value) <> " " <> unit
      string_2 = to_string(value) <> unit
      Hocon.as_size(string_1) == result &&
      Hocon.as_size(string_2) == result
    end)
  end
end
