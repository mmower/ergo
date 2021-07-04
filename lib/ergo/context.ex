defmodule Ergo.Context do
  alias __MODULE__

  defstruct status: :ok,
            message: nil,
            input: "",
            index: 0,
            line: 1,
            col: 1,
            char: 0,
            ast: []

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
    %Context{status: :ok, input: "ello World", char: ?H, ast: [?H], index: 1, line: 1, col: 2}
  """
  def next_char(context)

  def next_char(%Context{input: ""} = ctx) do
    %{
      ctx
      | status: {:error, :unexpected_eoi},
        message: "Unexpected end of input"
    }
  end

  def next_char(%Context{input: input, index: index, line: line, col: col, ast: ast} = ctx) do
    <<char::utf8, rest::binary>> = input
    {new_index, new_line, new_col} = wind_forward({index, line, col}, char == ?\n)

    %{
      ctx
      | status: :ok,
        input: rest,
        char: char,
        ast: [char | ast],
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
      %Context{status: :ok, char: ?H, ast: [?H], input: "ello", index: 1, line: 1, col: 2}

      iex> context = Context.new()
      ...> Context.peek(context)
      %Context{status: {:error, :unexpected_eoi}, message: "Unexpected end of input", index: 0, line: 1, col: 1}
  """
  def peek(%Context{} = ctx) do
    with %Context{status: :ok} = peek_ctx <- next_char(ctx) do
      peek_ctx
    end
  end
end
