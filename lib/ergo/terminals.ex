defmodule Ergo.Terminals do
  alias Ergo.{Context, Parser}
  import Ergo.Utils
  require Logger

  @moduledoc ~S"""
  `Ergo.Terminals` contains the terminal parsers, which are those parsers not
  parameterized with other parsers and therefore work more at the level of text
  than structure.
  """

  @doc """
  The eoi parser is a terminal parser that checks whether the input
  has been fully consumed. If there is input remaining to be parsed
  the return context status is set to :error.

  ## Examples
      iex> alias Ergo.{Context, Parser}
      iex> import Ergo.Terminals
      iex> ctx = Context.new("")
      iex> assert %Context{status: :ok, ast: nil} = Parser.invoke(ctx, eoi())

      iex> alias Ergo.{Context, Parser}
      iex> import Ergo.Terminals
      iex> ctx = Context.new("Hello World")
      iex> assert %Context{status: {:error, [{:not_eoi, {1, 1}, "Input not empty: Hello World"}]}, input: "Hello World"} = Parser.invoke(ctx, eoi())
  """
  def eoi() do
    Parser.terminal(
      :eoi,
      "eoi",
      fn
        %Context{input: ""} = ctx ->
          %{ctx | status: :ok, ast: nil}

        %Context{input: input} = ctx ->
          Context.add_error(ctx, :not_eoi, "Input not empty: #{ellipsize(input)}")
      end
    )
  end

  @doc """
  The `any/0` parser matches any character.

  # Examples
      iex> alias Ergo.Context
      iex> import Ergo.Terminals
      iex> parser = any()
      iex> assert %Context{status: :ok, ast: ?H} = Ergo.parse(parser, "H")
      iex> assert %Context{status: :ok, ast: ?e} = Ergo.parse(parser, "e")
      iex> assert %Context{status: :ok, ast: ?!} = Ergo.parse(parser, "!")
      iex> assert %Context{status: :ok, ast: ?0} = Ergo.parse(parser, "0")
  """
  def any() do
    Parser.terminal(
      :any,
      "any",
      fn ctx ->
        Context.next_char(ctx)
      end
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
      iex> assert %Context{status: {:error, [{:unexpected_char, {1, 1}, "Expected: |h| Actual: |H|"}]}, input: "Hello World"} = Ergo.parse(parser, "Hello World")

      iex> alias Ergo.Context
      iex> import Ergo.Terminals
      iex> parser = char(?H)
      iex> assert %Context{status: {:error, [{:unexpected_eoi, {1, 1}, "Unexpected end of input"}]}} = Ergo.parse(parser, "")

      iex> alias Ergo.Context
      iex> import Ergo.Terminals
      iex> parser = char(?A..?Z)
      iex> assert %Context{status: :ok, ast: ?H, input: "ello World", index: 1, line: 1, col: 2} = Ergo.parse(parser, "Hello World")

      iex> alias Ergo.Context
      iex> import Ergo.Terminals
      iex> parser = char(?a..?z)
      iex> assert %Context{status: {:error, [{:unexpected_char, {1, 1}, "Expected: |a|..|z| Actual: |H|"}]},input: "Hello World"} = Ergo.parse(parser, "Hello World")

      iex> alias Ergo.Context
      iex> import Ergo.Terminals
      iex> parser = char(?A..?Z)
      iex> assert %Context{status: {:error, [{:unexpected_eoi, {1, 1}, "Unexpected end of input"}]}} = Ergo.parse(parser, "")

      iex> alias Ergo.Context
      iex> import Ergo.Terminals
      iex> parser = char([?a..?z, ?A..?Z])
      iex> assert %Context{status: :ok, ast: ?H, input: "ello World", index: 1, line: 1, col: 2} = Ergo.parse(parser, "Hello World")

      iex> alias Ergo.Context
      iex> import Ergo.Terminals
      iex> parser = char([?a..?z, ?A..?Z])
      iex> assert %Context{status: {:error, [{:unexpected_char, {1, 1}, "Expected: [|a|..|z|, |A|..|Z|] Actual: |0|"}]}, input: "0000"} = Ergo.parse(parser, "0000")

      iex> alias Ergo.Context
      iex> import Ergo.Terminals
      iex> parser = char(-?0)
      iex> assert %Context{status: {:error, [{:unexpected_char, {1, 1}, "Should not have matched |0|"}]}, input: "0000"} = Ergo.parse(parser, "0000")

      iex> alias Ergo.Context
      iex> import Ergo.Terminals
      iex> parser = char(-?a)
      iex> assert %Context{status: :ok, input: "000", ast: ?0, index: 1, col: 2} = Ergo.parse(parser, "0000")
  """
  def char(c, opts \\ [])

  def char(c, opts) when is_integer(c) and c >= 0 do
    label = Keyword.get(opts, :label, describe_char_match(c))

    Parser.terminal(
      :char,
      label,
      fn ctx ->
        case Context.next_char(ctx) do
          %Context{status: :ok, ast: ^c} = new_ctx ->
            new_ctx

          %Context{status: :ok, ast: u} ->
            Context.add_error(ctx, :unexpected_char, "Expected: #{describe_char_match(c)} Actual: #{describe_char_match(u)}")

          %Context{status: {:error, _}} = new_ctx ->
            new_ctx
        end
      end
    )
  end

  def char(c, opts) when is_integer(c) and c < 0 do
    c = -c

    label = Keyword.get(opts, :label, describe_char_match(c))

    Parser.terminal(
      :not_char,
      label,
      fn ctx ->
        case Context.next_char(ctx) do
          %Context{status: :ok, ast: ^c} ->
            Context.add_error(ctx, :unexpected_char, "Should not have matched #{describe_char_match(c)}")

          %Context{status: :ok, ast: _} = new_ctx ->
            new_ctx

          %Context{status: {:error, _}} = err_ctx ->
            err_ctx
        end
      end
    )
  end

  def char(min..max, opts) when is_integer(min) and is_integer(max) do
    label = Keyword.get(opts, :label, describe_char_match(min..max))

    Parser.terminal(
      :char_range,
      label,
      fn ctx ->
        case Context.next_char(ctx) do
          %Context{status: :ok, ast: c} = new_ctx when c in min..max ->
            new_ctx

          %Context{status: :ok, ast: c} ->
            Context.add_error(ctx, :unexpected_char, "Expected: #{describe_char_match(min..max)} Actual: #{describe_char_match(c)}")

          %Context{status: {:error, _}} = new_ctx ->
            new_ctx
        end
      end
    )
  end

  def char(l, opts) when is_list(l) do
    label = Keyword.get(opts, :label, "[#{inspect(l)}]")
    parsers = Enum.map(l, fn c -> char(c) end)

    Parser.terminal(
      :char_list,
      label,
      fn ctx ->
        with %Context{status: :ok} = peek_ctx <- Context.peek(ctx) do
          err_ctx = Context.add_error(ctx, :unexpected_char, "Expected: #{describe_char_match(l)} Actual: #{describe_char_match(peek_ctx.ast)}")

          Enum.reduce_while(parsers, err_ctx, fn char_matcher, err_ctx ->
            case Parser.invoke(ctx, char_matcher) do
              %Context{status: :ok} = new_ctx -> {:halt, new_ctx}
              _no_match -> {:cont, err_ctx}
            end
          end)
        end
      end
    )
  end

  @doc """
  The not_char matcher accepts a char or a list of chars and will match any
  char that is not in the list.

  # Examples
      iex> alias Ergo.Context
      iex> import Ergo.Terminals
      iex> parser = not_char(?0)
      iex> assert %Context{status: {:error, [{:unexpected_char, {1, 1}, "Should not have matched |0|"}]}, input: "0000"} = Ergo.parse(parser, "0000")
      iex> assert %Context{status: :ok, ast: ?1} = Ergo.parse(parser, "1111")
      iex> parser = not_char([?{, ?}])
      iex> assert %Context{status: {:error, [{:unexpected_char, {1, 1}, "Should not have matched |{|"}]}, input: "{}"} = Ergo.parse(parser, "{}")
      iex> assert %Context{status: {:error, [{:unexpected_char, {1, 1}, "Should not have matched |}|"}]}, input: "}"} = Ergo.parse(parser, "}")
  """
  def not_char(c_or_l, opts \\ [])

  def not_char(char, opts) when is_integer(char) do
    not_char([char], opts)
  end

  def not_char(l, opts) when is_list(l) do
    label = Keyword.get(opts, :label, "?-[#{inspect(l)}]")
    Parser.terminal(
      :not_char_list,
      label,
      fn ctx ->
        with %Context{status: :ok, ast: ast} <- Context.peek(ctx) do
          case Enum.member?(l, ast) do
            true ->
              Context.add_error(ctx, :unexpected_char, "Should not have matched #{describe_char_match(ast)}")
            false ->
              Context.next_char(ctx)
          end
        end
      end
    )
  end

  defp describe_char_match(c) when is_integer(c) and c < 0 do
    "!|" <> <<-c::utf8>> <> "|"
  end

  defp describe_char_match(c) when is_integer(c) do
    "|" <> <<c::utf8>> <> "|"
  end

  defp describe_char_match(min..max) when is_integer(min) and is_integer(max) do
    "|#{<<min::utf8>>}|..|#{<<max::utf8>>}|"
  end

  defp describe_char_match(l) when is_list(l) do
    "[" <> Enum.map_join(l, ", ", &describe_char_match/1) <> "]"
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
      iex> assert %Context{status: {:error, [{:unexpected_char, {1, 1}, "Expected: |0|..|9| Actual: |A|"}]}, input: "AAAA", index: 0, line: 1, col: 1} = Ergo.parse(parser, "AAAA")

      iex> alias Ergo.{Context, Parser}
      iex> import Ergo.Terminals
      iex> ctx = Context.new("")
      iex> parser = digit()
      iex> assert %Context{status: {:error, [{:unexpected_eoi, {1, 1}, "Unexpected end of input"}]}, input: "", index: 0, line: 1, col: 1} = Parser.invoke(ctx, parser)
  """
  def digit(options \\ []) do
    label = Keyword.get(options, :label, "digit")
    char(?0..?9, label: label)
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
      iex> assert %Context{status: {:error, [{:unexpected_char, {1, 1}, "Expected: [|a|..|z|, |A|..|Z|] Actual: | |"}]}, input: " World"} = Ergo.parse(parser, " World")
  """
  def alpha(options \\ []) do
    label = Keyword.get(options, :label, "alpha")
    char([?a..?z, ?A..?Z], label: label)
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
      iex> assert %Context{status: {:error, [{:unexpected_char, {1, 1}, "Expected: [| |, |\t|, |\r|, |\n|, |\v|] Actual: |H|"}]}, input: "Hello World"} = Ergo.parse(parser, "Hello World")
  """
  def ws(options \\ []) do
    label = Keyword.get(options, :label, "ws")
    char([?\s, ?\t, ?\r, ?\n, ?\v], label: label)
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
      iex> assert %Context{status: {:error, [{:unexpected_char, {1, 1}, "Expected: [|0|..|9|, |a|..|z|, |A|..|Z|, |_|] Actual: | |"}]}, input: " Hello"} = Ergo.parse(parser, " Hello")
  """
  def wc() do
    char([?0..?9, ?a..?z, ?A..?Z, ?_], label: "wc")
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
      iex> parser = literal("Hello")
      iex> assert %Context{status: {:error, [{:bad_literal, {1, 5}, "literal<Hello>"}, {:unexpected_char, {1, 5}, "Expected: |o| Actual: |x|"}]}, input: "x World", index: 4, line: 1, col: 5} = Ergo.parse(parser, "Hellx World")
  """
  def literal(s, opts \\ []) when is_binary(s) do
    map_fn = Keyword.get(opts, :map, nil)
    label = Keyword.get(opts, :label, "literal<#{s}>")

    char_parsers = Enum.map(String.to_charlist(s), &(char(&1)))

    Parser.terminal(
      :literal,
      label,
      fn %Context{} = ctx ->
        case reduce_chars(char_parsers, ctx) do
          %{status: :ok} = ok_ctx ->
            ok_ctx
            |> Context.ast_in_parsed_order()
            |> Context.ast_to_string()
            |> Context.ast_transform(map_fn)

          %{status: {:error, _}} = err_ctx ->
            Context.add_error(err_ctx, :bad_literal, label)
        end
      end
    )
  end

  defp reduce_chars(char_parsers, ctx) do
    Enum.reduce_while(char_parsers, %{ctx | ast: []}, fn char_parser, ctx ->
      case Parser.invoke(ctx, char_parser) do
        %Context{status: :ok} = ok_ctx ->
          {:cont, %{ok_ctx | ast: [ok_ctx.ast | ctx.ast]}}

        %Context{status: {:error, [{error_id, {_line, _col}, message}]}} ->
          {:halt, Context.add_error(ctx, error_id, message)}
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
  def delimited_text(open_char, close_char, opts \\ []) do
    label = Keyword.get(opts, :label, "delimited_text<#{<<open_char::utf8>>}, #{<<close_char::utf8>>}>")
    Parser.terminal(
      :delimited_text,
      label,
      fn ctx -> nested_next_char(ctx, {0, []}, open_char, close_char) end
    )
  end

  defp nested_next_char(ctx, {count, chars}, open_char, close_char) when open_char != close_char do
    with %{status: :ok, ast: ast} = new_ctx <- Context.next_char(ctx) do
      case ast do
        ^open_char ->
          nested_next_char(new_ctx, {count + 1, [ast | chars]}, open_char, close_char)

        ^close_char ->
          case count do
            0 -> Context.add_error(new_ctx, :unexpected_char, "Expected |#{describe_char_match(open_char)}| Actual: |#{describe_char_match(close_char)}|")

            _ ->
              count = count - 1
              case count do
                0 -> %{new_ctx | ast: [ast | chars] |> Enum.reverse() |> List.to_string()}
                _ -> nested_next_char(new_ctx, {count, [ast | chars]}, open_char, close_char)
              end
          end

        _char ->
          case count do
            0 -> Context.add_error(new_ctx, :unexpected_char, "Expected |#{describe_char_match(open_char)}| Actual: |#{describe_char_match(ast)}|")

            _ ->
              nested_next_char(new_ctx, {count, [ast | chars]}, open_char, close_char)
          end
      end
    end
  end
end
