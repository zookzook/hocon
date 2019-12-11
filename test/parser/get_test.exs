defmodule Parser.GetTest do
  use ExUnit.Case, async: true

  test "get a nested value" do
    conf = Hocon.decode!(~s(a { b { c : "10kb" } }))
    assert "10kb" == Hocon.get(conf, "a.b.c", nil)
    assert "10kb" == Hocon.get(conf, "a.b.d", "10kb")
  end

  test "get a nested value as bytes" do
    conf = Hocon.decode!(~s(a { b { c : "10kb" } }))
    assert (10*1024) == Hocon.get_bytes(conf, "a.b.c", nil)
    assert (10*1024) == Hocon.get_bytes(conf, "a.b.d", 10*1024)
  end

  test "get a nested value as size" do
    conf = Hocon.decode!(~s(a { b { c : "10kb" } }))
    assert (10*1000) == Hocon.get_size(conf, "a.b.c", nil)
    assert (10*1000) == Hocon.get_size(conf, "a.b.d", 10*1000)
  end

  test "get a nested value as duration" do
    conf = Hocon.decode!(~s(a { b { c : "3d" } }))
    assert (3*1000*60*60*24) == Hocon.get_milliseconds(conf, "a.b.c", nil)
    assert (10*1000) == Hocon.get_milliseconds(conf, "a.b.d", 10*1000)
  end

end
