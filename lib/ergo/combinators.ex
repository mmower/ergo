defmodule Ergo.Combinators do
  alias Ergo.Context
  require Logger

  @doc ~S"""
  The `choice/1` parser takes a list of parsers. It tries each in order attempting to match one. Once a match has been
  made choice returns the result of the matching parser.

  ## Examples

      iex> alias Ergo.{Context, Terminals, Combinators}
      ...> context = Context.new("Hello World")
      ...> parser = Combinators.choice([Terminals.literal("Foo"), Terminals.literal("Bar"), Terminals.literal("Hello"), Terminals.literal("World")])
      ...> parser.(context)
      %Context{status: :ok, ast: "Hello", input: " World", char: ?o, index: 5, col: 6}

      iex> alias Ergo.{Context, Terminals, Combinators}
      ...> context = Context.new("Hello World")
      ...> parser = Combinators.choice([Terminals.literal("Foo"), Terminals.literal("Bar")])
      ...> parser.(context)
      %Context{status: {:error, :no_valid_choice}, message: "No valid choice", ast: nil, input: "Hello World"}
  """
  def choice(parsers, opts \\ []) when is_list(parsers) do
    debug = Keyword.get(opts, :debug, false)
    label = Keyword.get(opts, :label, "")
    map_fn = Keyword.get(opts, :map, nil)

    fn ctx ->
      if debug, do: Logger.info("choice: #{label}")
      with %Context{status: :ok} = new_ctx <- apply_parsers_in_turn(parsers, ctx) do
        if map_fn do
          %{new_ctx | ast: map_fn.(new_ctx.ast)}
        else
          new_ctx
        end
      end
    end
  end

  defp apply_parsers_in_turn(parsers, ctx) do
    Enum.reduce_while(
        parsers,
        %{ctx | status: {:error, :no_valid_choice}, message: "No valid choice", ast: nil},
        &reduce_parsers/2
      )
  end

  defp reduce_parsers(parser, ctx) do
    case parser.(ctx) do
      %Context{status: :ok} = new_ctx ->
        {:halt, %{new_ctx | message: nil}}

      _ ->
        {:cont, ctx}
    end
  end

  @doc ~S"""

  ## Examples

      iex> alias Ergo.{Context, Terminals, Combinators}
      ...> context = Context.new("Hello World")
      ...> parser = Combinators.sequence([Terminals.literal("Hello"), Terminals.ws(), Terminals.literal("World")])
      ...> parser.(context)
      %Context{status: :ok, ast: ["Hello", ?\s, "World"], char: ?d, index: 11, line: 1, col: 12}

      iex> fun = fn ast -> Enum.join(ast, " ") end
      iex> alias Ergo.{Context, Terminals, Combinators}
      ...> context = Context.new("Hello World")
      ...> parser = Combinators.sequence([Terminals.literal("Hello"), Terminals.ws(), Terminals.literal("World")], map: fun)
      ...> parser.(context)
      %Context{status: :ok, ast: "Hello 32 World", char: ?d, index: 11, line: 1, col: 12}
  """
  def sequence(parsers, opts \\ [])

  def sequence(parsers, opts) when is_list(parsers) do
    debug = Keyword.get(opts, :debug, false)
    label = Keyword.get(opts, :label, "")
    fun = Keyword.get(opts, :map, &Function.identity/1)

    fn ctx ->
      if debug, do: Logger.info("sequence: #{label}")
      with %Context{status: :ok} = new_ctx <- sequence_reduce(parsers, ctx) do
        # We reject nils from the AST since they represent ignored values
        new_ctx
        |> Context.ast_without_ignored()
        |> Context.ast_in_parsed_order()
        |> Context.ast_transform(fun)
      end
    end
  end

  def sequence([], _opts) do
    raise "You must supply at least one parser to sequence/2"
  end

  defp sequence_reduce(parsers, ctx) do
    Enum.reduce_while(parsers, %{ctx | ast: []}, fn parser, ctx ->
      case parser.(%{ctx | ast: []}) do
        %Context{status: :ok, ast: ast} = new_ctx -> {:cont, %{new_ctx | ast: [ast | ctx.ast]}}
        err_ctx -> {:halt, err_ctx}
      end
    end)
  end

  @doc ~S"""
  ## Examples

      iex> alias Ergo.{Context, Combinators}
      ...> context = Context.new("Hello World")
      ...> parser = Combinators.many(Ergo.Terminals.wc())
      ...> parser.(context)
      %Context{status: :ok, ast: [?H, ?e, ?l, ?l, ?o], input: " World", index: 5, col: 6, char: ?o}

      iex> alias Ergo.{Context, Terminals, Combinators}
      ...> context = Context.new("Hello World")
      ...> parser = Combinators.many(Terminals.wc(), min: 6)
      ...> parser.(context)
      %Context{status: {:error, :many_less_than_min}, ast: nil, input: " World", char: ?o, index: 5, col: 6}

      iex> alias Ergo.{Context, Terminals, Combinators}
      ...> context = Context.new("Hello World")
      ...> parser = Combinators.many(Terminals.wc(), max: 3)
      ...> parser.(context)
      %Context{status: :ok, ast: [?H, ?e, ?l], input: "lo World", char: ?l, index: 3, col: 4}

      iex> alias Ergo.{Context, Combinators}
      ...> context = Context.new("Hello World")
      ...> parser = Combinators.many(Ergo.Terminals.wc(), map: &Enum.count/1)
      ...> parser.(context)
      %Context{status: :ok, ast: 5, input: " World", index: 5, col: 6, char: ?o}
  """
  def many(parser, opts \\ [])

  def many(parser, opts) when is_function(parser) do
    debug = Keyword.get(opts, :debug, false)
    label = Keyword.get(opts, :label, "")

    min = Keyword.get(opts, :min, 0)
    max = Keyword.get(opts, :max, :infinity)
    fun = Keyword.get(opts, :map, &Function.identity/1)

    fn ctx ->
      if debug, do: Logger.info("many: #{label}")
      with %Context{status: :ok} = new_ctx <- parse_many(parser, %{ctx | ast: []}, min, max, 0) do
        new_ctx
        |> Context.ast_without_ignored()
        |> Context.ast_in_parsed_order()
        |> Context.ast_transform(fun)
      end
    end
  end

  def parse_many(parser, ctx, min, max, count) do
    case parser.(%{ctx | ast: []}) do
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

  # defp many_parser(parser, ctx) do
  #   many_context_stream(parser, ctx) |> Enum.reduce(%{ctx | ast: []}, fn ctx, result_ctx ->
  #     IO.puts("many_stream")
  #     IO.inspect(ctx)
  #     IO.inspect(result_ctx)
  #     %{ctx | ast: [ctx.ast | result_ctx.ast]} end)
  # end

  # def many_context_stream(parser, %Context{} = ctx) when is_function(parser) do
  #   Stream.unfold(ctx, fn ctx ->
  #     case parser.(ctx) do
  #       %Context{status: :ok} = new_ctx -> {ctx, new_ctx}
  #       _ -> nil
  #     end
  #   end)
  # end

  @doc ~S"""

  ## Examples

      iex> alias Ergo.{Context, Terminals, Combinators}
      ...> context = Context.new("Hello World")
      ...> parser = Combinators.optional(Terminals.literal("Hello"))
      ...> parser.(context)
      %Context{status: :ok, ast: "Hello", input: " World", index: 5, col: 6, char: ?o}

      iex> alias Ergo.{Context, Terminals, Combinators}
      ...> context = Context.new(" World")
      ...> parser = Combinators.optional(Terminals.literal("Hello"))
      ...> parser.(context)
      %Context{status: :ok, ast: nil, input: " World", index: 0, col: 1, char: 0}

  """
  def optional(parser, opts \\ []) when is_function(parser) do
    debug = Keyword.get(opts, :debug, false)
    label = Keyword.get(opts, :label, "")

    fn ctx ->
      if debug, do: Logger.info("optional: #{label}")

      case parser.(ctx) do
        %Context{status: :ok} = new_ctx -> new_ctx
        _ -> ctx
      end
    end
  end

  @doc ~S"""
  The ignore/1 parser matches but ignores the AST of its child parser.

  ## Examples

      iex> alias Ergo.{Context, Terminals, Combinators}
      ...> context = Context.new("Hello World")
      ...> parser = Combinators.sequence([Terminals.literal("Hello"), Combinators.ignore(Terminals.ws()), Terminals.literal("World")])
      ...> parser.(context)
      %Context{status: :ok, ast: ["Hello", "World"], index: 11, col: 12, char: ?d}
  """
  def ignore(parser) when is_function(parser) do
    fn ctx ->
      with %Context{status: :ok} = new_ctx <- parser.(ctx) do
        %{new_ctx | ast: nil}
      end
    end
  end

  @doc ~S"""
  The `transform/2` parser runs a transforming function on the AST of its child parser.

  ## Examples

      # Sum the digits
      iex> alias Ergo.{Context, Terminals, Combinators}
      ...> digit_to_int = fn d -> List.to_string([d]) |> String.to_integer() end
      ...> t_fn = fn ast -> ast |> Enum.map(digit_to_int) |> Enum.sum() end
      ...> context = Context.new("1234")
      ...> parser_1 = Combinators.sequence([Terminals.digit(), Terminals.digit(), Terminals.digit(), Terminals.digit()])
      ...> parser_2 = Combinators.transform(parser_1, t_fn)
      ...> parser_2.(context)
      %Context{status: :ok, ast: 10, char: ?4, index: 4, line: 1, col: 5}
  """
  def transform(parser, t_fn) when is_function(parser) and is_function(t_fn) do
    fn ctx ->
      with %Context{status: :ok, ast: ast} = new_ctx <- parser.(ctx) do
        %{new_ctx | ast: t_fn.(ast)}
      end
    end
  end

  @doc ~S"""
  The `lookahead` parser accepts a parser and matches it but does not update the context when it succeeds.

  ## Example

      iex> alias Ergo.{Context, Terminals, Combinators}
      ...> context = Context.new("Hello World")
      ...> parser = Combinators.lookahead(Terminals.literal("Hello"))
      ...> parser.(context)
      %Context{status: :ok, ast: nil, input: "Hello World", char: 0, index: 0, line: 1, col: 1}

      iex> alias Ergo.{Context, Terminals, Combinators}
      ...> context = Context.new("Hello World")
      ...> parser = Combinators.lookahead(Terminals.literal("Helga"))
      ...> parser.(context)
      %Context{status: {:error, :lookahead_fail}, ast: [?l, ?e, ?H], char: ?l, index: 3, col: 4, input: "lo World"}
  """
  def lookahead(parser) when is_function(parser) do
    fn ctx ->
      case parser.(ctx) do
        %Context{status: :ok} -> ctx
        bad_ctx -> %{bad_ctx | status: {:error, :lookahead_fail}, message: nil}
      end
    end
  end

  @doc ~S"""
  The `not_lookahead` parser accepts a parser and attempts to match it. If the match fails the not_lookahead parser returns status: :ok but does not affect the context otherwise.

  If the match succeeds the `not_lookahead` parser fails with {:error, :lookahead_fail}

  ## Examples

    iex> alias Ergo.{Context, Terminals, Combinators}
    ...> context = Context.new("Hello World")
    ...> parser = Combinators.not_lookahead(Terminals.literal("Foo"))
    ...> parser.(context)
    %Context{status: :ok, input: "Hello World"}

    iex> alias Ergo.{Context, Terminals, Combinators}
    ...> context = Context.new("Hello World")
    ...> parser = Combinators.not_lookahead(Terminals.literal("Hello"))
    ...> parser.(context)
    %Context{status: {:error, :lookahead_fail}, input: "Hello World"}
  """
  def not_lookahead(parser) when is_function(parser) do
    fn ctx ->
      case parser.(ctx) do
        %Context{status: {:error, _}} -> %{ctx | status: :ok}
        %Context{} -> %{ctx | status: {:error, :lookahead_fail}, message: nil}
      end
    end
  end
end
