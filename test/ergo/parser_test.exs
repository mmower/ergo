defmodule Ergo.ParserTest do
  use ExUnit.Case
  @moduletag capture_log: true
  doctest Ergo.Parser

  alias Ergo.Context
  import Ergo.{Terminals, Combinators}

  test "captures entry point line:col" do
    parser = sequence([
      literal("begin"),
      many(ws()),
      literal("end")
    ],
    ctx: fn %Context{entry_points: [{entry_line, entry_col} | _]} = ctx ->
      Map.put(ctx, :test_entry_point, {entry_line, entry_col})
    end)

    %{status: status, test_entry_point: tep} = Ergo.parse(parser, "begin     end")

    assert :ok = status
    assert {1, 1} = tep
  end
end
