defmodule Ergo.ManyCommitTest do
  use ExUnit.Case

  alias Ergo
  import Ergo.{Terminals, Combinators, Meta}

  @moduledoc """
  A problem with the parser combinators in Ergo is that way that many swallows
  errors. The many combinator attempts to match another parser 0 or more times.
  If its parser fails it simply means "no more matches".

  But if we consider in particular the sequence parser that expects a specific
  series of other parsers to match. Here's a couple of examples:

  actor = sequence([
    literal("@actor"),
    ws(),
    id(),
    ws(),
    literal("begin"),
    ws(),
    actor_def(),
    ws(),
    literal("end")
  ])

  stage = sequence([
    literal("@stage"),
    ws(),
    id(),
    ws(),
    literal("begin"),
    ws(),
    stage_def(),
    ws(),
    literal("end")
  ])

  Now image we connect these using a choice:

  actor_or_stage = choice([
    actor(),
    stage()
  ])

  and that we expect many of these to be defined:

  actors_and_stages = many(actor_or_stage())

  If we feed this parser a particular kind of wrong input we can see where the
  problem occurs:

  parse("@actor ian_mckellen begin <<invalid>> end")

  The input is correct up to the 'begin' this is definitely an actor definition
  but something has been screwed up that causes the actor_def parser to fail.

  Clearly the stage parser cannot parse this input, it will fail too.

  The wrapping `many` parser will swallow this error and return :ok beacuse
  it will treat the error as "end of stream".

  This will leave the following parser with the "@actor …" input that *should
  have been parsed* already.

  Parsing is likely to fail at this parser but with an error that is confusing.

  We never see that `actor_def` didn't parse properly.

  Therefore we need a way to signal that a sequence has gotten so far that it
  should parse, but not completed and that this error should bubble up through
  many parsers.

  We introduce a new category of error `:fatal` which does not get ignored.
  """

  def mws() do
    ignore(many(ws()), label: "ws")
  end

  def actor(false) do
    sequence([
      literal("@actor"),
      mws(),
      literal("ian_mckellen"),
      mws(),
      literal("begin"),
      mws(),
      literal("IAN"),
      mws(),
      literal("MCKELLEN"),
      mws(),
      literal("end", label: "actor-end"),
      optional(mws(), label: "ows/1")
    ],
    label: "actor")
  end

  def actor(true) do
    sequence([
      literal("@actor"),
      mws(),
      commit(),
      literal("ian_mckellen"),
      mws(),
      literal("begin"),
      mws(),
      literal("IAN"),
      mws(),
      literal("MCKELLEN"),
      mws(),
      literal("end", label: "actor-end"),
      optional(mws(), label: "ows/1")
    ],
    label: "actor")
  end

  def stage(false) do
    sequence([
      literal("@stage"),
      mws(),
      literal("old_vic"),
      mws(),
      literal("begin"),
      mws(),
      literal("OLD"),
      mws(),
      literal("VIC"),
      mws(),
      literal("end", label: "stage-end"),
      optional(mws(), label: "ows/2")
    ],
    label: "stage")
  end

  def stage(true) do
    sequence([
      literal("@stage"),
      mws(),
      commit(),
      literal("old_vic"),
      mws(),
      literal("begin"),
      mws(),
      literal("OLD"),
      mws(),
      literal("VIC"),
      mws(),
      literal("end", label: "stage-end"),
      optional(mws(), label: "ows/2")
    ],
    label: "stage")
  end

  def actor_or_stage(commit) do
    choice([
      actor(commit),
      stage(commit)
    ],
    label: "actor_or_stage")
  end

  def actors_and_stages(commit) do
    many(actor_or_stage(commit), label: "actors_and_stages")
  end

  def theatre(commit) do
    sequence([
      literal("@theatre"),
      mws(),
      literal("begin"),
      mws(),
      actors_and_stages(commit),
      optional(mws(), label: "ows/3"),
      literal("end", label: "theatre-end"),
      optional(mws(), label: "ows/4")
    ],
    label: "theatre")
  end

  test "parses actor without commit" do
    input = """
@actor ian_mckellen begin
IAN MCKELLEN
end
"""

    assert %{status: :ok} = Ergo.parse(actor(false), input)
  end

  test "parses stage without commit" do
    input = """
@stage old_vic begin
  OLD VIC
end

"""

    assert %{status: :ok} = Ergo.parse(stage(false), input)
  end

  test "parses correct input without commit" do
    input = """
@theatre begin
  @actor ian_mckellen begin
    IAN MCKELLEN
  end

  @stage old_vic begin
    OLD VIC
  end
end
"""

    ctx = Ergo.parse(theatre(false), input)
    assert %{status: :ok} = ctx
  end

  test "fails on incorrect input without commit" do
    input = """
@theatre begin
  @actor ian_mckellen begin
    IAN MCKELLEN
  end

  @stage old_vic begin
    OLD VIC
  @end
end
"""

    # The failure is on line 8 where stage-end finds a "@" before the "end"
    # However the failure is reported at line 6 by theatre-end

    assert %{status: {:error, [{:bad_literal, {6, 3}, "theatre-end"}, _]}} = Ergo.parse(theatre(false), input)
  end

  test "fails correctly with commit" do
    input = """
@theatre begin
  @actor ian_mckellen begin
    IAN MCKELLEN
  end

  @stage old_vic begin
    OLD VIC
  @end
end
"""

    assert %{status: {:fatal, [{:bad_literal, {8, 3}, "stage-end"}, {:unexpected_char, {8, 3}, "Expected: e Actual: @"}]}} = Ergo.parse(theatre(true), input)
  end

end
