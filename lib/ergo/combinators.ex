defmodule Ergo.Combinators do
  alias Ergo.Context

  @doc ~S"""

  ## Examples

      iex> context = Ergo.Context.new("Hello World")
      ...> parser = Ergo.Combinators.sequence([Ergo.Terminals.literal("Hello"), Ergo.Terminals.ws(), Ergo.Terminals.literal("World")])
      ...> parser.(context)
      %Ergo.Context{status: :ok, ast: ["Hello", ' ', "World"], char: ?d, index: 11, line: 1, col: 12}
  """

  def sequence(parsers, opts \\ [])

  def sequence(parsers, _opts) when is_list(parsers) do
    fn ctx ->
      with %Context{status: :ok, ast: ast} = new_ctx <- sequence_reduce(parsers, ctx) do
        # We reject nils from the AST since they represent ignored values
        %{new_ctx | ast: ast |> Enum.reject(&is_nil/1) |> Enum.reverse()}
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
  The ignore/1 parser matches but ignores the AST of its child parser.

  ## Examples
      iex> context = Ergo.Context.new("Hello World")
      ...> parser = Ergo.Combinators.sequence([Ergo.Terminals.literal("Hello"), Ergo.Combinators.ignore(Ergo.Terminals.ws()), Ergo.Terminals.literal("World")])
      ...> parser.(context)
      %Ergo.Context{status: :ok, ast: ["Hello", "World"], index: 11, col: 12, char: ?d}
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
      iex> digit_to_int = fn d -> List.to_string([d]) |> String.to_integer() end
      ...> t_fn = fn ast -> ast |> Enum.map(digit_to_int) |> Enum.sum() end
      ...> context = Ergo.Context.new("1234")
      ...> parser_1 = Ergo.Combinators.sequence([Ergo.Terminals.digit(), Ergo.Terminals.digit(), Ergo.Terminals.digit(), Ergo.Terminals.digit()])
      ...> parser_2 = Ergo.Combinators.transform(parser_1, t_fn)
      ...> parser_2.(context)
      %Ergo.Context{status: :ok, ast: 10, char: ?4, index: 4, line: 1, col: 5}
  """
  def transform(parser, t_fn) do
    fn ctx ->
      with %Context{status: :ok, ast: ast} = new_ctx <- parser.(ctx) do
        %{new_ctx | ast: t_fn.(ast)}
      end
    end
  end

end
