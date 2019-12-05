defmodule DocumentTest do
  use ExUnit.Case, async: true

  alias Hocon.Document

  test "Create an empty document struct" do
    assert  %Document{root: %{}} == Document.new()
  end

  test "Use path expressions" do
    {_, result} = Document.new()
                |> Document.put("a.b.c", "foo", [])
    assert %{"a" => %{"b" => %{"c" => "foo"}}}== result.root
  end

  test "Use multiple path expressions" do
    {_, result} = Document.new() |> Document.put("a.b.c", "foo", [])
    {_, result} = Document.put(result, "a.b.c", "bar", [])

    assert %{"a" => %{"b" => %{"c" => "bar"}}} == result.root

    {_, result} = Document.new() |> Document.put("a.b.c", "foo", [])
    {_, result} = Document.put(result, "a.b.d", "bar", [])
    assert %{"a" => %{"b" => %{"c" => "foo", "d" => "bar"}}}== result.root

    {_, other } = Document.new() |> Document.put("x", "foo", [])
    {_, other } = Document.put(other, "y", "bar", [])

    {_, result} = Document.put(result, "b", other, [])

    assert  %{"a" => %{"b" => %{"c" => "foo", "d" => "bar"}}, "b" => %{"x" => "foo", "y" => "bar"}}== result.root
  end

  test "object merging" do
    {_, result} = Document.new() |> Document.put("foo.a", "42")
    {_, result} = Document.put(result, "foo.b", "43")
    assert  %{"foo" => %{"a" => "42", "b" => "43"}} == result.root
    {_, result} = Document.new() |> Document.put("foo.a", "42")
    {_, result} = Document.put(result, "foo.a", nil)
    {_, result} = Document.put(result, "foo.b", "43")
    assert  %{"foo" => %{ "b" => "43"}} == result.root
  end

  test "Conversion of numerically-indexed objects to arrays" do

    {_, result} = Document.new() |> Document.put("foo.x", 42)
    {_, result} = Document.put(result, "foo.1", 43)
    {_, result} = Document.put(result, "foo.2", 43)

    result = Document.convert(result, convert_numerically_indexed: true)

    assert %{"foo" => %{"1" => 43, "2" => 43, "x" => 42}} == result

    {_, result} = Document.new() |> Document.put("foo.x", 42)
    {_, result} = Document.put(result, "foo.1", 43)
    {_, result} = Document.put(result, "foo.2", 43)

    result = Document.convert(result, convert_numerically_indexed: true, strict_conversion: false)
    assert %{"foo" => [43,43]} == result

    {_, result} = Document.new() |> Document.put("foo.0", 42)
    {_, result} = Document.put(result, "foo.1", 43)
    {_, result} = Document.put(result, "foo.2", 43)

    result = Document.convert(result, convert_numerically_indexed: true)

    assert %{"foo" => [42,43,43]} == result
  end

  test "Conversion of numerically-indexed objects to arrays using convert" do
    {_, result} = Document.new() |> Document.put("foo.0", 42)
    {_, result} = Document.put(result, "foo.1", 43)
    {_, result} = Document.put(result, "foo.2", 43)

    result = Document.convert(result, convert_numerically_indexed: true)
    assert %{"foo" => [42, 43, 43]} == result

  end

end