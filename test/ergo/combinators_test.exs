defmodule Ergo.CombinatorsTest do
  use ExUnit.Case
  doctest Ergo.Combinators

  alias Ergo
  import Ergo.{Combinators, Terminals, Meta}

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

  describe "sequence parser partial AST" do
    test "sequence failure provides partial AST to error function" do
      # Test the original use case: attr_name: value parsing
      attr_name_parser = many(alpha(), min: 1) |> string()
      value_parser = many(alpha(), min: 1) |> string()
      
      parser = sequence([
        attr_name_parser,
        literal(":"),
        value_parser
      ], err: fn %{partial_ast: partial} = ctx ->
        case partial do
          [attr_name, ":"] ->
            Ergo.Context.add_error(ctx, :value_parse_failed, 
              "Failed to parse value for attribute '#{attr_name}'")
          [attr_name] ->
            Ergo.Context.add_error(ctx, :colon_missing, 
              "Expected ':' after attribute name '#{attr_name}'")
          _ ->
            ctx
        end
      end)

      # Test case where value parser fails (use non-alpha characters)
      result = Ergo.parse(parser, "myattr:123")
      assert [{:value_parse_failed, {1, 8}, "Failed to parse value for attribute 'myattr'"} | _] = 
        elem(result.status, 1)
      assert result.partial_ast == ["myattr", ":"]
      
      # Test case where colon is missing
      result = Ergo.parse(parser, "myattr 123")
      assert [{:colon_missing, {1, 7}, "Expected ':' after attribute name 'myattr'"} | _] = 
        elem(result.status, 1)
      assert result.partial_ast == ["myattr"]
    end

    test "sequence success clears partial AST" do
      parser = sequence([
        literal("hello"),
        literal(" "),
        literal("world")
      ])

      result = Ergo.parse(parser, "hello world")
      assert %{status: :ok, partial_ast: []} = result
    end

    test "simple sequence partial AST with failure" do
      parser = sequence([
        literal("first"),
        literal("second"),
        literal("third")
      ], err: fn %{partial_ast: partial} = ctx ->
        case partial do
          ["first", "second"] ->
            Ergo.Context.add_error(ctx, :third_failed, 
              "Failed to parse third element")
          ["first"] ->
            Ergo.Context.add_error(ctx, :second_failed, 
              "Failed to parse second element")
          _ ->
            ctx
        end
      end)

      result = Ergo.parse(parser, "firstsecondBAD")
      # Check that partial_ast contains the successfully parsed elements
      assert result.partial_ast == ["first", "second"]
      # The error function should be called
      assert [{:third_failed, {1, 12}, "Failed to parse third element"} | _] = 
        elem(result.status, 1)
    end

    test "sequence with commit preserves partial AST in fatal error" do
      parser = sequence([
        literal("start"),
        literal(":"),
        commit(),
        literal("end")
      ], err: fn %{partial_ast: partial} = ctx ->
        case partial do
          ["start", ":"] ->
            Ergo.Context.add_error(ctx, :end_expected, 
              "Expected 'end' after committed sequence")
          _ ->
            ctx
        end
      end)

      result = Ergo.parse(parser, "start:fail")
      assert [{:end_expected, {1, 7}, "Expected 'end' after committed sequence"} | _] = 
        elem(result.status, 1)
      assert result.partial_ast == ["start", ":"]
    end

    test "sequence partial AST includes ignored elements" do
      parser = sequence([
        literal("attr"),
        ignore(literal(":")),
        literal("value")
      ], err: fn %{partial_ast: partial} = ctx ->
        case partial do
          ["attr", nil] ->
            Ergo.Context.add_error(ctx, :value_missing, 
              "Expected value after 'attr:'")
          ["attr"] ->
            Ergo.Context.add_error(ctx, :colon_missing, 
              "Expected ':' after 'attr'")
          _ ->
            ctx
        end
      end)

      result = Ergo.parse(parser, "attr:fail")
      assert [{:value_missing, {1, 6}, "Expected value after 'attr:'"} | _] = 
        elem(result.status, 1)
      assert result.partial_ast == ["attr", nil]
    end

    test "single element sequence partial AST" do
      parser = sequence([
        literal("hello")
      ], err: fn %{partial_ast: _partial} = ctx ->
        # This should never be called since single element should succeed
        Ergo.Context.add_error(ctx, :unexpected_error, "Single element sequence failed")
      end)

      result = Ergo.parse(parser, "hello")
      assert %{status: :ok, partial_ast: []} = result
    end

    test "backward compatibility - error function without partial AST pattern still works" do
      parser = sequence([
        literal("hello"),
        literal(" "),
        literal("world")
      ], err: fn ctx ->
        # Old style error function that doesn't access partial_ast
        Ergo.Context.add_error(ctx, :old_style_error, "Old style error handling")
      end)

      result = Ergo.parse(parser, "hello fail")
      assert [{:old_style_error, {1, 7}, "Old style error handling"} | _] = 
        elem(result.status, 1)
      # partial_ast should still be set even if error function doesn't use it
      assert result.partial_ast == ["hello", " "]
    end
  end
end
