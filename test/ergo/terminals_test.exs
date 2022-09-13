defmodule Ergo.TerminalsTest do
  use ExUnit.Case
  doctest Ergo.Terminals

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
    assert %Context{status: {:error, [{:bad_literal, {1, 5}, "literal<Hello>"}, {:unexpected_char, {1, 5}, "Expected: |o| Actual: |x|"}]}, input: "x World", index: 4, line: 1, col: 5} = Ergo.parse(parser, "Hellx World")
  end

end
