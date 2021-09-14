defmodule Ergo.Combinators do
  alias Ergo.{Context, Parser}
  import Ergo.Utils, only: [ellipsize: 2]
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
      iex> parser = choice([literal("Foo"), literal("Bar")])
      iex> context = Ergo.parse(parser, "Hello World")
      iex> %Context{status: {:error, :no_valid_choice}, message: "No valid choice", ast: nil, input: "Hello World"} = context
  """
  def choice(parsers, opts \\ []) when is_list(parsers) do
    label = Keyword.get(opts, :label, "#")
    map_fn = Keyword.get(opts, :map, &Function.identity/1)

    validate_parsers(parsers)

    Parser.new(
      :choice,
      fn %Context{debug: debug, input: input} = ctx ->
        if debug, do: Logger.info("Trying Choice<#{label}> on [#{ellipsize(input, 20)}]")

        with %Context{status: :ok} = new_ctx <- apply_parsers_in_turn(parsers, ctx) do
          %{new_ctx | ast: map_fn.(new_ctx.ast)}
        end
      end,
      combinator: true,
      label: label
    )
  end

  defp apply_parsers_in_turn(parsers, ctx) do
    Enum.reduce_while(
      parsers,
      %{ctx | status: {:error, :no_valid_choice}, message: "No valid choice", ast: nil},
      fn parser, %Context{debug: debug} = ctx ->
        case Parser.invoke(parser, ctx) do
          %Context{status: :ok, ast: ast} = new_ctx ->
            if debug, do: Logger.info("<-- Choice: [#{inspect(ast)}]")
            {:halt, %{new_ctx | message: nil}}

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
      # iex> context = Ergo.parse(parser, "Hello World", debug: true)
      # iex> assert %Context{status: :ok, debug: true, ast: ["Hello", ?\s, "World"], index: 11, line: 1, col: 12} = context

      iex> alias Ergo.Context
      iex> import Ergo.{Terminals, Combinators}
      iex> parser = sequence([literal("Hello"), ws(), literal("World")], map: fn ast -> Enum.join(ast, " ") end)
      iex> context = Ergo.parse(parser, "Hello World")
      iex> assert %Context{status: :ok, ast: "Hello 32 World", index: 11, line: 1, col: 12} = context

      This test will need to be rewritten in terms of Ergo.diagnose
      # iex> Logger.disable(self())
      # iex> alias Ergo.Context
      # iex> import Ergo.{Terminals, Combinators}
      # iex> parser = sequence([literal("Hello"), ws(), literal("World")], label: "HelloWorld", map: fn ast -> Enum.join(ast, " ") end)
      # iex> context = Ergo.parse(parser, "Hello World", debug: true)
      # iex> assert %Context{status: :ok, debug: true, ast: "Hello 32 World", index: 11, line: 1, col: 12} = context

      iex> alias Ergo.Context
      iex> import Ergo.{Combinators, Terminals}
      iex> parser = sequence([literal("foo"), ws(), literal("bar")])
      iex> assert %Context{status: {:error, :unexpected_char}} = Ergo.parse(parser, "Hello World")
  """
  def sequence(parsers, opts \\ [])

  def sequence(parsers, opts) when is_list(parsers) do
    label = Keyword.get(opts, :label, "#")
    map_fn = Keyword.get(opts, :map, nil)

    validate_parsers(parsers)

    Parser.new(
      :sequence,
      fn %Context{debug: debug, input: input} = ctx ->
        if debug, do: Logger.info("Trying Sequence<#{label}> on [#{ellipsize(input, 20)}]")

        with %Context{status: :ok} = new_ctx <- sequence_reduce(parsers, ctx) do
          if debug, do: Logger.info("Sequence matched")
          # We reject nils from the AST since they represent ignored values
          new_ctx
          |> Context.ast_without_ignored()
          |> Context.ast_in_parsed_order()
          |> Context.ast_transform(map_fn)
        else
          err_ctx ->
            if debug, do: Logger.info("Sequence failed to match")
            err_ctx
        end
      end,
      combinator: true,
      label: label
    )
  end

  def sequence([], _opts) do
    raise "You must supply at least one parser to sequence/2"
  end

  defp sequence_reduce(parsers, %Context{} = ctx) when is_list(parsers) do
    Enum.reduce_while(parsers, %{ctx | ast: []}, fn parser, ctx ->
      case Parser.invoke(parser, ctx) do
        %Context{status: :ok, ast: ast} = new_ctx -> {:cont, %{new_ctx | ast: [ast | ctx.ast]}}
        err_ctx -> {:halt, err_ctx}
      end
    end)
  end

  @doc ~S"""
  ## Examples

      This test will need to be rewritten in terms of Ergo.diganose
      # iex> Logger.disable(self())
      # iex> alias Ergo.Context
      # iex> import Ergo.{Combinators, Terminals}
      # iex> parser = many(wc(), label: "Chars")
      # iex> context = Ergo.parse(parser, "Hello World", debug: true)
      # iex> assert %Context{status: :ok, debug: true, ast: [?H, ?e, ?l, ?l, ?o], input: " World", index: 5, col: 6, char: ?o} = context

      iex> alias Ergo.Context
      iex> import Ergo.{Combinators, Terminals}
      iex> parser = many(wc(), min: 6)
      iex> context = Ergo.parse(parser, "Hello World")
      iex> assert %Context{status: {:error, :many_less_than_min}, ast: nil, input: " World", index: 5, col: 6} = context

      iex> alias Ergo.{Context, Parser}
      iex> import Ergo.{Combinators, Terminals}
      iex> parser = many(wc(), max: 3)
      iex> context = Ergo.parse(parser, "Hello World")
      iex> assert %Context{status: :ok, ast: [?H, ?e, ?l], input: "lo World", index: 3, col: 4} = context

      iex> alias Ergo.{Context, Parser}
      iex> import Ergo.{Combinators, Terminals}
      iex> parser = many(wc(), map: &Enum.count/1)
      iex> context = Ergo.parse(parser, "Hello World")
      iex> assert %Context{status: :ok, ast: 5, input: " World", index: 5, col: 6} = context
  """
  def many(parser, opts \\ [])

  def many(%Parser{} = parser, opts) do
    label = Keyword.get(opts, :label, "#")

    min = Keyword.get(opts, :min, 0)
    max = Keyword.get(opts, :max, :infinity)
    map_fn = Keyword.get(opts, :map, nil)

    Parser.new(
      :many,
      fn %Context{debug: debug, input: input} = ctx ->
        if debug, do: Logger.info("Trying Many<#{label}> on [#{ellipsize(input, 20)}]")

        with %Context{status: :ok} = new_ctx <- parse_many(parser, %{ctx | ast: []}, min, max, 0) do
          new_ctx
          |> Context.ast_without_ignored()
          |> Context.ast_in_parsed_order()
          |> Context.ast_transform(map_fn)
        end
      end,
      combinator: true,
      label: label
    )
  end

  def parse_many(%Parser{} = parser, %Context{} = ctx, min, max, count)
      when is_integer(min) and min >= 0 and ((is_integer(max) and max > min) or max == :infinity) and
             is_integer(count) do
    case Parser.invoke(parser, ctx) do
      %Context{status: {:error, _}} ->
        if count < min do
          %{ctx | status: {:error, :many_less_than_min}, ast: nil}
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
    label = Keyword.get(opts, :label, "#")
    map_fn = Keyword.get(opts, :map, nil)

    Parser.new(
      :optional,
      fn %Context{debug: debug, input: input} = ctx ->
        if debug, do: Logger.info("Trying Optional<#{label}> on [#{ellipsize(input, 20)}]")

        case Parser.invoke(parser, ctx) do
          %Context{status: :ok, ast: ast} = new_ctx ->
            if debug, do: Logger.info("<- Matched: [#{inspect(ast)}]")

            if map_fn do
              mapped_ast = map_fn.(ast)
              if debug, do: Logger.info("<- Return [#{inspect(mapped_ast)}]")
              %{new_ctx | ast: mapped_ast}
            else
              new_ctx
            end

          _ ->
            %{ctx | status: :ok}
        end
      end,
      combinator: true,
      label: label
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
    label = Keyword.get(opts, :label, "#")

    Parser.new(
      :ignore,
      fn %Context{debug: debug, input: input} = ctx ->
        if debug, do: Logger.info("Trying Ignore<#{label}> on [#{ellipsize(input, 20)}]")

        with %Context{status: :ok} = new_ctx <- Parser.invoke(parser, ctx) do
          %{new_ctx | ast: nil}
        end
      end,
      combinator: true,
      label: label
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
    label = Keyword.get(opts, :label, "#")

    Parser.new(
      :transform,
      fn %Context{debug: debug, ast: ast} = ctx ->
        if debug, do: Logger.info("Trying Transform<#{label}> on [#{inspect(ast)}]")

        with %Context{status: :ok, ast: ast} = new_ctx <- Parser.invoke(parser, ctx),
             tranformed_ast <- t_fn.(ast) do
          if debug, do: Logger.info("<-- Transformed to: [#{inspect(tranformed_ast)}]")
          %{new_ctx | ast: tranformed_ast}
        end
      end,
      combinator: true,
      label: label
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
      iex> assert %Context{status: {:error, :lookahead_fail}, ast: [?l, ?e, ?H], index: 3, col: 4, input: "lo World"} = Ergo.parse(parser, "Hello World")
  """
  def lookahead(%Parser{} = parser, opts \\ []) do
    label = Keyword.get(opts, :label, "#")

    Parser.new(
      :lookahead,
      fn %Context{debug: debug, input: input} = ctx ->
        if debug, do: Logger.info("Trying Lookahead<#{label}> on [#{ellipsize(input, 20)}]")
        case Parser.invoke(parser, ctx) do
          %Context{status: :ok} -> %{ctx | ast: nil}
          bad_ctx -> %{bad_ctx | status: {:error, :lookahead_fail}, message: nil}
        end
      end,
      combinator: true,
      label: label
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
    iex> assert %Context{status: {:error, :lookahead_fail}, input: "Hello World"} = Ergo.parse(parser, "Hello World")
  """
  def not_lookahead(%Parser{} = parser, opts \\ []) do
    label = Keyword.get(opts, :label, "#")

    Parser.new(
      :not_lookahead,
      fn %Context{debug: debug, input: input} = ctx ->
        if debug, do: Logger.info("Trying NotLookahead<#{label}> on [#{ellipsize(input, 20)}]")
        case Parser.invoke(parser, ctx) do
          %Context{status: {:error, _}} -> %{ctx | status: :ok}
          %Context{} -> %{ctx | status: {:error, :lookahead_fail}, message: nil}
        end
      end,
      combinator: true,
      label: label
    )
  end
end
