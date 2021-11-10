defmodule Ergo.CombinatorsTest do
  use ExUnit.Case
  @moduletag capture_log: true
  doctest Ergo.Combinators

  alias Ergo
  alias Ergo.{Combinators, Terminals}

  @doc """
  We had a case where we accidentally used the Kernel.binding function instead of a
  rule called binding_value. Kernel.binding returned an empty list which foxed the
  system which expected a Parser and not a List (empty or otherwise). Took me a while
  to figure out the mistake and track down where the [] was entering the system so
  now we'll validate lists of parsers.
  """
  test "Parsers should be valid" do

    assert_raise(RuntimeError, fn -> Combinators.sequence([]) end)
    assert_raise(RuntimeError, fn -> Combinators.sequence([1]) end)

    assert_raise(RuntimeError, fn -> Combinators.sequence([
      binding()
    ]) end)

    assert_raise(RuntimeError, fn -> Combinators.choice([
      Terminals.wc(),
      binding()
    ]) end)
  end

  test "traces sequence" do
    parser = Combinators.sequence([Terminals.digit(), Terminals.digit()], label: "2digits", debug: true)
    assert %{trace: ["[00] Try 2digits on: \"12\"", "[00] 2digits matched"]} = Ergo.parse(parser, "12")
  end
end
