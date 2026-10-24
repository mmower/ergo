defmodule Ergo.ParserTest do
  use ExUnit.Case
  @moduletag capture_log: true
  doctest Ergo.Parser

  alias Ergo.Context
  import Ergo.{Terminals, Combinators}

  test "captures entry point line:col" do
    parser =
      sequence(
        [
          literal("begin"),
          many(ws()),
          literal("end")
        ],
        ctx: fn %Context{entry_points: [{entry_line, entry_col} | _]} = ctx ->
          Map.put(ctx, :test_entry_point, {entry_line, entry_col})
        end
      )

    %{status: status, test_entry_point: tep} = Ergo.parse(parser, "begin     end")

    assert :ok = status
    assert {1, 1} = tep
  end

  test "invoke restores parser, parsers and entry_points after parsing" do
    parser =
      sequence([
        literal("begin"),
        many(choice([ws(), literal("x")])),
        literal("end")
      ])

    ctx = Context.new("begin  xend")
    result = Ergo.Parser.invoke(ctx, parser)

    assert %Context{status: :ok} = result
    assert result.parser == ctx.parser
    assert result.parsers == ctx.parsers
    assert result.entry_points == ctx.entry_points
  end

  test "invoke restores bookkeeping when the parser fails" do
    parser = sequence([literal("begin"), literal("end")])

    ctx = Context.new("begin nope")
    result = Ergo.Parser.invoke(ctx, parser)

    assert %Context{status: {:error, _}} = result
    assert result.parser == ctx.parser
    assert result.parsers == ctx.parsers
    assert result.entry_points == ctx.entry_points
  end
end
