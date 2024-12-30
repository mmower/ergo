defmodule Ergo.Context do
  alias __MODULE__

  alias Ergo.Utils

  @moduledoc """

  `Ergo.Context` defines the `Context` struct that is used to maintain parser state as the various
  parsers work, and various functions for creating & manipulating contexts.

  # Fields

  * `status`

  When a parser returns it either sets `status` to `:ok` to indicate that it was successful or to a tuple
  `{:error, reasons}` where reasons is a list of tuples representing a sequence of errors. Each tuple is of
  the form `{code, message}` where code is an atom indiciting the specific type of error and the message
  contains additional human-focused information that may be helpful in diagnosing the problem.

  * `input`

  The binary input being parsed.

  * `consumed`

  The binary input that has already been consumed by parsing.

  * `index`

  Represents the position in the input which has been read so far. Initially 0 it increments for each character processed.

  * `line`

  Represents the current line of the input. Initially 1 it increments whenever a `\n` is read from the input.

  * `col`

  Represents the current column of the input. Initially 1 it is incremented every time a character is read from the input and automatically resets whenever a `\n` is read.

  * `entry_points`

  A list of `Parser` entry points

  * `data`

  Map containing user-data that the parsers can use to pass information between them.

  * `ast`

  Represents the current data structure being built from the input.

  * `parser`

  The current parser.

  * `tracks`

  Parsers will add themselves to the `Context` tracks in the form of `{ref, index}`.
  If the same parser attempts to add itself a second time at the same index an
  error is thrown because a cycle has been detected.

  * `depth`

  As nested parsers are called the depth field will be updated to reflect the
  number of levels of nesting for the current parser.

  * `captures`

  A map of data that can be captured from ASTs using the capture parser.

  """

  defstruct id: nil,
            created_at: nil,
            status: :ok,
            serial: 0,
            input: "",
            consumed: [],
            index: 0,
            line: 1,
            col: 1,
            entry_points: [],
            data: %{},
            ast: nil,
            parser: nil,
            tracks: %{},
            depth: 0,
            parsers: [],
            commit: 0,
            captures: %{}

  @doc """
  `new` returns a newly initialised `Context` with `input` set to the string passed in.

  ## Examples:
    iex> alias Ergo.Context
    iex> assert %Context{status: :ok, input: "Hello World", line: 1, col: 1, index: 0, tracks: %{}} = Context.new("Hello World")
  """
  def new(input \\ "", options \\ []) when is_binary(input) do
    created_at = Calendar.strftime(DateTime.utc_now(), "%y-%m-%d-%H-%M-%S")

    id = Keyword.get(options, :id, created_at)
    ast = Keyword.get(options, :ast, nil)
    data = Keyword.get(options, :data, %{})

    %Context{
      id: id,
      created_at: created_at,
      input: input,
      ast: ast,
      data: data
    }
  end

  @doc ~S"""
  Clears the value of the status and ast fields to ensure that the wrong status information cannot be returned from a child parser.

  ## Examples

      iex> context = Context.new("Hello World")
      iex> context = %{context | status: {:error, [{:inexplicable_error, "What the…"}]}, ast: true}
      iex> context = Context.reset_status(context)
      iex> assert %Context{status: :ok, ast: nil} = context
  """
  def reset_status(%Context{} = ctx) do
    %{ctx | status: :ok, ast: nil}
  end

  def push_parser(
        %Context{parser: parser, parsers: parser_stack} = ctx,
        %Ergo.Parser{} = next_parser
      ) do
    %{ctx | parsers: [parser | parser_stack], parser: next_parser}
  end

  def pop_parser(%Context{parsers: [parent_parser | parser_stack]} = ctx) do
    %{ctx | parsers: parser_stack, parser: parent_parser}
  end

  def parent_parser(%Context{parsers: [parent_parser | _]}) do
    parent_parser
  end

  @doc """
  ## Examples
      iex> alias Ergo.Context
      iex> context =
      ...>  Context.new("Hello World")
      ...>  |> Context.add_error(:unexpected_char, "Expected: |e| Actual: |.|")
      iex> assert is_nil(context.ast)
      iex> assert {:error, [{:unexpected_char, {1, 1}, "Expected: |e| Actual: |.|"}]} = context.status

      iex> alias Ergo.Context
      iex> context =
      ...>  Context.new("Hello World")
      ...>  |> Context.add_error(:unexpected_char, "Expected: |e| Actual: |.|")
      ...>  |> Context.add_error(:literal_failed, "Expected 'end'")
      iex> assert is_nil(context.ast)
      iex> assert {:error, [{:literal_failed, {1, 1}, "Expected 'end'"}, {:unexpected_char, {1, 1}, "Expected: |e| Actual: |.|"}]} = context.status
  """
  def add_error(ctx, error_id, message \\ "")

  def add_error(%Context{status: :ok, line: line, col: col} = ctx, error_id, message) do
    %{ctx | ast: nil, status: {:error, [{error_id, {line, col}, message}]}}
  end

  def add_error(%Context{status: {code, errors}, line: line, col: col} = ctx, error_id, message) do
    %{ctx | ast: nil, status: {code, [{error_id, {line, col}, message} | errors]}}
  end

  def make_error_fatal(%Context{status: status} = ctx) do
    %{ctx | status: put_elem(status, 0, :fatal)}
  end

  @doc ~S"""
  Returns truthy value if the parser referred to by `ref` has already been called for the index `index`.

  ## Examples

    iex> alias Ergo.Context
    iex> parser_ref = 123
    iex> context = Context.new("Hello World") |> Context.track_parser(parser_ref, :foo)
    iex> assert Context.parser_tracked?(context, parser_ref)
  """
  def parser_tracked?(%Context{tracks: tracks, index: index}, ref) when is_integer(ref) do
    Map.has_key?(tracks, {index, ref})
  end

  @doc ~S"""
  Updates the `Context` to track that the parser referred to by `ref` has been called for the index `index`.

  Examples:

      iex> alias Ergo.Context
      iex> import Ergo.Terminals
      iex> context = Context.new("Hello World")
      iex> parser = literal("Hello")
      iex> context2 = Context.track_parser(context, parser.ref, :foo)
      iex> assert Map.has_key?(context2.tracks, {0, parser.ref})
  """
  def track_parser(%Context{tracks: tracks, index: index, line: line, col: col} = ctx, ref, data)
      when is_integer(ref) do
    %{
      ctx
      | tracks: Map.put(tracks, {index, ref}, {line, col, data})
    }
  end

  @doc """
  Reads the next character from the `input` of the passed in `Context`.

  If the `input` is empty returns `status: {:error, :unexpected_eoi}`.

  Otherwise returns a new `Context` setting `ast` to the character read and incrementing positional variables such as `index`, `line`, and `column` appropriately.

  ## Examples

    iex> context = Context.next_char(Context.new(""))
    iex> assert %Context{status: {:error, [{:unexpected_eoi, {1, 1}, "Unexpected end of input"}] }} = context

    iex> context = Context.next_char(Context.new("Hello World"))
    iex> assert %Context{status: :ok, input: "ello World", ast: ?H, index: 1, line: 1, col: 2} = context
  """
  def next_char(context)

  def next_char(%Context{input: ""} = ctx) do
    Context.add_error(ctx, :unexpected_eoi, "Unexpected end of input")
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
        consumed: [char | consumed],
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
      iex> assert %Context{status: :ok, ast: ?H, input: "ello", index: 1, line: 1, col: 2} = Context.peek(context)

      iex> context = Context.new("")
      iex> assert %Context{status: {:error, [{:unexpected_eoi, {1, 1}, "Unexpected end of input"}]}, index: 0, line: 1, col: 1} = Context.peek(context)
  """
  def peek(%Context{} = ctx) do
    with %Context{status: :ok} = peek_ctx <- next_char(ctx) do
      peek_ctx
    end
  end

  def set_ast(%Context{} = ctx, new_ast) do
    %{ctx | ast: new_ast}
  end

  def commit(%Context{commit: commit_level} = ctx) do
    %{ctx | commit: commit_level + 1}
  end

  def uncommit(%Context{commit: commit_level} = ctx) when commit_level > 0 do
    %{ctx | commit: commit_level - 1}
  end

  @doc ~S"""
  The `ignore` parser matches but returns a nil for the AST. Parsers like `sequence` accumulate these nil values.
  Call this function to remove them

  ## Examples
      iex> context = Ergo.Context.new("", ast: ["Hello", nil, "World", nil])
      iex> assert %Context{ast: ["Hello", "World"]} = Context.ast_without_ignored(context)
  """
  def ast_without_ignored(%Context{ast: ast} = ctx) do
    %{ctx | ast: Enum.reject(ast, &is_nil/1)}
  end

  @doc ~S"""
  Because we build ASTs using lists they end up in reverse order. This method reverses the AST back
  to in-parse-order

  ## Examples
      iex> context = Ergo.Context.new("", ast: [4, 3, 2, 1])
      iex> assert %Context{ast: [1, 2, 3, 4]} = Context.ast_in_parsed_order(context)
  """
  def ast_in_parsed_order(%Context{ast: ast} = ctx) do
    %{ctx | ast: Enum.reverse(ast)}
  end

  @doc ~S"""
  Where an AST has been built from individual characters and needs to be converted to a string

  ## Examples
      iex> context = Ergo.Context.new("", ast: [?H, ?e, ?l, ?l, ?o])
      iex> assert %Context{ast: "Hello"} = Context.ast_to_string(context)
  """
  def ast_to_string(%Context{ast: ast} = ctx) do
    %{ctx | ast: List.to_string(ast)}
  end

  @doc ~S"""
  Called to perform an arbitrary transformation on the AST value of a Context.

  ## Examples

      iex> alias Ergo.Context
      iex> context = Context.new("", ast: "Hello World")
      iex> assert %Context{ast: "Hello World"} = Context.ast_transform(context, &Function.identity/1)

      iex> alias Ergo.Context
      iex> context = Context.new("", ast: "Hello World")
      iex> assert %Context{ast: 11} = Context.ast_transform(context, &String.length/1)

      iex> alias Ergo.Context
      iex> context = Context.new("", ast: "Hello World")
      iex> assert %Context{ast: "Hello World"} = Context.ast_transform(context, nil)
  """
  def ast_transform(%Context{ast: ast} = ctx, fun) do
    case fun do
      f when is_function(f) -> %{ctx | ast: f.(ast)}
      nil -> ctx
    end
  end

  # def transform(%Context{} = ctx, tr_fn) when is_function(tr_fn) do
  #   tr_fn.(ctx)
  # end

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
