defmodule Ergo.Terminals do
  alias Ergo.{Context, Parser}
  import Ergo.Utils
  require Logger

  @moduledoc ~S"""
  `Ergo.Terminals` contains the terminal parsers.

  A terminal parser is a parser that is not parameterised with another parser and works directly with the input.

  # Parsers

  * eoi
  * char
  * digit
  * alpha
  * ws
  * wc
  * literal

  """

  @doc """
  The eoi parser is a terminal parser that checks whether the input
  has been fully consumed. If there is input remaining to be parsed
  the return context status is set to :error.

  ## Examples

      iex> alias Ergo.{Context, Parser}
      iex> import Ergo.Terminals
      iex> context = Context.new(&Ergo.Parser.call/2, "")
      iex> assert %Context{status: :ok, ast: nil} = Parser.invoke(eoi(), context)

      iex> alias Ergo.{Context, Parser}
      iex> import Ergo.Terminals
      iex> context = Context.new(&Ergo.Parser.call/2, "Hello World")
      iex> assert %Context{status: {:error, :not_eoi}, message: "Input not empty: Hello World…", input: "Hello World"} = Parser.invoke(eoi(), context)
  """
  def eoi() do
    Parser.new(
      :eoi,
      fn
        %Context{input: ""} = ctx ->
          %{ctx | status: :ok, ast: nil}

        %Context{input: input} = ctx ->
          {truncated, _} = String.split_at(input, 20)
          %{ctx | status: {:error, :not_eoi}, message: "Input not empty: #{truncated}…"}
      end,
      label: "eoi"
    )
  end

  @doc """

  The `char/1` parser is a terminal parser that matches a specific character.

  ## Examples

      iex> alias Ergo.Context
      iex> import Ergo.Terminals
      iex> parser = char(?H)
      iex> assert %Context{status: :ok, ast: ?H, input: "ello World", index: 1, line: 1, col: 2} = Ergo.parse(parser, "Hello World")

      iex> alias Ergo.Context
      iex> import Ergo.Terminals
      iex> parser = char(?h)
      iex> assert %Context{status: {:error, :unexpected_char}, message: "Expected: h Actual: H", input: "Hello World"} = Ergo.parse(parser, "Hello World")

      iex> alias Ergo.Context
      iex> import Ergo.Terminals
      iex> parser = char(?H)
      iex> assert %Context{status: {:error, :unexpected_eoi}, message: "Unexpected end of input"} = Ergo.parse(parser, "")

      iex> alias Ergo.Context
      iex> import Ergo.Terminals
      iex> parser = char(?A..?Z)
      iex> assert %Context{status: :ok, ast: ?H, input: "ello World", index: 1, line: 1, col: 2} = Ergo.parse(parser, "Hello World")

      iex> alias Ergo.Context
      iex> import Ergo.Terminals
      iex> parser = char(?a..?z)
      iex> assert %Context{status: {:error, :unexpected_char}, message: "Expected: a..z Actual: H", input: "Hello World"} = Ergo.parse(parser, "Hello World")

      iex> alias Ergo.Context
      iex> import Ergo.Terminals
      iex> parser = char(?A..?Z)
      iex> assert %Context{status: {:error, :unexpected_eoi}, message: "Unexpected end of input"} = Ergo.parse(parser, "")

      iex> alias Ergo.Context
      iex> import Ergo.Terminals
      iex> parser = char([?a..?z, ?A..?Z])
      iex> assert %Context{status: :ok, ast: ?H, input: "ello World", index: 1, line: 1, col: 2} = Ergo.parse(parser, "Hello World")

      iex> alias Ergo.Context
      iex> import Ergo.Terminals
      iex> parser = char([?a..?z, ?A..?Z])
      iex> assert %Context{status: {:error, :unexpected_char}, message: "Expected: [a..z, A..Z] Actual: 0", input: "0000"} = Ergo.parse(parser, "0000")

      iex> alias Ergo.Context
      iex> import Ergo.Terminals
      iex> parser = char(-?0)
      iex> assert %Context{status: {:error, :unexpected_char}, message: "Should not have matched 0", input: "0000"} = Ergo.parse(parser, "0000")

      iex> alias Ergo.Context
      iex> import Ergo.Terminals
      iex> parser = char(-?a)
      iex> assert %Context{status: :ok, input: "000", ast: ?0, index: 1, col: 2} = Ergo.parse(parser, "0000")
  """
  def char(c, opts \\ [])

  def char(c, opts) when is_integer(c) and c >= 0 do
    label = Keyword.get(opts, :label, "?#{char_to_string(c)}")

    Parser.new(
      :char,
      fn ctx ->
        case Context.next_char(ctx) do
          %Context{status: :ok, ast: ^c} = new_ctx ->
            new_ctx

          %Context{status: :ok, ast: u} ->
            %{
              ctx
              | status: {:error, :unexpected_char},
                message: "Expected: #{describe_char_match(c)} Actual: #{char_to_string(u)}"
            }

          %Context{status: {:error, _}} = new_ctx ->
            new_ctx
        end
      end,
      label: label
    )
  end

  def char(c, opts) when is_integer(c) and c < 0 do
    c = -c

    label = Keyword.get(opts, :label, "?-#{char_to_string(c)}")

    Parser.new(
      :not_char,
      fn ctx ->
        case Context.next_char(ctx) do
          %Context{status: :ok, ast: ^c} ->
            %{
              ctx
              | status: {:error, :unexpected_char},
                message: "Should not have matched #{describe_char_match(c)}"
            }

          %Context{status: :ok, ast: _} = new_ctx ->
            new_ctx

          %Context{status: {:error, _}} = err_ctx ->
            err_ctx
        end
      end,
      label: label
    )
  end

  def char(min..max, opts) when is_integer(min) and is_integer(max) do
    label = Keyword.get(opts, :label, "?(#{char_to_string(min)}..#{char_to_string(max)})")

    Parser.new(
      :char_rng,
      fn ctx ->
        case Context.next_char(ctx) do
          %Context{status: :ok, ast: c} = new_ctx when c in min..max ->
            new_ctx

          %Context{status: :ok, ast: c} ->
            %{
              ctx
              | status: {:error, :unexpected_char},
                message: "Expected: #{describe_char_match(min..max)} Actual: #{char_to_string(c)}"
            }

          %Context{status: {:error, _}} = new_ctx ->
            new_ctx
        end
      end,
      label: label
    )
  end

  def char(l, opts) when is_list(l) do
    label = Keyword.get(opts, :label, "?[#{inspect(l)}]")

    Parser.new(
      :char_lst,
      fn ctx ->
        with %Context{status: :ok} = peek_ctx <- Context.peek(ctx) do
          err_ctx = %{
            ctx
            | status: {:error, :unexpected_char},
              message:
                "Expected: #{describe_char_match(l)} Actual: #{char_to_string(peek_ctx.ast)}"
          }

          Enum.reduce_while(l, err_ctx, fn matcher, err_ctx ->
            case Parser.invoke(char(matcher), ctx) do
              %Context{status: :ok} = new_ctx -> {:halt, new_ctx}
              _no_match -> {:cont, err_ctx}
            end
          end)
        end
      end,
      label: label
    )
  end

  @doc """
  The not_char matcher accepts a char or a list of chars and will match any
  char that is not in the list.

  # Examples
      iex> alias Ergo.Context
      iex> import Ergo.Terminals
      iex> parser = not_char(?0)
      iex> assert %Context{status: {:error, :unexpected_char}, message: "Should not have matched 0", input: "0000"} = Ergo.parse(parser, "0000")
      iex> assert %Context{status: :ok, ast: ?1} = Ergo.parse(parser, "1111")
      iex> parser = not_char([?{, ?}])
      iex> assert %Context{status: {:error, :unexpected_char}, message: "Should not have matched {", input: "{}"} = Ergo.parse(parser, "{}")
      iex> assert %Context{status: {:error, :unexpected_char}, message: "Should not have matched }", input: "}"} = Ergo.parse(parser, "}")
  """
  def not_char(char) when is_integer(char) do
    not_char([char])
  end

  def not_char(l) when is_list(l) do
    Parser.new(
      :not_char,
      fn ctx ->
        with %Context{status: :ok, ast: ast} <- Context.peek(ctx) do
          case Enum.member?(l, ast) do
            true ->
              %{
                ctx
                | status: {:error, :unexpected_char},
                  message: "Should not have matched #{char_to_string(ast)}"
              }

            false ->
              Context.next_char(ctx)
          end
        end
      end
    )
  end

  defp describe_char_match(c) when is_integer(c) and c > 0 do
    char_to_string(c)
  end

  defp describe_char_match(c) when is_integer(c) do
    "!#{char_to_string(-c)}"
  end

  defp describe_char_match(min..max) when is_integer(min) and is_integer(max) do
    "#{char_to_string(min)}..#{char_to_string(max)}"
  end

  defp describe_char_match(l) when is_list(l) do
    s = l |> Enum.map(fn e -> describe_char_match(e) end) |> Enum.join(", ")
    "[#{s}]"
  end

  @doc ~S"""
  The `digit/0` parser accepts a character in the range of 0..9

  ## Examples

      iex> alias Ergo.Context
      iex> import Ergo.Terminals
      iex> parser = digit()
      iex> assert %Context{status: :ok, ast: ?0, input: "000", index: 1, line: 1, col: 2} = Ergo.parse(parser, "0000")

      iex> alias Ergo.Context
      iex> import Ergo.Terminals
      iex> import Ergo.Terminals
      iex> parser = digit()
      iex> assert %Context{status: {:error, :unexpected_char}, message: "Expected: 0..9 Actual: A", input: "AAAA", index: 0, line: 1, col: 1} = Ergo.parse(parser, "AAAA")

      iex> alias Ergo.{Context, Parser}
      iex> import Ergo.Terminals
      iex> context = Context.new(&Ergo.Parser.call/2, "")
      iex> parser = digit()
      iex> assert %Context{status: {:error, :unexpected_eoi}, message: "Unexpected end of input", input: "", index: 0, line: 1, col: 1} = Parser.invoke(parser, context)
  """
  def digit() do
    char(?0..?9, label: "Digit")
  end

  @doc """
  The `alpha/0` parser accepts a single character in the range a..z or A..Z.

  ## Examples

      iex> alias Ergo.Context
      iex> import Ergo.Terminals
      iex> parser = alpha()
      iex> assert %Context{status: :ok, input: "ello World", ast: ?H, index: 1, line: 1, col: 2} = Ergo.parse(parser, "Hello World")

      iex> alias Ergo.Context
      iex> import Ergo.Terminals
      iex> parser = alpha()
      iex> assert %Context{status: :ok, input: "llo World", ast: ?e, index: 1, line: 1, col: 2} = Ergo.parse(parser, "ello World")

      iex> alias Ergo.Context
      iex> import Ergo.Terminals
      iex> parser = alpha()
      iex> assert %Context{status: {:error, :unexpected_char}, message: "Expected: [a..z, A..Z] Actual:  ", input: " World"} = Ergo.parse(parser, " World")
  """
  def alpha() do
    char([?a..?z, ?A..?Z], label: "Alpha")
  end

  @doc ~S"""
  The `ws/0` parser accepts a white space character and is equivalent to the \s regular expression.

  ## Examples

      iex> alias Ergo.Context
      iex> import Ergo.Terminals
      iex> parser = ws()
      iex> assert %Context{status: :ok, ast: ?\s, input: "World", index: 1, line: 1, col: 2}= Ergo.parse(parser, " World")

      iex> alias Ergo.Context
      iex> import Ergo.Terminals
      iex> parser = ws()
      iex> assert %Context{status: :ok, ast: ?\t, input: "World", index: 1, line: 1, col: 2} = Ergo.parse(parser, "\tWorld")

      iex> alias Ergo.Context
      iex> import Ergo.Terminals
      iex> parser = ws()
      iex> assert %Context{status: :ok, ast: ?\n, input: "World", index: 1, line: 2, col: 1} = Ergo.parse(parser, "\nWorld")

      iex> alias Ergo.Context
      iex> import Ergo.Terminals
      iex> parser = ws()
      iex> assert %Context{status: {:error, :unexpected_char}, message: "Expected: [\s, \t, \r, \n, \v] Actual: H", input: "Hello World"} = Ergo.parse(parser, "Hello World")
  """
  def ws() do
    char([?\s, ?\t, ?\r, ?\n, ?\v], label: "WhiteSpace")
  end

  @doc ~S"""

  The `wc/0` parser parses a word character and is analagous to the \w regular expression.

  ## Examples

      iex> alias Ergo.Context
      iex> import Ergo.Terminals
      iex> parser = wc()
      iex> assert %Context{status: :ok, ast: ?H, input: "ello World", index: 1, col: 2} = Ergo.parse(parser, "Hello World")

      iex> alias Ergo.Context
      iex> import Ergo.Terminals
      iex> parser = wc()
      iex> assert %Context{status: :ok, ast: ?0, input: " World", index: 1, col: 2} = Ergo.parse(parser, "0 World")

      iex> alias Ergo.Context
      iex> import Ergo.Terminals
      iex> parser = wc()
      iex> assert %Context{status: :ok, ast: ?_, input: "Hello", index: 1, col: 2} = Ergo.parse(parser, "_Hello")

      iex> alias Ergo.Context
      iex> import Ergo.Terminals
      iex> parser = wc()
      iex> assert %Context{status: {:error, :unexpected_char}, message: "Expected: [0..9, a..z, A..Z, _] Actual:  ", input: " Hello"} = Ergo.parse(parser, " Hello")
  """
  def wc() do
    char([?0..?9, ?a..?z, ?A..?Z, ?_], label: "WordChar")
  end

  @doc ~S"""
  The `literal/1` parser matches the specified string character by character.

  ## Examples

      iex> alias Ergo.Context
      iex> import Ergo.Terminals
      iex> parser = literal("Hello")
      iex> assert %Context{status: :ok, input: " World", ast: "Hello", index: 5, line: 1, col: 6} = Ergo.parse(parser, "Hello World")

      iex> alias Ergo.Context
      iex> import Ergo.Terminals
      iex> parser = literal("Hellx")
      iex> assert %Context{status: {:error, :unexpected_char}, message: "Expected: x Actual: o [in literal(Hellx)]", input: "o World", ast: [?l, ?l, ?e, ?H], index: 4, line: 1, col: 5} = Ergo.parse(parser, "Hello World")
  """
  def literal(s, opts \\ []) when is_binary(s) do
    map_fn = Keyword.get(opts, :map, nil)

    label =
      case Keyword.get(opts, :label, nil) do
        nil -> "literal(#{s})"
        l -> l
      end

    Parser.new(
      :literal,
      fn %Context{input: input, debug: debug} = ctx ->
        if debug, do: Logger.info("Trying Literal<#{label}> on [#{ellipsize(input, 20)}]")

        with %Context{status: :ok} = new_ctx <-
               literal_reduce(String.to_charlist(s), %{ctx | ast: []}) do
          new_ctx
          |> Context.ast_in_parsed_order()
          |> Context.ast_to_string()
          |> Context.ast_transform(map_fn)
        else
          %Context{message: message} = err_ctx ->
            %{err_ctx | message: "#{message} [in #{label}]"}
        end
      end,
      label: label
    )
  end

  defp literal_reduce(chars, ctx) do
    Enum.reduce_while(chars, ctx, fn c, ctx ->
      case Parser.invoke(char(c), ctx) do
        %Context{status: :ok} = new_ctx ->
          {:cont, %{new_ctx | ast: [new_ctx.ast | ctx.ast]}}

        %Context{status: {:error, error}, message: message} ->
          {:halt, %{ctx | status: {:error, error}, message: message}}
      end
    end)
  end

  @doc """
  The delimited_text/2 parser matches a sequence of text delimited `open_char` and
  `close_char`. Because it is expected that `open_char` may appear multiple times
  within the sequence it balances the tokens to ensure the right number of closing
  tokens is matched.

  # Examples
        iex> alias Ergo
        iex> alias Ergo.Context
        iex> import Ergo.Terminals
        iex> parser = delimited_text(?{, ?})
        iex> assert %Context{status: :ok, ast: "{return {foo: \\"bar\\", bar: {baz: \\"quux\\"}};}", input: ""} = Ergo.parse(parser, "{return {foo: \\"bar\\", bar: {baz: \\"quux\\"}};}")
        iex> assert %Context{status: :ok, ast: "{function b(y) {return x + y;}; return b;}", input: "foo"} = Ergo.parse(parser, "{function b(y) {return x + y;}; return b;}foo")
  """
  def delimited_text(open_char, close_char) do
    Parser.new(
      :nested,
      fn ctx ->
        ctx
        |> Context.push_state({0, []})
        |> nested_next_char({0, []}, open_char, close_char)
        |> Context.pop_state()
      end
    )
  end

  defp nested_next_char(ctx, {count, chars}, open_char, close_char) when open_char != close_char do
    with %{status: :ok, ast: ast} = new_ctx <- Context.next_char(ctx) do
      case ast do
        ^open_char ->
          nested_next_char(new_ctx, {count + 1, [ast | chars]}, open_char, close_char)

        ^close_char ->
          case count do
            0 ->
              %{
                new_ctx
                | status: {:error, :unexpected_char},
                  message:
                    "Expected #{char_to_string(open_char)} Actual: #{char_to_string(close_char)}"
              }

            _ ->
              count = count - 1
              case count do
                0 -> %{new_ctx | ast: [ast | chars] |> Enum.reverse() |> List.to_string()}
                _ -> nested_next_char(new_ctx, {count, [ast | chars]}, open_char, close_char)
              end
          end

        _char ->
          case count do
            0 ->
              %{
                new_ctx
                | status: {:error, :unexpected_char},
                  message:
                    "Expected #{char_to_string(open_char)} Actual: #{char_to_string(ast)}"
              }

            _ ->
              nested_next_char(new_ctx, {count, [ast | chars]}, open_char, close_char)
          end
      end
    end
  end
end
