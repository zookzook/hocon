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


end