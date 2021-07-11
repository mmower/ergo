defmodule Ergo.Context do
  alias __MODULE__

  defstruct status: :ok,
            message: nil,
            input: "",
            index: 0,
            line: 1,
            col: 1,
            char: 0,
            ast: nil

  @doc """
  ## Examples:

    iex> Context.new("Hello World")
    %Context{status: :ok, input: "Hello World", line: 1, col: 1, index: 0}
  """
  def new(s) when is_binary(s) do
    %Context{input: s}
  end

  @doc """
  ## Examples

    iex> Context.new()
    %Context{}
  """
  def new() do
    %Context{}
  end

  @doc """
  ## Examples

    iex> Context.next_char(Context.new())
    %Context{status: {:error, :unexpected_eoi}, message: "Unexpected end of input"}

    iex> Context.next_char(Context.new("Hello World"))
    %Context{status: :ok, input: "ello World", char: ?H, ast: ?H, index: 1, line: 1, col: 2}
  """
  def next_char(context)

  def next_char(%Context{input: ""} = ctx) do
    %{
      ctx
      | status: {:error, :unexpected_eoi},
        message: "Unexpected end of input"
    }
  end

  def next_char(%Context{input: input, index: index, line: line, col: col} = ctx) do
    <<char::utf8, rest::binary>> = input
    {new_index, new_line, new_col} = wind_forward({index, line, col}, char == ?\n)

    %{
      ctx
      | status: :ok,
        input: rest,
        char: char,
        ast: char,
        index: new_index,
        line: new_line,
        col: new_col
    }
  end

  defp wind_forward({index, line, col}, is_newline) do
    case is_newline do
      true -> {index + 1, line + 1, 1}
      false -> {index + 1, line, col + 1}
    end
  end

  @doc """

  ## Examples
      iex> context = Context.new("Hello")
      ...> Context.peek(context)
      %Context{status: :ok, char: ?H, ast: ?H, input: "ello", index: 1, line: 1, col: 2}

      iex> context = Context.new()
      ...> Context.peek(context)
      %Context{status: {:error, :unexpected_eoi}, message: "Unexpected end of input", index: 0, line: 1, col: 1}
  """
  def peek(%Context{} = ctx) do
    with %Context{status: :ok} = peek_ctx <- next_char(ctx) do
      peek_ctx
    end
  end

  @doc ~S"""
  The `ignore` parser matches but returns a nil for the AST. Parsers like `sequence` accumulate these nil values.
  Call this function to remove them

  ## Examples
      iex> context = Ergo.Context.new()
      ...> context = %{context | ast: ["Hello", nil, "World", nil]}
      ...> Context.ast_without_ignored(context)
      %Context{ast: ["Hello", "World"]}
  """
  def ast_without_ignored(%Context{ast: ast} = ctx) do
    %{ctx | ast: Enum.reject(ast, &is_nil/1)}
  end

  @doc ~S"""
  Because we build ASTs using lists they end up in reverse order. This method reverses the AST back
  to in-parse-order

  ## Examples
      iex> context = Ergo.Context.new()
      ...> context = %{context | ast: [4, 3, 2, 1]}
      ...> Context.ast_in_parsed_order(context)
      %Context{ast: [1, 2, 3, 4]}
  """
  def ast_in_parsed_order(%Context{ast: ast} = ctx) do
    %{ctx | ast: Enum.reverse(ast)}
  end

  @doc ~S"""
  Where an AST has been built from individual characters and needs to be converted to a string

  ## Examples
      iex> context = Ergo.Context.new()
      iex> context = %{context | ast: [?H, ?e, ?l, ?l, ?o]}
      iex> Context.ast_to_string(context)
      %Context{ast: "Hello"}
  """
  def ast_to_string(%Context{ast: ast} = ctx) do
    %{ctx | ast: List.to_string(ast)}
  end

  @doc ~S"""
  Called to perform an arbitrary transformation on the AST value of a Context.

  ## Examples

      iex> alias Ergo.Context
      iex> context = Context.new()
      iex> context = %{context | ast: "Hello World"}
      iex> Context.ast_transform(context, &Function.identity/1)
      %Context{ast: "Hello World"}

      iex> alias Ergo.Context
      iex> context = Context.new()
      iex> context = %{context | ast: "Hello World"}
      iex> Context.ast_transform(context, &String.length/1)
      %Context{ast: 11}

      iex> alias Ergo.Context
      iex> context = Context.new()
      iex> context = %{context | ast: "Hello World"}
      iex> Context.ast_transform(context, nil)
      %Context{ast: "Hello World"}
  """
  def ast_transform(%Context{ast: ast} = ctx, fun) do
    case fun do
      f when is_function(f) -> %{ctx | ast: f.(ast)}
      nil -> ctx
    end
  end
end
