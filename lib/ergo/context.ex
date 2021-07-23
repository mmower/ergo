defmodule Ergo.Context do
  alias __MODULE__

  defmodule CycleError do
    alias __MODULE__

    defexception [:message]

    def exception({{_ref, description, _index, line, col}, %{tracks: tracks}}) do
      message =
        Enum.reduce(
          tracks,
          "Ergo has detected a cycle in #{description} and is aborting parsing at: #{line}:#{col}",
          fn {_ref, description, _index, _line, _col}, msg ->
            msg <> "\n#{description}"
          end
        )

      %CycleError{message: message}
    end
  end

  @moduledoc """
  `Ergo.Context` defines the `Context` record type and functions to create and manipulate them.

  # Fields

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

  * `char`

  Represents the last character read from the input.

  * `ast`

  Represents the current data structure being built from the input.

  * `debug`

  When set to 'true' parsers will attempt to log their behaviours as they run using the Elixir Logger at the :info level.

  * `tracks`

  Parsers for which `track: true` is specified (by default this is most of the
  combinator parsers but not the terminal parsers) will add themselves to the
  `Context` tracks in the form of `{ref, index}`. If the same parser attempts
  to add itself a second time at the same index an error is thrown because a
  cycle has been detected.

  """

  defstruct status: :ok,
            message: nil,
            input: "",
            index: 0,
            line: 1,
            col: 1,
            char: 0,
            ast: nil,
            debug: false,
            tracks: []

  @doc """
  Returns a newly initialised `Context` with `input` set to the string passed in.

  ## Examples:

    iex> Context.new("Hello World")
    %Context{status: :ok, input: "Hello World", line: 1, col: 1, index: 0, debug: false, tracks: []}
  """
  def new(input, debug \\ false) when is_binary(input) do
    %Context{input: input, debug: debug}
  end

  @doc """
  Returns a newly initialised `Context` with an empty `input`.

  ## Examples

    iex> Context.new()
    %Context{}
  """
  def new() do
    %Context{}
  end

  @doc ~S"""
  Clears the value of the status and ast fields to ensure that the wrong status information cannot be returned from a child parser.

  ## Examples

      iex> context = Context.new("Hello World")
      iex> context = %{context | status: {:error, :inexplicable_error}, ast: true}
      iex> context = Context.reset_status(context)
      iex> assert %Context{status: :ok, ast: nil} = context
  """
  def reset_status(%Context{} = ctx) do
    %{ctx | status: :ok, ast: nil}
  end

  @doc ~S"""
  We track which parsers have operated on the input.

  ## Examples

      First example checks that we keep references
      iex> alias Ergo.Context
      iex> import Ergo.{Terminals, Combinators}
      iex> context = Context.new("Hello World")
      iex> parser = many(char(?H))
      iex> track = {parser.ref, parser.description, 0, 1, 1}
      iex> assert %Context{tracks: [^track]} = context2 = Context.update_tracks(context, parser.ref, parser.description)
      iex> parser2 = many(char(?e))
      iex> track2 = {parser2.ref, parser2.description, 0, 1, 1}
      iex> assert %Context{tracks: [^track2, ^track]} = Context.update_tracks(context2, parser2.ref, parser2.description)

      Second example checks that we throw if we get a cycle
      iex> import Ergo.{Terminals, Combinators}
      iex> parser = many(choice([many(ws()), char(?})]))
      iex> assert_raise Ergo.Context.CycleError, fn -> Ergo.parse(parser, "}}}") end
  """
  def update_tracks(
        %Context{index: index, line: line, col: col, tracks: tracks} = ctx,
        ref,
        description
      ) do
    new_track = {ref, description, index, line, col}

    if Enum.find(tracks, false, fn track -> new_track == track end) do
      raise Ergo.Context.CycleError, {new_track, ctx}
    else
      %{ctx | tracks: [new_track | tracks]}
    end
  end

  @doc """
  Reads the next character from the `input` of the passed in `Context`.

  If the `input` is empty returns `status: {:error, :unexpected_eoi}`.

  Otherwise returns a new `Context` setting `char` to the character read and incrementing positional variables such as `index`, `line`, and `column` appropriately.

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
