defmodule Ergo.Parser do
  alias __MODULE__
  alias Ergo.{Context, ParserRefs, Telemetry}

  require Logger

  defmodule CycleError do
    alias __MODULE__

    defexception [:message]

    def exception(%{
          context: %{dedescription: description, line: line, col: col},
          parser: %{tracks: tracks}
        }) do
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
  defstruct type: nil,
            label: "*unknown*",
            combinator: false,
            children: [],
            parser_fn: nil,
            ref: nil,
            err: nil

  @doc ~S"""
  Create a new combinator parser with the given label, parsing function, and
  optional metadata.
  """
  def combinator(type, label, parser_fn, meta \\ [])
      when is_binary(label) and is_function(parser_fn) do
    %Parser{
      type: type,
      combinator: true,
      label: label,
      parser_fn: parser_fn,
      ref: ParserRefs.next_ref()
    }
    |> Map.merge(Enum.into(meta, %{}))
  end

  @doc ~S"""
  Create a new terminal parser with the given label, parsing function, and
  optional metadata.
  """
  def terminal(type, label, parser_fn, meta \\ [])
      when is_binary(label) and is_function(parser_fn) do
    %Parser{
      type: type,
      combinator: false,
      label: label,
      parser_fn: parser_fn,
      ref: ParserRefs.next_ref()
    }
    |> Map.merge(Enum.into(meta, %{}))
  end

  @doc ~S"""
  `invoke/2` is the main entry point for the parsing process. It looks up the parser control function within
  the `Context` and uses it to run the given `parser`.

  This indirection allows a different control function to be specified, e.g. by the diagnose entry point
  which can wrap the parser call, while still calling the same parsing function (i.e. we are not introducing
  debugging variants of the parsers that could be subject to different behaviours)
  """

  def invoke(%Context{parser: invoking_parser} = ctx, %Parser{parser_fn: parser_fn} = parser) do
    stashed_parser = invoking_parser

    ctx
    |> Context.set_parser(parser)
    |> Telemetry.enter()
    |> Context.reset_status()
    |> track_parser()
    |> push_entry_point()
    |> parser_fn.()
    |> pop_entry_point()
    |> Telemetry.result()
    |> Telemetry.leave()
    |> Context.set_parser(stashed_parser)
  end

  def push_entry_point(%Context{entry_points: entry_points, line: line, col: col} = ctx) do
    %{ctx | entry_points: [{line, col} | entry_points]}
  end

  def pop_entry_point(%Context{entry_points: [_ | entry_points]} = ctx) do
    %{ctx | entry_points: entry_points}
  end

  @doc ~S"""
  `track_parser` first checks if the parser has already been tracked for the current input index and, if it has,
  raises a `CycleError` to indicate the parser is in a loop. Otherwise it adds the parser at the current index.

  ## Examples

    iex> alias Ergo.{Context, Parser}
    iex> import Ergo.{Terminals, Combinators}
    iex> parser = many(char(?H))
    iex> context =
    ...>  Context.new("Hello World")
    ...>  |> Map.put(:parser, parser)
    ...>  |> Parser.track_parser()
    iex> assert Context.parser_tracked?(context, parser.ref)
  """
  def track_parser(%Context{parser: %Parser{ref: ref} = parser} = ctx) do
    if Context.parser_tracked?(ctx, ref) do
      raise Ergo.Parser.CycleError, %{context: ctx, parser: parser}
    else
      Context.track_parser(ctx, ref)
    end
  end
end
