defmodule Ergo.Combinators do
  alias Ergo.{Context, Parser}
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

  # If any element of the parser list is not an Ergo.Parser, raise an exception.

  defp validate_parser(p) do
    if !is_struct(p, Ergo.Parser), do: raise "Non-parser passed to combinator: #{inspect(p)}"
  end

  defp validate_parsers(parsers) when is_list(parsers) do
    Enum.each(parsers, &validate_parser/1)
  end

  def parser_labels(parsers) when is_list(parsers) do
    parsers
    |> Enum.map(fn %Parser{label: label} -> label end)
    |> Enum.join(", ")
  end

  @doc ~S"""
  A ctx: function should be passed & return the whole context. It takes
  precendence over an ast: function that receives and returns a modified
  AST. Otherwise the identity function is returned.

  ## Examples
      iex> alias Ergo.Context
      iex> import Ergo.Combinators
      iex> f = mapping_fn(ctx: fn _ -> :kazam end)
      iex> assert :kazam = f.(%Context{})
  """
  def mapping_fn(opts) do
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
  The `choice/1` parser takes a list of parsers. It tries each in order attempting to match one. Once a match has been
  made choice returns the result of the matching parser.

  ## Examples

      iex> alias Ergo.Context
      iex> import Ergo.{Terminals, Combinators}
      iex> parser = choice([literal("Foo"), literal("Bar"), literal("Hello"), literal("World")], label: "Foo|Bar|Hello|World")
      iex> context = Ergo.parse(parser, "Hello World")
      iex> assert %Context{status: :ok, ast: "Hello", input: " World", index: 5, col: 6} = context

      iex> alias Ergo.Context
      iex> import Ergo.{Terminals, Combinators}
      iex> parser = choice([literal("Foo"), literal("Bar")], label: "Foo|Bar")
      iex> context = Ergo.parse(parser, "Hello World")
      iex> %Context{status: {:error, [{:no_valid_choice, "Foo|Bar cannot be applied"}]}, ast: nil, input: "Hello World"} = context
  """
  def choice(parsers, opts \\ []) when is_list(parsers) do
    if Enum.empty?(parsers), do: raise "Cannot define a choice() with zero parsers"
    if Enum.any?(parsers, fn e -> !is_struct(e, Ergo.Parser) end), do: raise "Passed non-parser to choice()"

    label = Keyword.get(opts, :label, "choice<#{parser_labels(parsers)}>")
    debug = Keyword.get(opts, :debug, false)
    map_fn = mapping_fn(opts)
    err_fn = Keyword.get(opts, :err, &Function.identity/1)

    validate_parsers(parsers)

    Parser.combinator(
      label,
      fn %Context{} = ctx ->
        ctx = Context.trace(ctx, debug, "____ CHO #{label} on: #{Context.clip(ctx)}")

        with %Context{status: :ok} = new_ctx <- apply_parsers_in_turn(parsers, ctx, label) do
          new_ctx
          |> map_fn.()
          |> Context.trace_match(debug, "____ CHO", label)
          map_fn.(new_ctx)
        else
          err_ctx ->
            err_ctx
            |> err_fn.()
            |> Context.trace_match(debug, "____ CHO", label)
        end
      end
    )
  end

  defp apply_parsers_in_turn(parsers, %Context{} = ctx, label) do
    Enum.reduce_while(
      parsers,
      Context.add_error(ctx, :no_valid_choice, "#{label} cannot be applied"),
      fn parser, %Context{} = ctx ->
        case Parser.invoke(parser, ctx) do
          %Context{status: :ok} = new_ctx ->
            #new_ctx = Context.trace(new_ctx, debug, "CHO + #{label} #{inspect(ast)}")
            {:halt, new_ctx}

          _ ->
            {:cont, ctx}
        end
      end
    )
  end

  @doc ~S"""

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
      iex> assert %Context{status: {:error, [{:bad_literal, _}, {:unexpected_char, _}]}} = Ergo.parse(parser, "Hello World")
  """
  def sequence(parsers, opts \\ [])

  def sequence(parsers, opts) when is_list(parsers) do
    if Enum.empty?(parsers), do: raise "Cannot define a sequence with no parsers"
    if Enum.any?(parsers, fn parser -> !is_struct(parser, Ergo.Parser) end), do: raise "Invalid parser in sequence"

    label = Keyword.get(opts, :label, "sequence<#{parser_labels(parsers)}>")
    debug = Keyword.get(opts, :debug, false)
    map_fn = mapping_fn(opts)
    err_fn = Keyword.get(opts, :err, &Function.identity/1)

    validate_parsers(parsers)

    Parser.combinator(
      label,
      fn %Context{} = ctx ->
        ctx = Context.trace(ctx, debug, "____ SEQ #{label} on: #{Context.clip(ctx)}")

        with %Context{status: :ok} = new_ctx <- sequence_reduce(parsers, ctx) do
          # We reject nils from the AST since they represent ignored values
          new_ctx
          |> Context.ast_without_ignored()
          |> Context.ast_in_parsed_order()
          |> map_fn.()
          |> Context.trace_match(debug, "____ SEQ", label)
        else
          err_ctx ->
            err_ctx
            |> err_fn.()
            |> Context.trace_match(debug, "____ SEQ", label)
        end
      end
    )
  end

  defp sequence_reduce(parsers, %Context{} = ctx) when is_list(parsers) do
    Enum.reduce_while(parsers, %{ctx | ast: []}, fn parser, ctx ->
      case Parser.invoke(parser, ctx) do
        %Context{status: :ok, ast: ast} = new_ctx -> {:cont, %{new_ctx | ast: [ast | ctx.ast]}}
        err_ctx -> {:halt, err_ctx}
      end
    end)
  end

  @doc """
  The hoist/1 parser takes a parser expected to return an AST which is a
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
  def hoist(parser) do
    Parser.combinator(
      "hoist",
      fn ctx ->
        with %Context{status: :ok, ast: [item | []]} = new_ctx <- Parser.invoke(parser, ctx) do
          %{new_ctx | ast: item}
        end
      end
    )
  end

  @doc ~S"""
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
      iex> assert %Context{status: {:error, [{:many_less_than_min, "5 < 6"}]}, ast: nil, input: " World", index: 5, col: 6} = context

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
    max = Keyword.get(opts, :max, :infinity)
    debug = Keyword.get(opts, :debug, false)

    map_fn = mapping_fn(opts)
    err_fn = Keyword.get(opts, :err, &Function.identity/1)

    Parser.combinator(
      label,
      fn %Context{} = ctx ->
        ctx = Context.trace(ctx, debug, "____ MNY #{label} on: #{Context.clip(ctx)}")

        with %Context{status: :ok} = new_ctx <- parse_many(parser, %{ctx | ast: []}, min, max, 0) do
          new_ctx
          |> Context.ast_without_ignored()
          |> Context.ast_in_parsed_order()
          |> map_fn.()
          |> Context.trace_match(debug, "MNY", label)
        else
          err_ctx ->
            err_ctx
            |> err_fn.()
            |> Context.trace_match(debug, "MNY", label)
        end
      end
    )
  end

  def parse_many(%Parser{} = parser, %Context{} = ctx, min, max, count)
      when is_integer(min) and min >= 0 and ((is_integer(max) and max > min) or max == :infinity) and
             is_integer(count) do
    case Parser.invoke(parser, ctx) do
      %Context{status: {:error, _}} ->
        if count < min do
          Context.add_error(ctx, :many_less_than_min, "#{count} < #{min}")
        else
          ctx
        end

      %Context{status: :ok} = new_ctx ->
        if max != :infinity && count == max - 1 do
          %{new_ctx | ast: [new_ctx.ast | ctx.ast]}
        else
          parse_many(parser, %{new_ctx | ast: [new_ctx.ast | ctx.ast]}, min, max, count + 1)
        end
    end
  end

  @doc ~S"""

  ## Examples

      iex> alias Ergo.Context
      iex> import Ergo.{Terminals, Combinators}
      iex> context = Ergo.parse(optional(literal("Hello")), "Hello World")
      iex> assert %Context{status: :ok, ast: "Hello", input: " World", index: 5, col: 6} = context

      In this example we deliberately ensure that the Context ast is not nil
      iex> alias Ergo.{Context, Parser}
      iex> import Ergo.{Terminals, Combinators}
      iex> context = Context.new(&Ergo.Parser.call/2, " World", ast: [])
      iex> parser = optional(literal("Hello"))
      iex> new_context = Parser.invoke(parser, context)
      iex> assert %Context{status: :ok, ast: nil, input: " World", index: 0, col: 1} = new_context
  """
  def optional(%Parser{} = parser, opts \\ []) do
    label = Keyword.get(opts, :label, "optional<#{parser.label}>")
    debug = Keyword.get(opts, :debug, false)
    map_fn = mapping_fn(opts)

    Parser.combinator(
      label,
      fn %Context{} = ctx ->
        ctx = Context.trace(ctx, debug, "____ OPT #{label} on: #{Context.clip(ctx)}")

        case Parser.invoke(parser, ctx) do
          %Context{status: :ok} = new_ctx ->
            new_ctx
            |> map_fn.()
            |> Context.trace_match(debug, "OPT", label)
          _ ->
            ctx
            |> Context.reset_status()
            |> Context.trace_match(debug, "OPT", label)
            %{ctx | status: :ok}
        end
      end
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
    debug = Keyword.get(opts, :debug, false)

    Parser.combinator(
      label,
      fn %Context{} = ctx ->
        ctx = Context.trace(ctx, debug, "____ IGN #{label} on: #{Context.clip(ctx)}")

        with %Context{status: :ok} = new_ctx <- Parser.invoke(parser, ctx) do
          %{new_ctx | ast: nil}
        end
      end
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
      "string<#{parser.label}>",
      fn ctx ->
        with %Context{status: :ok, ast: ast} = new_ctx <- Parser.invoke(parser, ctx) do
          %{new_ctx | ast: List.to_string(ast)}
        end
      end
    )
  end

  @doc """
  The string/1 parser takes a parser that returns an AST which is a string and
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
      "atom<#{parser.label}>",
      fn ctx ->
        with %Context{status: :ok, ast: ast} = new_ctx <- Parser.invoke(parser, ctx) do
          %{new_ctx | ast: String.to_atom(ast)}
        end
      end
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
  def transform(%Parser{} = parser, t_fn, opts \\ []) when is_function(t_fn) do
    label = Keyword.get(opts, :label, "transform<#{parser.label}>")
    debug = Keyword.get(opts, :debug, false)

    Parser.combinator(
      label,
      fn %Context{ast: ast} = ctx ->
        ctx = Context.trace(ctx, debug, "____ TRN #{label} on: #{inspect(ast)}")

        with %Context{status: :ok, ast: ast} = new_ctx <- Parser.invoke(parser, ctx) do
          new_ctx
          |> Context.ast_transform(t_fn)
          |> Context.trace(debug, "Output: #{inspect(ast)}")
        end
      end
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
      label,
      fn %Context{} = ctx ->
        with %Context{status: :ok} = new_ctx <- Parser.invoke(parser, ctx) do
          %{new_ctx | ast: replacement_value}
        end
      end
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
      iex> assert %Context{status: {:error, [{:lookahead_fail, _}, {:bad_literal, _}, {:unexpected_char, _}]}, index: 3, col: 4, input: "lo World"} = Ergo.parse(parser, "Hello World")
  """
  def lookahead(%Parser{} = parser, opts \\ []) do
    label = Keyword.get(opts, :label, "lookahead<#{parser.label}>")
    debug = Keyword.get(opts, :debug, false)

    Parser.combinator(
      label,
      fn %Context{} = ctx ->
        ctx = Context.trace(ctx, debug, "____ LAH #{label} on: #{Context.clip(ctx)}")
        case Parser.invoke(parser, ctx) do
          %Context{status: :ok} -> %{ctx | ast: nil}
          bad_ctx -> Context.add_error(bad_ctx, :lookahead_fail, "Could not satisfy: #{parser.label}")
          # %{bad_ctx | status: {:error, }, message: nil}
        end
      end
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
    iex> assert %Context{status: {:error, [{:lookahead_fail, "Satisfied: literal<Hello>"}]}, input: "Hello World"} = Ergo.parse(parser, "Hello World")
  """
  def not_lookahead(%Parser{} = parser, opts \\ []) do
    label = Keyword.get(opts, :label, "-lookahead<#{parser.label}>")
    debug = Keyword.get(opts, :debug, false)

    Parser.combinator(
      label,
      fn %Context{} = ctx ->
        ctx = Context.trace(ctx, debug, "____ NLA #{label} on: #{Context.clip(ctx)}")
        case Parser.invoke(parser, ctx) do
          %Context{status: {:error, _}} -> %{ctx | status: :ok}
          %Context{} -> Context.add_error(ctx, :lookahead_fail, "Satisfied: #{parser.label}")
        end
      end
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
      iex> assert %Context{status: {:error, [{:unsatisfied, "Failed to satisfy: digit char"}]}} = Ergo.parse(parser, "!")
      iex> parser = satisfy(number(), fn n -> Integer.mod(n, 2) == 0 end, label: "even number")
      iex> assert %Context{status: :ok, ast: 42} = Ergo.diagnose(parser, "42")
      iex> assert %Context{status: {:error, [{:unsatisfied, "Failed to satisfy: even number"}]}} = Ergo.parse(parser, "27")
  """
  def satisfy(%Parser{} = parser, pred_fn, opts \\ []) when is_function(pred_fn) do
    label = Keyword.get(opts, :label, "satisfy<#{parser.label}>")
    debug = Keyword.get(opts, :debug, false)

    Parser.combinator(
      label,
      fn %Context{} = ctx ->
        ctx = Context.trace(ctx, debug, "SAT #{label} on #{Context.clip(ctx)}")
        with %Context{status: :ok, ast: ast} = new_ctx <- Parser.invoke(parser, ctx) do
          if pred_fn.(ast) do
            new_ctx
          else
            Context.add_error(ctx, :unsatisfied, "Failed to satisfy: #{label}")
          end
        end
      end
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
        "lazy",
        fn ctx -> Parser.invoke(unquote(parser), ctx) end
      )
    end
  end

end
