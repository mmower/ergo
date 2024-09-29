defmodule Ergo.Combinators do
  alias Ergo.{Context, Parser, Telemetry}
  require Logger

  @moduledoc """
  `Ergo.Combinators` is the key set of parsers used for combining together other parsers.

  # Parsers

  * choice
  * sequence
  * many
  * optional
  * ignore
  * transform
  * lookeahead
  * not_lookahead

  """

  # Raises an exception if the passed argument is not a valid Parser struct
  defp validate_parser(p) do
    if !is_struct(p, Ergo.Parser), do: raise("Non-parser passed to combinator: #{inspect(p)}")
  end

  # Raises an exception if any element of the passed argument list is not a valid Parser struct
  defp validate_parsers(parsers) when is_list(parsers) do
    if Enum.empty?(parsers), do: raise("Passed empty parser list to combinator")
    Enum.each(parsers, &validate_parser/1)
  end

  # Gathers the labels from a list of Parsers and converts them into a string
  defp parser_labels(parsers) when is_list(parsers) do
    Enum.map_join(parsers, ", ", & &1.label)
  end

  # Given a keyword list representing options:
  # first looks for the `ctx:` option which is expected to be a function that
  # takes & returns a `Context.
  # next looks for the `ast:` option which is expected to be a function that
  # takes & returns an AST value. This is wrapped in a function that takes
  # a `Context` and returns a `Context` with the modified AST.
  # finally returns the identity function.
  # Allows the return to be safely put into into a Context based pipeline.
  defp mapping_fn(opts) do
    ctx_fn = Keyword.get(opts, :ctx)
    ast_fn = Keyword.get(opts, :ast)

    cond do
      is_function(ctx_fn) ->
        ctx_fn

      is_function(ast_fn) ->
        fn %Context{ast: ast} = ctx -> %{ctx | ast: ast_fn.(ast)} end

      true ->
        &Function.identity/1
    end
  end

  @doc ~S"""
  The `choice/2` parser takes a list of parsers and a list (defaults to []) of
  options. It tries to match each in turn, returning :ok if it does. Otherwise,
  if none match, it returns :error.

  Valid options are:
  * `label: "text"` a label output in debugging
    `ast: fn` a function passed the AST value for processing if the parser succeeds
    `ctx: fn` a function passed the `Context` for processing if the parser succeeds
    `err: fn` a function passed the `Context` for processing if the parser fails

  ## Examples

      iex> alias Ergo.Context
      iex> import Ergo.{Terminals, Combinators}
      iex> parser = choice([literal("Foo"), literal("Bar"), literal("Hello"), literal("World")], label: "Foo|Bar|Hello|World")
      iex> context = Ergo.parse(parser, "Hello World")
      iex> assert %Context{status: :ok, ast: "Hello", input: " World", index: 5, col: 6} = context

      iex> alias Ergo.Context
      iex> import Ergo.{Terminals, Combinators}
      iex> parser = choice([literal("Hello"), literal("World")], ast: &String.upcase/1)
      iex> context = Ergo.parse(parser, "Hello World")
      iex> assert %Context{status: :ok, ast: "HELLO"} = context

      iex> alias Ergo.Context
      iex> import Ergo.{Terminals, Combinators}
      iex> fun = fn %Context{ast: ast} = ctx -> %{ctx | ast: String.upcase(ast)} end
      iex> parser = choice([literal("Hello"), literal("World")], ctx: fun)
      iex> context = Ergo.parse(parser, "Hello World")
      iex> assert %Context{status: :ok, ast: "HELLO"} = context

      iex> alias Ergo.Context
      iex> import Ergo.{Terminals, Combinators}
      iex> parser = choice([literal("Foo"), literal("Bar")], label: "Foo|Bar")
      iex> context = Ergo.parse(parser, "Hello World")
      iex> %Context{status: {:error, [{:no_valid_choice, {1, 1}, "Foo|Bar did not find a valid choice"}]}, ast: nil, input: "Hello World"} = context
  """
  def choice(parsers, opts \\ []) when is_list(parsers) do
    validate_parsers(parsers)

    label = Keyword.get(opts, :label, "choice<#{parser_labels(parsers)}>")
    map_fn = mapping_fn(opts)
    err_fn = Keyword.get(opts, :err, &Function.identity/1)

    Parser.combinator(
      :choice,
      label,
      fn %Context{} = ctx ->
        case apply_parsers_in_turn(parsers, ctx, label) do
          %Context{status: :ok} = ok_ctx ->
            map_fn.(ok_ctx)

          %Context{} = err_ctx ->
            err_fn.(err_ctx)
        end
      end,
      child_info: Parser.child_info_for_telemetry(parsers)
    )
  end

  defp apply_parsers_in_turn(parsers, %Context{} = ctx, label) do
    Enum.reduce_while(
      parsers,
      Context.add_error(ctx, :no_valid_choice, "#{label} did not find a valid choice"),
      fn %Parser{} = parser, %Context{} = ctx ->
        case Parser.invoke(ctx, parser) do
          %Context{status: :ok} = new_ctx ->
            {:halt, new_ctx}

          %Context{status: {:error, _}} ->
            {:cont, ctx}

          %Context{status: {:fatal, _}} = fatal_ctx ->
            {:halt, fatal_ctx}
        end
      end
    )
  end

  @doc ~S"""
  The `sequence/2` parser takes a list of parsers which are applied in turn.
  If any of the parsers fails the sequence itself fails.

  The `sequence/2` parser treats the `commit/0` parser differently. When it
  sees commit it increments the contexts commit count. When the parser
  is complete, if it has increased the commit count it decrements it before
  returning it. See also `many`

  ## Examples

      iex> alias Ergo.Context
      iex> import Ergo.{Terminals, Combinators}
      iex> parser = sequence([literal("Hello"), ws(), literal("World")])
      iex> context = Ergo.parse(parser, "Hello World")
      %Context{status: :ok, ast: ["Hello", ?\s, "World"], index: 11, line: 1, col: 12} = context

      This test will need to be rewritten in terms of Ergo.diagnose
      # iex> Logger.disable(self())
      # iex> alias Ergo.Context
      # iex> import Ergo.{Terminals, Combinators}
      # iex> parser = sequence([literal("Hello"), ws(), literal("World")], label: "HelloWorld")
      # iex> context = Ergo.parse(parser, "Hello World")
      # iex> assert %Context{status: :ok, ast: ["Hello", ?\s, "World"], index: 11, line: 1, col: 12} = context

      iex> alias Ergo.Context
      iex> import Ergo.{Terminals, Combinators}
      iex> parser = sequence([literal("Hello"), ws(), literal("World")], ast: fn ast -> Enum.join(ast, " ") end)
      iex> context = Ergo.parse(parser, "Hello World")
      iex> assert %Context{status: :ok, ast: "Hello 32 World", index: 11, line: 1, col: 12} = context

      This test will need to be rewritten in terms of Ergo.diagnose
      # iex> Logger.disable(self())
      # iex> alias Ergo.Context
      # iex> import Ergo.{Terminals, Combinators}
      # iex> parser = sequence([literal("Hello"), ws(), literal("World")], label: "HelloWorld", ast: fn ast -> Enum.join(ast, " ") end)
      # iex> context = Ergo.parse(parser, "Hello World")
      # iex> assert %Context{status: :ok, ast: "Hello 32 World", index: 11, line: 1, col: 12} = context

      iex> alias Ergo.Context
      iex> import Ergo.{Combinators, Terminals}
      iex> parser = sequence([literal("foo"), ws(), literal("bar")])
      iex> assert %Context{status: {:error, [{:bad_literal, _, _}, {:unexpected_char, _, _}]}} = Ergo.parse(parser, "Hello World")
  """
  def sequence(parsers, opts \\ [])

  def sequence(parsers, opts) when is_list(parsers) do
    validate_parsers(parsers)

    label = Keyword.get(opts, :label, "sequence<#{parser_labels(parsers)}>")
    map_fn = mapping_fn(opts)
    err_fn = Keyword.get(opts, :err, &Function.identity/1)

    Parser.combinator(
      :sequence,
      label,
      fn %Context{} = ctx ->
        case sequence_reduce(parsers, ctx) do
          %Context{status: :ok} = ok_ctx ->
            ok_ctx
            # We remove nils from the AST since they represent ignored values
            |> Context.ast_without_ignored()
            |> Context.ast_in_parsed_order()
            |> map_fn.()

          %Context{} = err_ctx ->
            err_fn.(err_ctx)
        end
      end,
      child_info: Parser.child_info_for_telemetry(parsers)
    )
  end

  defp sequence_reduce(parsers, %Context{} = ctx) when is_list(parsers) do
    # In this code we pass around a tuple
    # {commited, ctx}
    # Committed is a flag which is set to false at the beginning of the reduce
    # that indicates whether a commit has happened within *this* sequence.
    #
    case sequence_reduce_inner(parsers, Context.set_ast(ctx, [])) do
      {false, reduced_ctx} ->
        reduced_ctx

      {true, reduced_ctx} ->
        Context.uncommit(reduced_ctx)
    end
  end

  defp sequence_reduce_inner(parsers, ctx) do
    Enum.reduce_while(parsers, {false, ctx}, fn
      %{type: :commit}, {_, ctx} ->
        # We don't need to invoke the commit parser, just recognise that
        # we have seen it, -> {true, _}
        {:cont, {true, Context.commit(ctx)}}

      parser, {committed, ctx} ->
        case {Parser.invoke(ctx, parser), committed} do
          {%Context{status: :ok, ast: child_ast} = ok_ctx, _} ->
            # Return the new CTX but prepend the child AST to the old AST
            {:cont, {committed, %{ok_ctx | ast: [child_ast | ctx.ast]}}}

          {%Context{status: {:fatal, _}} = fatal_ctx, _} ->
            {:halt, {committed, fatal_ctx}}

          {%Context{status: {:error, _}, commit: commit_level} = fatal_ctx, true}
          when commit_level > 0 ->
            # Error when committed, convert to fatal error
            fatal_ctx = Context.make_error_fatal(fatal_ctx)

            Telemetry.event(fatal_ctx, :fatal, %{
              info: "Error while commit_level > 0",
              status: fatal_ctx.status
            })

            {:halt, {true, fatal_ctx}}

          {%Context{status: {:error, _}} = err_ctx, false} ->
            # Regular error, halt and report back
            {:halt, {false, err_ctx}}
        end
    end)
  end

  @doc """
  The `hoist/1` parser takes a parser expected to return an AST which is a
  1-item list. The returned parser extracts the item from the list and
  returns an AST of just that item.

  This often comes up with the sequence/2 parser and ignore, where all but
  one item in a sequence are ignored. Using hoist pulls that item up so that
  subsequent parsers don't need to deal with the list.

  # Examples
      iex> alias Ergo
      iex> alias Ergo.Context
      iex> import Ergo.{Terminals, Combinators}
      iex> parser = sequence([ignore(many(char(?a))), char(?b)]) |> hoist()
      iex> assert %Context{status: :ok, ast: ?b} = Ergo.parse(parser, "aaaaaaaab")
  """
  def hoist(%Parser{} = parser) do
    Parser.combinator(
      :hoist,
      "hoist",
      fn ctx ->
        with %Context{status: :ok} = ok_ctx <- Parser.invoke(ctx, parser) do
          ok_ctx
          |> Context.ast_transform(fn ast -> List.first(ast) end)
        end
      end,
      child_info: Parser.child_info_for_telemetry(parser)
    )
  end

  @doc ~S"""
  The `many/2` parser takes a parser and attempts to match it on the input
  multiple (including possibly zero) times. Accepts options `min:` and `max:`
  to modify how many times the included parser must match for `many` to
  match.

  ## Examples

      This test will need to be rewritten in terms of Ergo.diganose
      # iex> Logger.disable(self())
      # iex> alias Ergo.Context
      # iex> import Ergo.{Combinators, Terminals}
      # iex> parser = many(wc(), label: "Chars")
      # iex> context = Ergo.parse(parser, "Hello World")
      # iex> assert %Context{status: :ok, ast: [?H, ?e, ?l, ?l, ?o], input: " World", index: 5, col: 6, char: ?o} = context

      iex> alias Ergo.Context
      iex> import Ergo.{Combinators, Terminals}
      iex> parser = many(wc(), min: 6)
      iex> context = Ergo.parse(parser, "Hello World")
      iex> assert %Context{status: {:error, [{:many_less_than_min, {1, 6}, "5 < 6"}]}, ast: nil, input: " World", index: 5, col: 6} = context

      iex> alias Ergo.{Context, Parser}
      iex> import Ergo.{Combinators, Terminals}
      iex> parser = many(wc(), max: 3)
      iex> context = Ergo.parse(parser, "Hello World")
      iex> assert %Context{status: :ok, ast: [?H, ?e, ?l], input: "lo World", index: 3, col: 4} = context

      iex> alias Ergo.{Context, Parser}
      iex> import Ergo.{Combinators, Terminals}
      iex> parser = many(wc(), ast: &Enum.count/1)
      iex> context = Ergo.parse(parser, "Hello World")
      iex> assert %Context{status: :ok, ast: 5, input: " World", index: 5, col: 6} = context
  """
  def many(parser, opts \\ [])

  def many(%Parser{} = parser, opts) do
    label = Keyword.get(opts, :label, "many<#{parser.label}>")

    min = Keyword.get(opts, :min, 0)
    if min < 0, do: raise("Cannot specify negative min value")
    max = Keyword.get(opts, :max, :infinity)
    if max != :infinity && max < min, do: raise("Cannot specify min less than max")

    map_fn = mapping_fn(opts)
    err_fn = Keyword.get(opts, :err, &Function.identity/1)

    Parser.combinator(
      :many,
      label,
      fn %Context{} = ctx ->
        case parse_many(parser, Context.set_ast(ctx, []), min, max, 0) do
          %{status: :ok} = ok_ctx ->
            ok_ctx
            |> Context.ast_without_ignored()
            |> Context.ast_in_parsed_order()
            |> map_fn.()

          err_ctx ->
            err_fn.(err_ctx)
        end
      end,
      min: min,
      max: max,
      child_info: Parser.child_info_for_telemetry(parser)
    )
  end

  def parse_many(%Parser{} = parser, %Context{} = ctx, min, max, count)
      when is_integer(min) and min >= 0 and ((is_integer(max) and max > min) or max == :infinity) and
             is_integer(count) do
    case Parser.invoke(ctx, parser) do
      %Context{status: {:fatal, _}} = fatal_ctx ->
        fatal_ctx

      %Context{status: {:error, _}} = err_ctx ->
        Telemetry.result(err_ctx)

        if count < min do
          ctx
          |> Context.add_error(:many_less_than_min, "#{count} < #{min}")
          |> Telemetry.result()
        else
          # We're returning ctx which must have status: :ok, not "new_ctx" which
          # will have status: {:error, _} this is the normal bail out
          ctx
          |> Telemetry.event("BAIL")
        end

      %Context{status: :ok} = new_ctx ->
        if max != :infinity && count == max - 1 do
          %{new_ctx | ast: [new_ctx.ast | ctx.ast]}
        else
          Telemetry.event(new_ctx, "RECUR")
          parse_many(parser, %{new_ctx | ast: [new_ctx.ast | ctx.ast]}, min, max, count + 1)
        end
    end
  end

  @doc ~S"""
  The optional/2 parser takes a parser and attempts to match it and succeeds
  whether or not it can.

  ## Examples

      iex> alias Ergo.Context
      iex> import Ergo.{Terminals, Combinators}
      iex> ctx = Ergo.parse(optional(literal("Hello")), "Hello World")
      iex> assert %Context{status: :ok, ast: "Hello", input: " World", index: 5, col: 6} = ctx

      In this example we deliberately ensure that the Context ast is not nil
      iex> alias Ergo.{Context, Parser}
      iex> import Ergo.{Terminals, Combinators}
      iex> ctx = Context.new(" World", ast: [])
      iex> parser = optional(literal("Hello"))
      iex> new_context = Parser.invoke(ctx, parser)
      iex> assert %Context{status: :ok, ast: nil, input: " World", index: 0, col: 1} = new_context
  """
  def optional(%Parser{} = parser, opts \\ []) do
    label = Keyword.get(opts, :label, "optional<#{parser.label}>")
    map_fn = mapping_fn(opts)

    Parser.combinator(
      :optional,
      label,
      fn %Context{} = ctx ->
        case Parser.invoke(ctx, parser) do
          %Context{status: :ok} = match_ctx ->
            match_ctx
            |> map_fn.()

          %Context{status: {:fatal, _}} = fatal_ctx ->
            fatal_ctx
            |> Telemetry.result()

          %Context{status: {:error, _}} = err_ctx ->
            Telemetry.result(err_ctx)

            ctx
            |> Context.reset_status()
            |> Telemetry.event("BAIL")
        end
      end,
      child_info: Parser.child_info_for_telemetry(parser)
    )
  end

  @doc ~S"""
  The ignore/1 parser matches but ignores the AST of its child parser.

  ## Examples

      iex> alias Ergo.Context
      iex> import Ergo.{Terminals, Combinators}
      iex> parser = sequence([literal("Hello"), ignore(ws()), literal("World")])
      iex> context = Ergo.parse(parser, "Hello World")
      iex> assert %Context{status: :ok, ast: ["Hello", "World"], index: 11, col: 12} = context
  """
  def ignore(%Parser{} = parser, opts \\ []) do
    label = Keyword.get(opts, :label, "ignore<#{parser.label}>")

    Parser.combinator(
      :ignore,
      label,
      fn %Context{} = ctx ->
        with %Context{status: :ok} = new_ctx <- Parser.invoke(ctx, parser) do
          %{new_ctx | ast: nil}
        end
      end,
      child_info: Parser.child_info_for_telemetry(parser)
    )
  end

  @doc """
  The string/1 parser takes a parser that returns an AST which is a list of characters
  and converts the AST into a string.

  # Examples
      iex> alias Ergo
      iex> alias Ergo.Context
      iex> import Ergo.{Terminals, Combinators}
      iex> parser = many(alpha()) |> string()
      iex> assert %Context{status: :ok, ast: "FourtyTwo"} = Ergo.parse(parser, "FourtyTwo")
  """
  def string(%Parser{} = parser) do
    Parser.combinator(
      :string_transform,
      "string<#{parser.label}>",
      fn ctx ->
        with %Context{status: :ok} = match_ctx <- Parser.invoke(ctx, parser) do
          match_ctx
          |> Context.ast_transform(&List.to_string/1)
        end
      end,
      child_info: Parser.child_info_for_telemetry(parser)
    )
  end

  @doc """
  The atom/1 parser takes a parser that returns an AST which is a string and
  converts the AST into an atom.

  # Examples
      iex> alias Ergo
      iex> alias Ergo.Context
      iex> import Ergo.{Terminals, Combinators}
      iex> parser = many(wc()) |> string() |> atom()
      iex> assert %Context{status: :ok, ast: :fourty_two} = Ergo.parse(parser, "fourty_two")
  """
  def atom(%Parser{} = parser) do
    Parser.combinator(
      :atom_transform,
      "atom<#{parser.label}>",
      fn ctx ->
        with %Context{status: :ok} = match_ctx <- Parser.invoke(ctx, parser) do
          match_ctx
          |> Context.ast_transform(&String.to_atom/1)
        end
      end,
      child_info: Parser.child_info_for_telemetry(parser)
    )
  end

  @doc ~S"""
  The `transform/2` parser runs a transforming function on the AST of its child parser.

  ## Examples

      # Sum the digits
      iex> alias Ergo.Context
      iex> import Ergo.{Combinators, Terminals}
      iex> digit_to_int = fn d -> List.to_string([d]) |> String.to_integer() end
      iex> t_fn = fn ast -> ast |> Enum.map(digit_to_int) |> Enum.sum() end
      iex> parser = sequence([digit(), digit(), digit(), digit()]) |> transform(t_fn)
      iex> context = Ergo.parse(parser, "1234")
      iex> %Context{status: :ok, ast: 10, index: 4, line: 1, col: 5} = context
  """
  def transform(%Parser{} = parser, transformer_fn, opts \\ [])
      when is_function(transformer_fn) do
    label = Keyword.get(opts, :label, "transform<#{parser.label}>")

    Parser.combinator(
      :transform,
      label,
      fn %Context{} = ctx ->
        with %Context{status: :ok} = match_ctx <- Parser.invoke(ctx, parser) do
          match_ctx
          |> Context.ast_transform(transformer_fn)
        end
      end,
      child_info: Parser.child_info_for_telemetry(parser)
    )
  end

  @doc ~S"""
  The replace/3 combinator replaces the AST value of it's child with a constant.

  ## Examples
      iex> alias Ergo.Context
      iex> alias Ergo
      iex> import Ergo.{Combinators, Terminals}
      iex> parser = ignore(literal("foo")) |> replace(:foo)
      iex> assert %Context{status: {:error, _}} = Ergo.parse(parser, "flush")
  """
  def replace(%Parser{} = parser, replacement_value, opts \\ []) do
    label = Keyword.get(opts, :label, "replace<#{parser.label}>")

    Parser.combinator(
      :replace,
      label,
      fn %Context{} = ctx ->
        Telemetry.enter(ctx)

        with %Context{status: :ok} = match_ctx <- Parser.invoke(ctx, parser) do
          match_ctx
          |> Context.ast_transform(fn _ast -> replacement_value end)
        end
      end,
      child_info: Parser.child_info_for_telemetry(parser)
    )
  end

  @doc ~S"""
  The `lookahead` parser accepts a parser and matches it but does not update the context when it succeeds.

  ## Example

      iex> alias Ergo.Context
      iex> import Ergo.{Combinators, Terminals}
      iex> parser = lookahead(literal("Hello"))
      iex> assert %Context{status: :ok, ast: nil, input: "Hello World", index: 0} = Ergo.parse(parser, "Hello World")

      iex> alias Ergo.Context
      iex> import Ergo.{Combinators, Terminals}
      iex> parser = lookahead(literal("Helga"))
      iex> assert %Context{status: {:error, [{:lookahead_fail, {1, 4}, _}, {:bad_literal, {1, 4}, _}, {:unexpected_char, {1, 4}, _}]}, index: 3, col: 4, input: "lo World"} = Ergo.parse(parser, "Hello World")
  """
  def lookahead(%Parser{} = parser, opts \\ []) do
    label = Keyword.get(opts, :label, "lookahead<#{parser.label}>")

    Parser.combinator(
      :lookahead,
      label,
      fn %Context{} = ctx ->
        case Parser.invoke(ctx, parser) do
          %Context{status: :ok} ->
            ctx
            |> Context.reset_status()

          %Context{status: {:fatal, _}} = fatal_ctx ->
            fatal_ctx

          %Context{status: {:error, _}} = err_ctx ->
            err_ctx
            |> Context.add_error(:lookahead_fail, "Could not satisfy: #{parser.label}")
        end
      end,
      child_info: Parser.child_info_for_telemetry(parser)
    )
  end

  @doc ~S"""
  The `not_lookahead` parser accepts a parser and attempts to match it. If the match fails the not_lookahead parser returns status: :ok but does not affect the context otherwise.

  If the match succeeds the `not_lookahead` parser fails with {:error, :lookahead_fail}

  ## Examples

    iex> alias Ergo.Context
    iex> import Ergo.{Combinators, Terminals}
    iex> parser = not_lookahead(literal("Foo"))
    iex> assert %Context{status: :ok, input: "Hello World"} = Ergo.parse(parser, "Hello World")

    iex> alias Ergo.{Context, Parser}
    iex> import Ergo.{Combinators, Terminals}
    iex> parser = not_lookahead(literal("Hello"))
    iex> assert %Context{status: {:error, [{:lookahead_fail, {1,6}, "Satisfied: literal<Hello>"}]}, input: " World"} = Ergo.parse(parser, "Hello World")
  """
  def not_lookahead(%Parser{} = parser, opts \\ []) do
    label = Keyword.get(opts, :label, "-lookahead<#{parser.label}>")

    Parser.combinator(
      :not_lookahead,
      label,
      fn %Context{} = ctx ->
        case Parser.invoke(ctx, parser) do
          %Context{status: {:fatal, _}} = fatal_ctx ->
            fatal_ctx

          %Context{status: {:error, _}} = err_ctx ->
            Telemetry.result(err_ctx)

            ctx
            |> Context.reset_status()

          %Context{status: :ok} = ok_ctx ->
            ok_ctx
            |> Context.add_error(:lookahead_fail, "Satisfied: #{parser.label}")
        end
      end,
      child_info: Parser.child_info_for_telemetry(parser)
    )
  end

  @doc """
  The satisfy/3 parser takes a parser and a predicate function. If the parser
  is successful the AST is passed to the predicate function. If the predicate
  function returns true the parser returns the successful context, otherwise
  an error context is returned.

  # Example
      iex> alias Ergo.Context
      iex> import Ergo.{Terminals, Combinators, Numeric}
      iex> parser = satisfy(any(), fn char -> char in (?0..?9) end, label: "digit char")
      iex> assert %Context{status: :ok, ast: ?4} = Ergo.parse(parser, "4")
      iex> assert %Context{status: {:error, [{:unsatisfied, {1, 1}, "Failed to satisfy: digit char"}]}} = Ergo.parse(parser, "!")
      iex> parser = satisfy(number(), fn n -> Integer.mod(n, 2) == 0 end, label: "even number")
      iex> assert %Context{status: :ok, ast: 42} = Ergo.parse(parser, "42")
      iex> assert %Context{status: {:error, [{:unsatisfied, {1, 1}, "Failed to satisfy: even number"}]}} = Ergo.parse(parser, "27")
  """
  def satisfy(%Parser{} = parser, pred_fn, opts \\ []) when is_function(pred_fn) do
    label = Keyword.get(opts, :label, "satisfy<#{parser.label}>")

    Parser.combinator(
      :satisfy,
      label,
      fn %Context{} = ctx ->
        with %Context{status: :ok, ast: ast} = ok_ctx <- Parser.invoke(ctx, parser) do
          if pred_fn.(ast) do
            ok_ctx
            # |> Telemetry.match()
          else
            ctx
            |> Context.add_error(:unsatisfied, "Failed to satisfy: #{label}")

            # |> Telemetry.error()
          end
        end
      end,
      child_info: Parser.child_info_for_telemetry(parser)
    )
  end

  @doc """
  The lazy/1 parser is intended for use in cases where constructing parsers
  creates a recursive call. By using `lazy` the original parser call is
  deferred until later, breaking the infinite recursion.
  """
  defmacro lazy(parser) do
    quote do
      Parser.combinator(
        :lazy,
        "lazy",
        fn ctx ->
          Parser.invoke(ctx, unquote(parser))
        end
      )
    end
  end
end
