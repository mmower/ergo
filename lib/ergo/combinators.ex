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

  @doc ~S"""
  The `choice/1` parser takes a list of parsers. It tries each in order attempting to match one. Once a match has been
  made choice returns the result of the matching parser.

  ## Examples

      iex> alias Ergo.{Context, Parser}
      iex> import Ergo.{Terminals, Parsers, Combinators}
      iex> context = Context.new("Hello World")
      iex> parser = choice([literal("Foo"), literal("Bar"), literal("Hello"), literal("World")])
      iex> Parser.call(parser, context)
      %Context{status: :ok, ast: "Hello", input: " World", char: ?o, index: 5, col: 6}

      iex> alias Ergo.{Context, Parser}
      iex> import Ergo.{Terminals, Parsers, Combinators}
      iex> context = Context.new("Hello World")
      iex> parser = choice([literal("Foo"), literal("Bar")])
      iex> Parser.call(parser, context)
      %Context{status: {:error, :no_valid_choice}, message: "No valid choice", ast: nil, input: "Hello World"}
  """
  def choice(parsers, opts \\ []) when is_list(parsers) do
    debug = Keyword.get(opts, :debug, false)
    label = Keyword.get(opts, :label, "")
    map_fn = Keyword.get(opts, :map, nil)

    Parser.new(
      fn ctx ->
        if debug, do: Logger.info("choice: #{label}")

        with %Context{status: :ok} = new_ctx <- apply_parsers_in_turn(parsers, ctx) do
          if map_fn do
            %{new_ctx | ast: map_fn.(new_ctx.ast)}
          else
            new_ctx
          end
        end
      end,
      %{
        parser: "choice",
        label: label,
        children: parsers
      }
    )
  end

  defp apply_parsers_in_turn(parsers, ctx) do
    Enum.reduce_while(
      parsers,
      %{ctx | status: {:error, :no_valid_choice}, message: "No valid choice", ast: nil},
      &reduce_parsers/2
    )
  end

  defp reduce_parsers(%Parser{} = parser, %Context{} = ctx) do
    case Parser.call(parser, ctx) do
      %Context{status: :ok} = new_ctx ->
        {:halt, %{new_ctx | message: nil}}

      _ ->
        {:cont, ctx}
    end
  end

  @doc ~S"""

  ## Examples

      iex> alias Ergo.{Context, Parser}
      iex> import Ergo.{Terminals, Combinators, Parsers}
      iex> context = Context.new("Hello World")
      iex> parser = sequence([literal("Hello"), ws(), literal("World")])
      iex> Parser.call(parser, context)
      %Context{status: :ok, ast: ["Hello", ?\s, "World"], char: ?d, index: 11, line: 1, col: 12}

      iex> alias Ergo.{Context, Parser}
      iex> import Ergo.{Terminals, Combinators, Parsers}
      iex> context = Context.new("Hello World")
      iex> parser = sequence([literal("Hello"), ws(), literal("World")], map: fn ast -> Enum.join(ast, " ") end)
      iex> Parser.call(parser, context)
      %Context{status: :ok, ast: "Hello 32 World", char: ?d, index: 11, line: 1, col: 12}
  """
  def sequence(parsers, opts \\ [])

  def sequence(parsers, opts) when is_list(parsers) do
    debug = Keyword.get(opts, :debug, false)
    label = Keyword.get(opts, :label, "")
    map_fn = Keyword.get(opts, :map, nil)

    Parser.new(
      fn ctx ->
        if debug, do: Logger.info("sequence: #{label}")

        with %Context{status: :ok} = new_ctx <- sequence_reduce(parsers, ctx) do
          # We reject nils from the AST since they represent ignored values
          new_ctx
          |> Context.ast_without_ignored()
          |> Context.ast_in_parsed_order()
          |> Context.ast_transform(map_fn)
        end
      end,
      %{
        parser: "sequence",
        label: label,
        children: parsers
      }
    )
  end

  def sequence([], _opts) do
    raise "You must supply at least one parser to sequence/2"
  end

  defp sequence_reduce(parsers, %Context{} = ctx) do
    Enum.reduce_while(parsers, %{ctx | ast: []}, fn parser, ctx ->
      case Parser.call(parser, ctx) do
        %Context{status: :ok, ast: ast} = new_ctx -> {:cont, %{new_ctx | ast: [ast | ctx.ast]}}
        err_ctx -> {:halt, err_ctx}
      end
    end)
  end

  @doc ~S"""
  ## Examples

      iex> alias Ergo.{Context, Combinators, Parser}
      iex> context = Context.new("Hello World")
      iex> parser = Combinators.many(Ergo.Terminals.wc())
      iex> Parser.call(parser, context)
      %Context{status: :ok, ast: [?H, ?e, ?l, ?l, ?o], input: " World", index: 5, col: 6, char: ?o}

      iex> alias Ergo.{Context, Combinators, Parser}
      iex> import Ergo.{Combinators, Terminals}
      iex> context = Context.new("Hello World")
      iex> parser = many(wc(), min: 6)
      iex> Parser.call(parser, context)
      %Context{status: {:error, :many_less_than_min}, ast: nil, input: " World", char: ?o, index: 5, col: 6}

      iex> alias Ergo.{Context, Combinators, Parser}
      iex> import Ergo.{Combinators, Terminals}
      iex> context = Context.new("Hello World")
      iex> parser = many(wc(), max: 3)
      iex> Parser.call(parser, context)
      %Context{status: :ok, ast: [?H, ?e, ?l], input: "lo World", char: ?l, index: 3, col: 4}

      iex> alias Ergo.{Context, Combinators, Parser}
      iex> import Ergo.{Combinators, Terminals}
      iex> context = Context.new("Hello World")
      iex> parser = many(wc(), map: &Enum.count/1)
      iex> Parser.call(parser, context)
      %Context{status: :ok, ast: 5, input: " World", index: 5, col: 6, char: ?o}
  """
  def many(parser, opts \\ [])

  def many(%Parser{} = parser, opts) do
    debug = Keyword.get(opts, :debug, false)
    label = Keyword.get(opts, :label, "")

    min = Keyword.get(opts, :min, 0)
    max = Keyword.get(opts, :max, :infinity)
    map_fn = Keyword.get(opts, :map, nil)

    Parser.new(
      fn ctx ->
        if debug, do: Logger.info("many: #{label}")

        with %Context{status: :ok} = new_ctx <- parse_many(parser, %{ctx | ast: []}, min, max, 0) do
          new_ctx
          |> Context.ast_without_ignored()
          |> Context.ast_in_parsed_order()
          |> Context.ast_transform(map_fn)
        end
      end,
      %{
        parser: "many",
        label: label,
        child: parser,
        min: min,
        max: max
      }
    )
  end

  def parse_many(%Parser{} = parser, %Context{} = ctx, min, max, count)
      when is_integer(min) and min >= 0 and ((is_integer(max) and max > min) or max == :infinity) and
             is_integer(count) do
    case Parser.call(parser, ctx) do
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
      iex> Ergo.parse(optional(literal("Hello")), "Hello World")
      %Context{status: :ok, ast: "Hello", input: " World", index: 5, col: 6, char: ?o}

      In this example we deliberately ensure that the Context ast is not nil
      iex> alias Ergo.{Context, Parser}
      iex> import Ergo.{Terminals, Combinators}
      iex> context = Context.new(" World")
      iex> context = %{context | ast: []}
      iex> parser = optional(literal("Hello"))
      iex> Parser.call(parser, context)
      %Context{status: :ok, ast: nil, input: " World", index: 0, col: 1, char: 0}
  """
  def optional(%Parser{} = parser, opts \\ []) do
    debug = Keyword.get(opts, :debug, false)
    label = Keyword.get(opts, :label, "")

    Parser.new(
      fn ctx ->
        if debug, do: Logger.info("optional: #{label}")

        case Parser.call(parser, ctx) do
          %Context{status: :ok} = new_ctx -> new_ctx
          _ -> %{ctx | ast: nil}
        end
      end,
      %{
        parser: "optional",
        label: label,
        child: parser
      }
    )
  end

  @doc ~S"""
  The ignore/1 parser matches but ignores the AST of its child parser.

  ## Examples

      iex> alias Ergo.{Context, Parser}
      iex> import Ergo.{Terminals, Combinators, Parsers}
      iex> context = Context.new("Hello World")
      iex> parser = sequence([literal("Hello"), ignore(ws()), literal("World")])
      iex> Parser.call(parser, context)
      %Context{status: :ok, ast: ["Hello", "World"], index: 11, col: 12, char: ?d}
  """
  def ignore(%Parser{} = parser, opts \\ []) do
    label = Keyword.get(opts, :label, "")

    Parser.new(
      fn ctx ->
        with %Context{status: :ok} = new_ctx <- Parser.call(parser, ctx) do
          %{new_ctx | ast: nil}
        end
      end,
      %{
        parser: "ignore",
        label: label,
        child: parser
      }
    )
  end

  @doc ~S"""
  The `transform/2` parser runs a transforming function on the AST of its child parser.

  ## Examples

      # Sum the digits
      iex> alias Ergo.{Context, Combinators, Parser}
      iex> import Ergo.{Combinators, Terminals}
      iex> digit_to_int = fn d -> List.to_string([d]) |> String.to_integer() end
      iex> t_fn = fn ast -> ast |> Enum.map(digit_to_int) |> Enum.sum() end
      iex> context = Context.new("1234")
      iex> parser_1 = sequence([digit(), digit(), digit(), digit()])
      iex> parser_2 = transform(parser_1, t_fn)
      iex> Parser.call(parser_2, context)
      %Context{status: :ok, ast: 10, char: ?4, index: 4, line: 1, col: 5}
  """
  def transform(%Parser{} = parser, t_fn, opts \\ []) when is_function(t_fn) do
    label = Keyword.get(opts, :label, "")

    Parser.new(
      fn ctx ->
        with %Context{status: :ok, ast: ast} = new_ctx <- Parser.call(parser, ctx) do
          %{new_ctx | ast: t_fn.(ast)}
        end
      end,
      %{
        parser: "transform",
        label: label,
        child: parser
      }
    )
  end

  @doc ~S"""
  The `lookahead` parser accepts a parser and matches it but does not update the context when it succeeds.

  ## Example

      iex> alias Ergo.{Context, Parser}
      iex> import Ergo.{Combinators, Terminals}
      iex> context = Context.new("Hello World")
      iex> parser = lookahead(literal("Hello"))
      iex> Parser.call(parser, context)
      %Context{status: :ok, ast: nil, input: "Hello World", char: 0, index: 0, line: 1, col: 1}

      iex> alias Ergo.{Context, Parser}
      iex> import Ergo.{Combinators, Terminals}
      iex> context = Context.new("Hello World")
      iex> parser = lookahead(literal("Helga"))
      iex> Parser.call(parser, context)
      %Context{status: {:error, :lookahead_fail}, ast: [?l, ?e, ?H], char: ?l, index: 3, col: 4, input: "lo World"}
  """
  def lookahead(%Parser{} = parser, opts \\ []) do
    label = Keyword.get(opts, :label, "")

    Parser.new(
      fn ctx ->
        case Parser.call(parser, ctx) do
          %Context{status: :ok} -> %{ctx | ast: nil}
          bad_ctx -> %{bad_ctx | status: {:error, :lookahead_fail}, message: nil}
        end
      end,
      %{
        parser: "lookahead",
        label: label,
        child: parser
      }
    )
  end

  @doc ~S"""
  The `not_lookahead` parser accepts a parser and attempts to match it. If the match fails the not_lookahead parser returns status: :ok but does not affect the context otherwise.

  If the match succeeds the `not_lookahead` parser fails with {:error, :lookahead_fail}

  ## Examples

    iex> alias Ergo.{Context, Parser}
    iex> import Ergo.{Combinators, Terminals}
    iex> context = Context.new("Hello World")
    iex> parser = not_lookahead(literal("Foo"))
    iex> Parser.call(parser, context)
    %Context{status: :ok, input: "Hello World"}

    iex> alias Ergo.{Context, Parser}
    iex> import Ergo.{Combinators, Terminals}
    iex> context = Context.new("Hello World")
    iex> parser = not_lookahead(literal("Hello"))
    iex> Parser.call(parser, context)
    %Context{status: {:error, :lookahead_fail}, input: "Hello World"}
  """
  def not_lookahead(%Parser{} = parser, opts \\ []) do
    label = Keyword.get(opts, :label, "")

    Parser.new(
      fn ctx ->
        case Parser.call(parser, ctx) do
          %Context{status: {:error, _}} -> %{ctx | status: :ok}
          %Context{} -> %{ctx | status: {:error, :lookahead_fail}, message: nil}
        end
      end,
      %{
        parser: "not_lookahed",
        label: label,
        child: parser
      }
    )
  end
end
