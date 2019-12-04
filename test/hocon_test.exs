defmodule HoconTest do
  use ExUnit.Case, async: true

  alias Hocon.Parser
  alias Hocon.Tokenizer

#  test "file" do
#
#    {:ok, body} = File.read("./test/data/my-configuration.conf")
#    result = Parser.decode(body)
#
#    IO.puts inspect result
#
#    assert true
#  end

  test "Parse missing root curlys" do
    assert {:ok, %{"key" => "value"}} == Hocon.decode(~s(#test missing root curlys\n{key = value}))
    assert {:ok, %{"key" => "value"}} == Hocon.decode(~s({key = value}))
    assert {:ok, %{"key" => "value"}} == Hocon.decode(~s(key = value))
  end

  test "Contact unquoted strings to one string" do
    {:ok, ast} = Tokenizer.decode(~s({}))
    assert [:open_curly, :close_curly] == Parser.contact_rule(ast, [])

    {:ok, ast} = Tokenizer.decode(~s({a b c}))
    assert [:open_curly, {:unquoted_string, "a b c"}, :close_curly] == Parser.contact_rule(ast, [])

    {:ok, ast} = Tokenizer.decode(~s({a 3 c}))
    assert [:open_curly, {:unquoted_string, "a 3 c"}, :close_curly] == Parser.contact_rule(ast, [])

    {:ok, ast} = Tokenizer.decode(~s({1 3 c}))
    assert [:open_curly, {:unquoted_string, "1 3 c"}, :close_curly] == Parser.contact_rule(ast, [])
  end

  test "Parse simple array" do
    assert {:ok, %{"a" => [1, 2, 3, 4]}} == Hocon.decode(~s( a = [1,2,3,4,]))
    assert {:ok, %{"a" => [1, 2, 3, 4]}} == Hocon.decode(~s( a = [1,2,3,4]))
    assert {:ok, %{"a" => ["1 2 3 4"]}} == Hocon.decode(~s( a = [1 2 3 4]))
    assert {:ok, %{"a" => [1, 2, 3, 4]}} == Hocon.decode(~s( a = [1\n2\n3\n4]))
    assert {:ok, %{"a" => [1, 2, 3, 4]}} == Hocon.decode(~s( a = [1\n2\n3\n4\n]))
  end

  test "Parse simple object" do
    assert {:ok, %{"a" => 1, "b" => 3, "c" => 4}} == Hocon.decode(~s({a : 1, b : 2, b : 3, c : 4}))
    assert {:ok, %{"a" => 1, "b" => 3, "c" => 4}} == Hocon.decode(~s({a : 1\nb : 2\nb : 3\nc : 4}))
    assert {:ok, %{"a" => 1, "b" => 3, "c" => 4}} == Hocon.decode(~s({\na : 1\nb : 2\nb : 3\nc : 4\n}))
  end

  test "Parse nested objects" do
    assert {:ok, %{"a" => %{"b" => %{"c" => 1}}}} == Hocon.decode(~s({a : { b : { c : 1 }}}))
    assert {:ok, %{"a" => %{"b" => %{"c" => 1}}}} == Hocon.decode(~s({a { b { c : 1 }}}))
    assert {:ok, %{"1" => %{"2" => %{"3" => 1}}}} == Hocon.decode(~s({1 : { 2 : { 3 : 1 }}}))
    assert {:ok, %{"1" => %{"2" => %{"3" => 1}}}} == Hocon.decode(~s({1 { 2 { 3 : 1 }}}))
  end

  test "Parse configuration with BOM" do
    assert {:ok, %{"a" => %{"b" => %{"c" => 1}}}} == Hocon.decode(<<0xEF, 0xBB, 0xBF>> <> ~s({a : { b : { c : 1 }}}))
    assert {:ok, %{"a" => %{"b" => %{"c" => 1}}}} == Hocon.decode(<<0xEF, 0xBB, 0xBF>> <> ~s(a : { b : { c : 1 }}))
  end

  test "Parse paths as keys" do
    assert {:ok, %{"foo" => %{"bar" => 42}}} == Hocon.decode(~s(foo.bar : 42))
    assert {:ok, %{"foo" => %{"bar" => %{"baz" => 42}}}} == Hocon.decode(~s(foo.bar.baz : 42))
    assert {:ok, %{"3" => 42}} == Hocon.decode(~s(3 : 42))
    assert {:ok, %{"true" => 42}} == Hocon.decode(~s(true : 42))
    assert {:ok, %{"3" => %{"14" => 42}}} == Hocon.decode(~s(3.14 : 42))
  end

  test "Parse json" do
    assert {:ok, %{"foo" => %{ "baz" => "bar"}}} == Hocon.decode(~s({"foo": { "baz" : "bar"} }))
  end

  test "object merging" do
    assert {:ok, %{"foo" => %{"a" => 42, "b" => 43}}} == Hocon.decode(~s({"foo" : { "a" : 42 }, "foo" : { "b" : 43 }}))
    assert {:ok, %{"foo" => %{"b" => 43}}} == Hocon.decode(~s({"foo" : { "a" : 42 }, "foo" : null, "foo" : { "b" : 43 }}))
  end

  test "object concatenation" do
    assert {:ok, %{"a" => %{"b" => 1, "c" => 2}}} == Hocon.decode(~s(a : { b : 1 } { c : 2 }))
    assert {:ok, %{"a" => %{"b" => 1, "c" => 2, "d" => 3}}} == Hocon.decode(~s(a : { b : 1 } { c : 2 } { d : 3 }))
    assert {:ok, %{"a" => %{"b" => 1, "c" => 2}}} == Hocon.decode(~s(a : { b : 1 }\na : { c : 2 }))
  end

  test "array concatenation" do
     assert {:ok, %{"a" => [1, 2, 3, 4]}} == Hocon.decode(~s(a : [ 1, 2 ] [ 3, 4 ]))
     assert {:ok, %{"a" => [[1, 2, 3, 4]]}} == Hocon.decode(~s(a : [ [ 1, 2 ] [ 3, 4 ] ]))
     assert {:ok, %{"a" => [[1, 2], [3, 4]]}} == Hocon.decode(~s(a : [ [ 1, 2 ]\n[ 3, 4 ] ]))
  end

  test "String concatenation" do
    assert {:ok, %{"key" => "horse is my favorite animal"}} == Hocon.decode(~s(key : horse " is my favorite animal"))
    assert {:ok, %{"key" => "horse is my favorite animal"}} == Hocon.decode(~s(key : "horse " "is my favorite animal"))
    assert {:ok, %{"key" => "horse is my favorite animal"}} == Hocon.decode(~s(key : "horse " is my favorite animal))
  end

  test "Parsing substitutions" do
    assert {:ok, %{"key" => "${animal.favorite} is my favorite animal", "animal" => %{"favorite" => "dog"}}} == Hocon.decode(~s(animal { favorite : "dog" }, key : """${animal.favorite} is my favorite animal"""))
    assert {:ok, %{"key" => "dog is my favorite animal", "animal" => %{"favorite" => "dog"}}} == Hocon.decode(~s(animal { favorite : "dog" }, key : ${animal.favorite} is my favorite animal))
    assert {:ok, %{"key" => "dog is my favorite animal", "animal" => %{"favorite" => "dog"}}} == Hocon.decode(~s(animal { favorite : "dog" }, key : ${animal.favorite}" is my favorite animal"))
    assert catch_throw(Hocon.decode(~s(key : ${animal.favorite}" is my favorite animal"))) == {:not_found, "animal.favorite"}
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
  end

  test "Parsing json" do
    assert {:ok, %{"a" => %{"b" => "c"}}} == Hocon.decode(~s({"a" : { "b" : "c"}}))
    assert {:ok, %{"a" => [1, 2, 3, 4]}} == Hocon.decode(~s({"a" : [1,2,3,4]}))
    assert {:ok, %{"a" => "b", "c" => ["a", "b", "c"], "x" => 10.99}} == Hocon.decode(~s({"a" : "b", "c" : ["a", "b", "c"], "x" : 10.99}))
  end

  test "Parsing substitutions with cycles" do
    assert catch_throw(Hocon.decode(~s(bar : ${foo}\nfoo : ${bar}))) == {:circle_detected, "foo"}
    assert catch_throw(Hocon.decode(~s(a : ${b}\nb : ${c}\nc : ${a}))) == {:circle_detected, "b"}
    assert catch_throw(Hocon.decode(~s(a : 1\nb : 2\na : ${b}\nb : ${a}))) == {:circle_detected, "b"}
    assert catch_throw(Hocon.decode(~s(a : { b : ${a} }))) == {:circle_detected, "a"}
  end

  test "Parsing unquoted strings as values" do
    assert {:ok, %{"a" => "c"}} == Hocon.decode(~s({a : b\n a : c}))
  end
  test "Parsing quoted strings as keys" do
    assert {:ok, %{"a" => %{"b" => %{"c" => 1}}}} == Hocon.decode(~s({"a" { "b" { c : 1 }}}))
  end

end
