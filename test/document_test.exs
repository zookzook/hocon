defmodule DocumentTest do
  use ExUnit.Case
  doctest Hocon

  alias Hocon.Document

  test "Create an empty document struct" do
    assert  %Document{root: %{}} == Document.new()
  end

  test "Use path expressions" do
    result = Document.new()
             |> Document.put("a.b.c", "foo")
    assert %{"a" => %{"b" => %{"c" => "foo"}}}== result.root
  end

  test "Use multiple path expressions" do
    result = Document.new()
             |> Document.put("a.b.c", "foo")
             |> Document.put("a.b.c", "bar")
    assert %{"a" => %{"b" => %{"c" => "bar"}}}== result.root

    result = Document.new()
             |> Document.put("a.b.c", "foo")
             |> Document.put("a.b.d", "bar")
    assert %{"a" => %{"b" => %{"c" => "foo", "d" => "bar"}}}== result.root

    other = Document.new()
             |> Document.put("x", "foo")
             |> Document.put("y", "bar")

    result = Document.put(result, "b", other)

    assert  %{"a" => %{"b" => %{"c" => "foo", "d" => "bar"}}, "b" => %{"x" => "foo", "y" => "bar"}}== result.root
  end

  test "object merging" do
    result = Document.new()
             |> Document.put("foo.a", "42")
             |> Document.put("foo.b", "43")
    assert  %{"foo" => %{"a" => "42", "b" => "43"}} == result.root
    result = Document.new()
             |> Document.put("foo.a", "42")
             |> Document.put("foo.a", nil)
             |> Document.put("foo.b", "43")
    assert  %{"foo" => %{ "b" => "43"}} == result.root
  end

  test "Conversion of numerically-indexed objects to arrays" do

    result = Document.new()
             |> Document.put("foo.x", 42)
             |> Document.put("foo.1", 43)
             |> Document.put("foo.2", 43)

    result = Document.convert_to_array(result.root["foo"], convert_numerically_indexed: true)

    assert :not_converted == result

    result = Document.new()
             |> Document.put("foo.x", 42)
             |> Document.put("foo.1", 43)
             |> Document.put("foo.2", 43)

    result = Document.convert_to_array(result.root["foo"], convert_numerically_indexed: true, strict_conversion: false)
    assert {:converted, [43,43]} == result

    result = Document.new()
             |> Document.put("foo.0", 42)
             |> Document.put("foo.1", 43)
             |> Document.put("foo.2", 43)

    result = Document.convert_to_array(result.root["foo"], convert_numerically_indexed: true)

    assert {:converted, [42,43,43]} == result
  end

  test "Conversion of numerically-indexed objects to arrays using convert" do
    result = Document.new()
             |> Document.put("foo.0", 42)
             |> Document.put("foo.1", 43)
             |> Document.put("foo.2", 43)

    result = Document.convert(result, convert_numerically_indexed: true)
    assert %{"foo" => [42, 43, 43]} == result

  end

end