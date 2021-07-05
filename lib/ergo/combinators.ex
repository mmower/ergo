defmodule Ergo.Combinators do
  alias Ergo.Context

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
  def choice(parsers) when is_list(parsers) do
    fn ctx ->
      Enum.reduce_while(
        parsers,
        %{ctx | status: {:error, :no_valid_choice}, message: "No valid choice", ast: nil},
        fn parser, ctx ->
          case parser.(ctx) do
            %Context{status: :ok} = new_ctx ->
              {:halt, %{new_ctx | message: nil}}

            _ ->
              {:cont, ctx}
          end
        end
      )
    end
  end

  @doc ~S"""

  ## Examples

      iex> alias Ergo.{Context, Terminals, Combinators}
      ...> context = Context.new("Hello World")
      ...> parser = Combinators.sequence([Terminals.literal("Hello"), Terminals.ws(), Terminals.literal("World")])
      ...> parser.(context)
      %Context{status: :ok, ast: ["Hello", ?\s, "World"], char: ?d, index: 11, line: 1, col: 12}
  """
  def sequence(parsers) when is_list(parsers) do
    fn ctx ->
      with %Context{status: :ok} = new_ctx <- sequence_reduce(parsers, ctx) do
        # We reject nils from the AST since they represent ignored values
        new_ctx |> Context.ast_without_ignored() |> Context.ast_in_parsed_order()
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
  """
  def many(parser, opts \\ [])

  def many(parser, opts) do
    min = Keyword.get(opts, :min, 0)
    max = Keyword.get(opts, :max, :infinity)

    fn ctx ->
      with %Context{status: :ok} = new_ctx <- parse_many(parser, %{ctx | ast: []}, min, max, 0) do
        new_ctx
        |> Context.ast_without_ignored()
        |> Context.ast_in_parsed_order()
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
          parse_many(parser, %{new_ctx | ast: [new_ctx.ast | ctx.ast]}, min, max, count+1)
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
  def optional(parser) do
    fn ctx ->
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
  def ignore(parser) do
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
  def transform(parser, t_fn) do
    fn ctx ->
      with %Context{status: :ok, ast: ast} = new_ctx <- parser.(ctx) do
        %{new_ctx | ast: t_fn.(ast)}
      end
    end
  end
end