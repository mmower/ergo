defmodule Ergo.TerminalsTest do
  use ExUnit.Case
  doctest Ergo.Terminals

  describe "char test" do
    alias Ergo
    alias Ergo.Context
    import Ergo.Terminals

    test "fails with unexpected_eoi at end of input" do
      assert %Context{
               status: {:error, [{:unexpected_eoi, {1, 1}, "Unexpected end of input"}]},
               input: ""
             } =
               Ergo.parse(char([?a, ?b..?c]), "")
    end
  end

  describe "delimited_text/2" do
    alias Ergo
    alias Ergo.Context
    import Ergo.Terminals

    test "success: parses JSON blob" do
      parser = delimited_text(?{, ?})
      json = File.read!("test/support/delimited_text.json")
      epilogue = "blahblah"
      data = "#{json}#{epilogue}"
      assert %Context{status: :ok, ast: ^json, input: ^epilogue} = Ergo.parse(parser, data)
    end

    test "success: parses Javascript function body 1" do
      js_body = delimited_text(?{, ?})
      body = File.read!("test/support/js_body1.js")
      epilogue = "blahblah"
      data = "#{body}#{epilogue}"
      assert %Context{status: :ok, ast: ^body, input: ^epilogue} = Ergo.parse(js_body, data)
    end

    test "success: parses Javascript function body 2" do
      js_body = delimited_text(?{, ?})
      body = File.read!("test/support/js_body2.js")
      epilogue = "blahblah"
      data = "#{body}#{epilogue}"
      assert %Context{status: :ok, ast: ^body, input: ^epilogue} = Ergo.parse(js_body, data)
    end
  end

  test "adds errors properly" do
    alias Ergo.Context
    import Ergo.Terminals
    parser = literal("Hello")

    assert %Context{
             status:
               {:error,
                [
                  {:bad_literal, {1, 5}, "literal<Hello>"},
                  {:unexpected_char, {1, 5}, "Expected: |o| Actual: |x|"}
                ]},
             input: "x World",
             index: 4,
             line: 1,
             col: 5
           } = Ergo.parse(parser, "Hellx World")
  end

  describe "char/2 with a list" do
    alias Ergo.Context
    import Ergo.Terminals

    test "matches a literal character" do
      assert %Context{status: :ok} = Ergo.parse(char([?a, ?b]), "b")
    end

    test "matches a range" do
      assert %Context{status: :ok} = Ergo.parse(char([?a..?c]), "b")
    end

    test "negative entry matches any character except the negated one" do
      parser = char([-?a])
      assert %Context{status: :ok} = Ergo.parse(parser, "b")
      assert %Context{status: {:error, _}} = Ergo.parse(parser, "a")
    end

    test "fails when nothing matches" do
      assert %Context{status: {:error, _}} = Ergo.parse(char([?a, ?b..?c]), "z")
    end
  end
end
