defmodule Parser.SubstitutionsTest do
  use ExUnit.Case, async: true

  test "Parsing substitutions" do
    assert {:ok, %{"key" => "${animal.favorite} is my favorite animal", "animal" => %{"favorite" => "dog"}}} == Hocon.decode(~s(animal { favorite : "dog" }, key : """${animal.favorite} is my favorite animal"""))
    assert {:ok, %{"key" => "dog is my favorite animal", "animal" => %{"favorite" => "dog"}}} == Hocon.decode(~s(animal { favorite : "dog" }, key : ${animal.favorite} is my favorite animal))
    assert {:ok, %{"key" => "dog is my favorite animal", "animal" => %{"favorite" => "dog"}}} == Hocon.decode(~s(animal { favorite : "dog" }, key : ${animal.favorite}" is my favorite animal"))
    assert catch_throw(Hocon.decode!(~s(key : ${animal.favorite}" is my favorite animal"))) == {:not_found, "animal.favorite"}
    assert {:ok, %{"key" => "Max limit is 10", "limit" => %{"max" => 10}}} == Hocon.decode(~s(limit { max : 10 }, key : Max limit is ${limit.max}))
    assert {:ok, %{"key" => "Max limit is ${limit.max}", "limit" => %{"max" => 10}}} == Hocon.decode(~s(limit { max : 10 }, key : """Max limit is ${limit.max}"""))
    assert {:ok, %{"key" => "Max limit is ${limit.max}", "limit" => %{"max" => 10}}} == Hocon.decode(~s(limit { max : 10 }, key : "Max limit is ${limit.max}"))
  end

  test "Parsing complex substitutions" do
    assert {:ok, %{"animal" => %{"favorite" => "dog"}, "a" => %{"b" => %{"c" => "dog"}}}} == Hocon.decode(~s(animal { favorite : "dog" }, a { b { c : ${animal.favorite}}}))
    assert {:ok, %{"bar" => %{"baz" => 42, "foo" => 42}}} == Hocon.decode(~s(bar : { foo : 42, baz : ${bar.foo}}))
    assert {:ok, %{"bar" => %{"baz" => 43, "foo" => 43}}} == Hocon.decode(~s(bar : { foo : 42, baz : ${bar.foo} }\nbar : { foo : 43 }))
    assert {:ok, %{"bar" => %{"a" => 4, "b" => 3}, "foo" => %{"c" => 3, "d" => 4}}} == Hocon.decode(~s(bar : { a : ${foo.d}, b : 1 }\nbar.b = 3\nfoo : { c : ${bar.b}, d : 2 }\nfoo.d = 4))
    assert {:ok, %{"a" => "2 2", "b" => 2}} == Hocon.decode(~s(a : ${b}, b : 2\n a : ${a} ${b}))
  end

  test "Parsing self-references substitutions" do
    assert {:ok, %{"foo" => %{"a" => 2, "c" => 1}}} == Hocon.decode(~s(foo : { a : { c : 1 } }\nfoo : ${foo.a}\nfoo : { a : 2 }))
    assert {:ok, %{"foo" => "1 2"}} == Hocon.decode(~s(foo : { bar : 1, baz : 2 }\nfoo : ${foo.bar} ${foo.baz}))
    assert {:ok, %{"foo" => "1 2", "baz" => 2}} == Hocon.decode(~s(baz : 2\nfoo : { bar : 1, baz : 2 }\nfoo : ${foo.bar} ${baz}))
    assert {:ok, %{"path" => "a:b:c:d"}} == Hocon.decode(~s(path : "a:b:c"\npath : ${path}":d"))
    assert catch_throw(Hocon.decode!(~s(foo : { bar : 1 }\nfoo : ${foo.bar} ${foo.baz}))) == {:not_found, "foo.foo.baz"}
  end

  test "Parsing substitutions with cycles" do
    assert catch_throw(Hocon.decode!(~s(bar : ${foo}\nfoo : ${bar}))) == {:circle_detected, "foo"}
    assert catch_throw(Hocon.decode!(~s(a : ${b}\nb : ${c}\nc : ${a}))) == {:circle_detected, "b"}
    assert catch_throw(Hocon.decode!(~s(a : 1\nb : 2\na : ${b}\nb : ${a}))) == {:circle_detected, "b"}
    assert catch_throw(Hocon.decode!(~s(a : { b : ${a} }))) == {:circle_detected, "a"}
    assert catch_throw(Hocon.decode!(~s(a : { b : ${x} }))) == {:not_found, "x"}
  end

  test "Parsing substitutions with environment variables" do
    System.put_env("MY_HOME", "/home/greta")
    assert {:ok, %{"path" => "/home/greta"}} == Hocon.decode(~s(path : ${MY_HOME}))
    System.put_env("MY_HOME", "/home")
    assert {:ok, %{"path" => "/home/greta"}} == Hocon.decode(~s(path : ${MY_HOME}\n path : ${path}"/greta"))
    assert {:ok, %{"path" => ["/home", "/usr/bin"]}} == Hocon.decode(~s(path : [${MY_HOME}]\n path : ${path} [ /usr/bin ]))
  end

  test "Parsing  += field separator" do
    assert {:ok, %{"a" => [1, "a"]}} == Hocon.decode(~s(a += 1\n a+= a))
    assert {:ok, %{"a" => [1, "a", 2, 3], "b" => 3}} == Hocon.decode(~s(b : 3, a += 1\n a+= a\n a += 2\n a += ${b}))
    assert {:ok, %{"b" => 3, "dic" => %{"a" => [1, "a", 2, 3]}}} == Hocon.decode(~s(b : 3, dic { a += 1\n a+= a\n a += 2\n a += ${b} }))
  end

  test "Parsing optional substitutions " do
    assert {:ok, %{"path" => ""}} == Hocon.decode(~s(path : ${?THE_HOME}))
    assert {:ok, %{"a" => [1, "a", 2, ""]}} == Hocon.decode(~s(a += 1\n a+= a\n a += 2\n a += ${?b}))
    assert {:ok, %{"bar" => %{"baz" => "", "fooz" => 42}}} == Hocon.decode(~s(bar : { fooz : 42, baz : ${?bar.foo}}))
  end

  test "Parsing substitutions by using assigns" do
    assigns = %{"THE_HOME" => "/home/hocon"}
    assert {:ok, %{"path" => "/home/hocon"}} == Hocon.decode(~s(path : ${?THE_HOME}), assigns: assigns)
  end
end
