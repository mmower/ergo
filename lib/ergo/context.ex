defmodule Ergo.Context do
  alias __MODULE__

  alias Ergo.Utils

  @moduledoc """

  `Ergo.Context` defines the `Context` struct that is used to maintain parser state as the various
  parsers work, and various functions for creating & manipulating contexts.

  # Fields

  * `invoke_fn`

  The `invoke_fn` defines the parsing entry point used for calling parsers.

  * `status`

  When a parser returns it either sets `status` to `:ok` to indicate that it was successful or to a tuple
  `{:error, :error_atom}` where `error_atom` is an atom indiciting the specific type of error. It may optionally
  set the `message` field to a human readable message.

  * `message`

  A human readable version of any error raised.

  * `input`

  The binary input being parsed.

  * `index`

  Represents the position in the input which has been read so far. Initially 0 it increments for each character processed.

  * `line`

  Represents the current line of the input. Initially 1 it increments whenever a `\n` is read from the input.

  * `col`

  Represents the current column of the input. Initially 1 it is incremented every time a character is read from the input and automatically resets whenever a `\n` is read.

  * `ast`

  Represents the current data structure being built from the input.

  * `tracks`

  Parsers for which `track: true` is specified (by default this is most of the
  combinator parsers but not the terminal parsers) will add themselves to the
  `Context` tracks in the form of `{ref, index}`. If the same parser attempts
  to add itself a second time at the same index an error is thrown because a
  cycle has been detected.

  """

  defstruct invoke_fn: nil,
            status: :ok,
            message: nil,
            input: "",
            consumed: "",
            index: 0,
            line: 1,
            col: 1,
            entry_points: [],
            data: %{},
            ast: nil,
            parser: nil,
            called_from: [],
            caller_logging: true,
            tracks: MapSet.new(),
            depth: 0,
            depth_pad: 2,
            debug_override: false,
            trace: [],
            process: []

  @doc """
  `new` returns a newly initialised `Context` with `input` set to the string passed in.

  ## Examples:

    iex> Context.new(&Ergo.Parser.call/2, "Hello World")
    %Context{status: :ok, input: "Hello World", line: 1, col: 1, index: 0, tracks: %MapSet{}, invoke_fn: &Ergo.Parser.call/2}
  """
  def new(invoke_fn, input \\ "", options \\ [])
      when is_function(invoke_fn) and is_binary(input) do
    ast = Keyword.get(options, :ast, nil)
    data = Keyword.get(options, :data, %{})
    padding = Keyword.get(options, :padding, 2)
    override = Keyword.get(options, :debug, false)

    %Context{
      invoke_fn: invoke_fn,
      input: input,
      ast: ast,
      data: data,
      depth_pad: padding,
      debug_override: override
    }
  end

  @doc ~S"""
  Clears the value of the status and ast fields to ensure that the wrong status information cannot be returned from a child parser.

  ## Examples

      iex> context = Context.new(&Ergo.Parser.call/2, "Hello World")
      iex> context = %{context | status: {:error, :inexplicable_error}, ast: true}
      iex> context = Context.reset_status(context)
      iex> assert %Context{status: :ok, ast: nil} = context
  """
  def reset_status(%Context{} = ctx) do
    %{ctx | status: :ok, ast: nil, message: nil}
  end

  @doc ~S"""
  Returns truthy value if the parser referred to by `ref` has already been called for the index `index`.

  ## Examples

    iex> alias Ergo.Context
    iex> parser_ref = 123
    iex> context = Context.new(&Ergo.Parser.call/2, "Hello World") |> Context.track_parser(parser_ref)
    iex> assert Context.parser_tracked?(context, parser_ref)
  """
  def parser_tracked?(%Context{tracks: tracks, index: index}, ref) when is_integer(ref) do
    MapSet.member?(tracks, {ref, index})
  end

  @doc ~S"""
  Updates the `Context` to track that the parser referred to by `ref` has been called for the index `index`.

  Examples:

      iex> alias Ergo.Context
      iex> import Ergo.Terminals
      iex> context = Context.new(&Ergo.Parser.call/2, "Hello World")
      iex> parser = literal("Hello")
      iex> context2 = Context.track_parser(context, parser.ref)
      iex> assert MapSet.member?(context2.tracks, {parser.ref, 0})
  """
  def track_parser(%Context{tracks: tracks, index: index} = ctx, ref) when is_integer(ref) do
    %{ctx | tracks: MapSet.put(tracks, {ref, index})}
  end

  @doc """
  Reads the next character from the `input` of the passed in `Context`.

  If the `input` is empty returns `status: {:error, :unexpected_eoi}`.

  Otherwise returns a new `Context` setting `ast` to the character read and incrementing positional variables such as `index`, `line`, and `column` appropriately.

  ## Examples

    iex> context = Context.next_char(Context.new(&Ergo.Parser.call/2, ""))
    iex> assert %Context{status: {:error, :unexpected_eoi}, message: "Unexpected end of input"} = context

    iex> context = Context.next_char(Context.new(&Ergo.Parser.call/2, "Hello World"))
    iex> assert %Context{status: :ok, input: "ello World", ast: ?H, index: 1, line: 1, col: 2} = context
  """
  def next_char(context)

  def next_char(%Context{input: ""} = ctx) do
    %{
      ctx
      | status: {:error, :unexpected_eoi},
        message: "Unexpected end of input"
    }
  end

  def next_char(
        %Context{input: input, consumed: consumed, index: index, line: line, col: col} = ctx
      ) do
    <<char::utf8, rest::binary>> = input
    {new_index, new_line, new_col} = wind_forward({index, line, col}, char == ?\n)

    %{
      ctx
      | status: :ok,
        input: rest,
        consumed: consumed <> List.to_string([char]),
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
      iex> context = Context.new(&Ergo.Parser.call/2, "Hello")
      iex> assert %Context{status: :ok, ast: ?H, input: "ello", index: 1, line: 1, col: 2} = Context.peek(context)

      iex> context = Context.new(&Ergo.Parser.call/2, "")
      iex> assert %Context{status: {:error, :unexpected_eoi}, message: "Unexpected end of input", index: 0, line: 1, col: 1} = Context.peek(context)
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
      iex> context = Ergo.Context.new(&Ergo.Parser.call/2, "", ast: ["Hello", nil, "World", nil])
      iex> assert %Context{ast: ["Hello", "World"]} = Context.ast_without_ignored(context)
  """
  def ast_without_ignored(%Context{ast: ast} = ctx) do
    %{ctx | ast: Enum.reject(ast, &is_nil/1)}
  end

  @doc ~S"""
  Because we build ASTs using lists they end up in reverse order. This method reverses the AST back
  to in-parse-order

  ## Examples
      iex> context = Ergo.Context.new(&Ergo.Parser.call/2, "", ast: [4, 3, 2, 1])
      iex> assert %Context{ast: [1, 2, 3, 4]} = Context.ast_in_parsed_order(context)
  """
  def ast_in_parsed_order(%Context{ast: ast} = ctx) do
    %{ctx | ast: Enum.reverse(ast)}
  end

  @doc ~S"""
  Where an AST has been built from individual characters and needs to be converted to a string

  ## Examples
      iex> context = Ergo.Context.new(&Ergo.Parser.call/2, "", ast: [?H, ?e, ?l, ?l, ?o])
      iex> assert %Context{ast: "Hello"} = Context.ast_to_string(context)
  """
  def ast_to_string(%Context{ast: ast} = ctx) do
    %{ctx | ast: List.to_string(ast)}
  end

  @doc ~S"""
  Called to perform an arbitrary transformation on the AST value of a Context.

  ## Examples

      iex> alias Ergo.Context
      iex> context = Context.new(&Ergo.Parser.call/2, "", ast: "Hello World")
      iex> assert %Context{ast: "Hello World"} = Context.ast_transform(context, &Function.identity/1)

      iex> alias Ergo.Context
      iex> context = Context.new(&Ergo.Parser.call/2, "", ast: "Hello World")
      iex> assert %Context{ast: 11} = Context.ast_transform(context, &String.length/1)

      iex> alias Ergo.Context
      iex> context = Context.new(&Ergo.Parser.call/2, "", ast: "Hello World")
      iex> assert %Context{ast: "Hello World"} = Context.ast_transform(context, nil)
  """
  def ast_transform(%Context{ast: ast} = ctx, fun) do
    case fun do
      f when is_function(f) -> %{ctx | ast: f.(ast)}
      nil -> ctx
    end
  end

  def transform(%Context{} = ctx, tr_fn) when is_function(tr_fn) do
    tr_fn.(ctx)
  end

  def trace(%Context{depth: depth, depth_pad: padd, trace: trace} = ctx, true, message) do
    depth_field = String.pad_leading(to_string(depth), padd, "0")
    %{ctx | trace: trace ++ ["[#{depth_field}] #{message}"]}
  end

  def trace(%Context{} = ctx, false, _message) do
    ctx
  end

  def trace_match(%Context{status: :ok, ast: ast} = ctx, debug, type, label) do
    trace(ctx, debug, "#{type} #{label} matched:#{inspect(ast)}")
  end

  def trace_match(%Context{status: {:error, reason}} = ctx, debug, type, label) do
    trace(ctx, debug, "#{type} #{label} failed:#{inspect(reason)}")
  end

  def clip(%Context{input: input}, length \\ 40) do
    "\"#{String.trim_trailing(Utils.ellipsize(input, length))}\""
  end

  def inc_depth(%Context{depth: depth} = ctx) do
    %{ctx | depth: depth + 1}
  end

  def dec_depth(%Context{depth: depth} = ctx) do
    %{ctx | depth: depth - 1}
  end
end
