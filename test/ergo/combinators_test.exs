defmodule Ergo.CombinatorsTest do
  use ExUnit.Case
  doctest Ergo.Combinators

  alias Ergo
  import Ergo.{Combinators, Terminals, Meta}
  alias Ergo.Context

  @doc """
  We had a case where we accidentally used the Kernel.binding function instead of a
  rule called binding_value. Kernel.binding returned an empty list which foxed the
  system which expected a Parser and not a List (empty or otherwise). Took me a while
  to figure out the mistake and track down where the [] was entering the system so
  now we'll validate lists of parsers.
  """
  test "Parsers should be valid" do
    assert_raise(RuntimeError, fn -> sequence([]) end)
    assert_raise(RuntimeError, fn -> sequence([1]) end)

    assert_raise(RuntimeError, fn ->
      sequence([
        binding()
      ])
    end)

    assert_raise(RuntimeError, fn ->
      choice([
        wc(),
        binding()
      ])
    end)
  end

  test "commit errors should break through" do
    p1 =
      sequence([
        literal("foo"),
        ws(),
        commit(),
        literal("bar")
      ])

    p2 =
      many(
        sequence([
          p1,
          optional(ws())
        ])
      )

    p3 =
      sequence([
        literal("["),
        p2,
        literal("]")
      ])

    assert %{
             status:
               {:fatal,
                [
                  {:bad_literal, {1, 16}, "literal<bar>"},
                  {:unexpected_char, {1, 16}, "Expected: |r| Actual: |x|"}
                ]}
           } = Ergo.parse(p3, "[foo bar foo bax]")
  end

  test "commit errors should cross choice boundary" do
    fake_case =
      sequence([
        literal("case"),
        ws(label: "ws1"),
        commit(),
        many(wc()),
        ws(label: "ws2"),
        literal("do"),
        ws(label: "ws3"),
        many(wc()),
        ws(label: "ws4"),
        literal("end")
      ],
      label: "case")

    fake_def =
      sequence([
        literal("def"),
        ws(label: "ws5"),
        commit(),
        many(wc()),
        ws(label: "ws6"),
        literal("do"),
        ws(label: "ws7"),
        many(wc()),
        ws(label: "ws8"),
        literal("end")
      ],
      label: "def")

    fake_expr =
      choice([
        fake_case,
        fake_def
      ], label: "expr")

    assert %{status: {:fatal, [{:unexpected_char, {1, 5}, _}]}} = Ergo.parse(fake_expr, "def # do foo end")
  end

  test "parses nil" do
    assert %Context{status: :ok, ast: nil} = Ergo.parse(replace(literal("nil"), nil), "nil")
  end

  test "hoisting an empty sequence returns nil" do
    empty_sequence = sequence([ignore(literal("1"))])

    assert %Context{status: :ok, ast: Ergo.Nil} = Ergo.parse(hoist(empty_sequence), "1")
  end
end
