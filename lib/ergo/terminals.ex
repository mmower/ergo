defmodule Ergo.Terminals do
  alias Ergo.Context
  import Ergo.Utils, only: [char_to_string: 1]

  @doc """
  The eoi parser is a terminal parser that checks whether the input
  has been fully consumed. If there is input remaining to be parsed
  the return context status is set to :error.

  ## Examples

      iex> context = Ergo.Context.new()
      ...> parser = Terminals.eoi()
      ...> parser.(context)
      %Ergo.Context{status: :ok}

      iex> context = Ergo.Context.new("Hello World")
      ...> parser = Terminals.eoi()
      ...> parser.(context)
      %Ergo.Context{status: {:error, :not_eoi}, message: "Input not empty: Hello World…", input: "Hello World"}
  """
  def eoi() do
    fn
      %Context{input: ""} = ctx ->
        %{ctx | status: :ok}

      %Context{input: input} = ctx ->
        {truncated, _} = String.split_at(input, 20)
        %{ctx | status: {:error, :not_eoi}, message: "Input not empty: #{truncated}…"}
    end
  end

  @doc """
  The `char/1` parser is a terminal parser that matches a specific character.

  ## Examples
      iex> context = Ergo.Context.new("Hello World")
      ...> parser = Terminals.char(?H)
      ...> parser.(context)
      %Ergo.Context{status: :ok, char: ?H, ast: [?H], input: "ello World", index: 1, line: 1, col: 2}

      iex> context = Ergo.Context.new("Hello World")
      ...> parser = Terminals.char(?h)
      ...> parser.(context)
      %Ergo.Context{status: {:error, :unexpected_char}, message: "Expected: h Actual: H", input: "Hello World"}

      iex> context = Ergo.Context.new()
      ...> parser = Terminals.char(?H)
      ...> parser.(context)
      %Ergo.Context{status: {:error, :unexpected_eoi}, message: "Unexpected end of input"}

      iex> context = Ergo.Context.new("Hello World")
      ...> parser = Terminals.char(?A..?Z)
      ...> parser.(context)
      %Ergo.Context{status: :ok, char: ?H, ast: [?H], input: "ello World", index: 1, line: 1, col: 2}

      iex> context = Ergo.Context.new("Hello World")
      ...> parser = Terminals.char(?a..?z)
      ...> parser.(context)
      %Ergo.Context{status: {:error, :unexpected_char}, message: "Expected: a..z Actual: H", input: "Hello World"}

      iex> context = Ergo.Context.new()
      ...> parser = Terminals.char(?A..?Z)
      ...> parser.(context)
      %Ergo.Context{status: {:error, :unexpected_eoi}, message: "Unexpected end of input"}

      iex> context = Ergo.Context.new("Hello World")
      ...> parser = Terminals.char([?a..?z, ?A..?Z])
      ...> parser.(context)
      %Ergo.Context{status: :ok, char: ?H, ast: [?H], input: "ello World", index: 1, line: 1, col: 2}

      iex> context = Ergo.Context.new("0000")
      ...> parser = Terminals.char([?a..?z, ?A..?Z])
      ...> parser.(context)
      %Ergo.Context{status: {:error, :unexpected_char}, message: "Expected: [a..z, A..Z] Actual: 0", input: "0000"}

  """
  def char(c) when is_integer(c) do
    fn ctx ->
      case Context.next_char(ctx) do
        %Context{status: :ok, char: ^c} = new_ctx ->
          new_ctx

        %Context{status: :ok, char: u} ->
          %{
            ctx
            | status: {:error, :unexpected_char},
              message: "Expected: #{describe_char_match(c)} Actual: #{char_to_string(u)}"
          }

        %Context{status: {:error, _}} = new_ctx ->
          new_ctx
      end
    end
  end

  def char(min..max) when is_integer(min) and is_integer(max) do
    fn ctx ->
      case Context.next_char(ctx) do
        %Context{status: :ok, char: c} = new_ctx when c in min..max ->
          new_ctx

        %Context{status: :ok, char: c} ->
          %{
            ctx
            | status: {:error, :unexpected_char},
              message: "Expected: #{describe_char_match(min..max)} Actual: #{char_to_string(c)}"
          }

        %Context{status: {:error, _}} = new_ctx ->
          new_ctx
      end
    end
  end

  def char(l) when is_list(l) do
    fn ctx ->
      with %Context{status: :ok} = peek_ctx <- Context.peek(ctx) do
        err_ctx = %{
          ctx
          | status: {:error, :unexpected_char},
            message:
              "Expected: #{describe_char_match(l)} Actual: #{char_to_string(peek_ctx.char)}"
        }

        Enum.reduce_while(l, err_ctx, fn matcher, err_ctx ->
          case char(matcher).(ctx) do
            %Context{status: :ok} = new_ctx -> {:halt, new_ctx}
            _no_match -> {:cont, err_ctx}
          end
        end)
      end
    end
  end

  defp describe_char_match(c) when is_integer(c) do
    char_to_string(c)
  end

  defp describe_char_match(min..max) when is_integer(min) and is_integer(max) do
    "#{char_to_string(min)}..#{char_to_string(max)}"
  end

  defp describe_char_match(l) when is_list(l) do
    s = l |> Enum.map(fn e -> describe_char_match(e) end) |> Enum.join(", ")
    "[#{s}]"
  end

  @doc ~S"""
  The `literal/1` parser matches the specified string character by character.

  ## Examples

      iex> context = Ergo.Context.new("Hello World")
      iex> parser = Terminals.literal("Hello")
      iex> parser.(context)
      %Ergo.Context{status: :ok, input: " World", ast: [?o, ?l, ?l, ?e, ?H], char: ?o, index: 5, line: 1, col: 6}

      iex> context = Ergo.Context.new("Hello World")
      iex> parser = Terminals.literal("Hellx")
      iex> parser.(context)
      %Ergo.Context{status: {:error, :unexpected_char}, message: "Expected: x Actual: o", input: "o World", ast: [?l, ?l, ?e, ?H], char: ?l, index: 4, line: 1, col: 5}

      iex> context = Ergo.Context.new()
      ...> parser = Terminals.digit()
      ...> parser.(context)
      %Ergo.Context{status: {:error, :unexpected_eoi}, message: "Unexpected end of input", char: 0, ast: [], input: "", index: 0, line: 1, col: 1}
  """
  def literal(s) when is_binary(s) do
    fn ctx ->
      Enum.reduce_while(String.to_charlist(s), ctx, fn c, ctx ->
        case char(c).(ctx) do
          %Context{status: :ok} = new_ctx ->
            {:cont, new_ctx}

          %Context{status: {:error, error}, message: message} ->
            {:halt, %{ctx | status: {:error, error}, message: message}}
        end
      end)
    end
  end

  @doc ~S"""
  The `digit/0` parser accepts a character in the range of 0..9

  ## Examples

    iex> context = Ergo.Context.new("0000")
    ...> parser = Terminals.digit()
    ...> parser.(context)
    %Ergo.Context{status: :ok, char: ?0, ast: [?0], input: "000", index: 1, line: 1, col: 2}

    iex> context = Ergo.Context.new("AAAA")
    ...> parser = Terminals.digit()
    ...> parser.(context)
    %Ergo.Context{status: {:error, :unexpected_char}, message: "Expected: 0..9 Actual: A", char: 0, ast: [], input: "AAAA", index: 0, line: 1, col: 1}

    iex> context = Ergo.Context.new()
    ...> parser = Terminals.digit()
    ...> parser.(context)
    %Ergo.Context{status: {:error, :unexpected_eoi}, message: "Unexpected end of input", char: 0, ast: [], input: "", index: 0, line: 1, col: 1}
  """
  def digit() do
    char(?0..?9)
  end

  @doc """
  The `alpha/0` parser accepts a single character in the range a..z or A..Z.

  ## Examples

      iex> context = Ergo.Context.new("Hello World")
      ...> parser = Terminals.alpha()
      ...> parser.(context)
      %Ergo.Context{status: :ok, input: "ello World", char: ?H, ast: [?H], index: 1, line: 1, col: 2}

      iex> context = Ergo.Context.new("ello World")
      ...> parser = Terminals.alpha()
      ...> parser.(context)
      %Ergo.Context{status: :ok, input: "llo World", char: ?e, ast: [?e], index: 1, line: 1, col: 2}

      iex> context = Ergo.Context.new(" World")
      ...> parser = Terminals.alpha()
      ...> parser.(context)
      %Ergo.Context{status: {:error, :unexpected_char}, message: "Expected: [a..z, A..Z] Actual:  ", input: " World"}
  """
  def alpha() do
    char([?a..?z, ?A..?Z])
  end

  @doc ~S"""
  The `ws/0` parser accepts a white space character and is equivalent to the \s regular expression.

  ## Examples

      iex> context = Ergo.Context.new(" World")
      ...> parser = Terminals.ws()
      ...> parser.(context)
      %Ergo.Context{status: :ok, char: ?\s, ast: [?\s], input: "World", index: 1, line: 1, col: 2}

      iex> context = Ergo.Context.new("\tWorld")
      ...> parser = Terminals.ws()
      ...> parser.(context)
      %Ergo.Context{status: :ok, char: ?\t, ast: [?\t], input: "World", index: 1, line: 1, col: 2}

      iex> context = Ergo.Context.new("\nWorld")
      ...> parser = Terminals.ws()
      ...> parser.(context)
      %Ergo.Context{status: :ok, char: ?\n, ast: [?\n], input: "World", index: 1, line: 2, col: 1}

      iex> context = Ergo.Context.new("Hello World")
      ...> parser = Terminals.ws()
      ...> parser.(context)
      %Ergo.Context{status: {:error, :unexpected_char}, message: "Expected: [\s, \t, \r, \n, \v] Actual: H", input: "Hello World"}
  """
  def ws() do
    char([?\s, ?\t, ?\r, ?\n, ?\v])
  end

  @doc ~S"""

  The `wc/0` parser parses a word character and is analagous to the \d regular expression.

  ## Examples

      iex> context = Ergo.Context.new("Hello World")
      ...> parser = Terminals.wc()
      ...> parser.(context)
      %Ergo.Context{status: :ok, char: ?H, ast: [?H], input: "ello World", index: 1, col: 2}

      iex> context = Ergo.Context.new("0 World")
      ...> parser = Terminals.wc()
      ...> parser.(context)
      %Ergo.Context{status: :ok, char: ?0, ast: [?0], input: " World", index: 1, col: 2}

      iex> context = Ergo.Context.new("_Hello")
      ...> parser = Terminals.wc()
      ...> parser.(context)
      %Ergo.Context{status: :ok, char: ?_, ast: [?_], input: "Hello", index: 1, col: 2}

      iex> context = Ergo.Context.new(" Hello")
      ...> parser = Terminals.wc()
      ...> parser.(context)
      %Ergo.Context{status: {:error, :unexpected_char}, message: "Expected: [0..9, a..z, A..Z, _] Actual:  ", input: " Hello"}
  """
  def wc() do
    char([?0..?9, ?a..?z, ?A..?Z, ?_])
  end
end
