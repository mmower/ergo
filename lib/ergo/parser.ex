defmodule Ergo.Parser do
  alias __MODULE__
  alias Ergo.{Context, ParserRefs}

  require Logger

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
  `Ergo.Parser` contains the Parser record type. Ergo parsers are anonymous functions but we embed
  them in a `Parser` record that can hold arbitrary metadata. The primary use for the metadata is
  the storage of debugging information.
  """
  defstruct [
    type: nil,
    parser_fn: nil,
    ref: nil,
    description: "#"
  ]

  @doc ~S"""
  `new/2` creates a new `Parser` from the given parsing function and with the specified metadata.
  """
  def new(type, parser_fn, meta \\ []) when is_atom(type) and is_function(parser_fn) do
    %Parser{type: type, parser_fn: parser_fn, ref: ParserRefs.ref_for(type)}
    |> Map.merge(Enum.into(meta, %{}))
  end

  @doc ~S"""
  `invoke/2` is the main entry point for the parsing process. It looks up the parser control function within
  the `Context` and uses it to run the given `parser`.

  This indirection allows a different control function to be specified, e.g. by the diagnose entry point
  which can wrap the parser call, while still calling the same parsing function (i.e. we are not introducing
  debugging variants of the parsers that could be subject to different behaviours)
  """

  def invoke(%Parser{} = parser, %Context{invoke_fn: invoke_fn} = ctx) do
    invoke_fn.(parser, ctx)
  end

  @doc ~S"""
  `call/2` invokes the specified parser by calling its parsing function with the specified context having
  first reset the context status.
  """
  def call(%Parser{parser_fn: parser_fn} = parser, %Context{} = ctx) do
    ctx
    |> Context.reset_status()
    |> track_parser(parser)
    |> parser_fn.()
  end

  def diagnose(%Parser{} = parser, %Context{} = ctx) do
    Logger.info("Diagnose: #{parser.type}")
    new_ctx = Parser.call(parser, ctx)
    Logger.info("Back from: #{parser.type}")
    new_ctx
  end

  @doc ~S"""
  `track_parser` first checks if the parser has already been tracked for the current input index and, if it has,
  raises a `CycleError` to indicate the parser is in a loop. Otherwise it adds the parser at the current index.

  ## Examples

    iex> alias Ergo.Context
    iex> import Ergo.{Terminals, Combinators}
    iex> context = Context.new("Hello World")
    iex> parser = many(char(?H))
    iex> context2 = track_parser(context, parser)
    iex> assert Context.parser_tracked?(context2, parser)
  """
  def track_parser(%Context{} = ctx, %Parser{ref: ref} = parser) do
    if Context.parser_tracked?(ctx, ref) do
      raise Ergo.Parser.CycleError, context: ctx, parser: parser
    else
      Context.track_parser(ctx, ref)
    end
  end

  @doc ~S"""
  `description/1` returns the description metadata for the parser.

  ## Examples

      iex> parser = Parser.new(identity, %{description: "Not a parser at all"})
      iex> Ergo.Parser.description(parser)
      "Not a parser at all"
  """
  def description(%Parser{description: description}) do
    description
  end

end
