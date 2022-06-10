defmodule Ergo.Parser do
  alias __MODULE__
  alias Ergo.{Context, ParserRefs, Telemetry}
  import Ergo.Utils, only: [printable_string: 1]

  require Logger

  defmodule CycleError do
    alias __MODULE__

    defexception [:message]

    def exception({%{index: curr_index, line: line, col: col, tracks: tracks} = _ctx, %{label: label, ref: cur_ref} = _parser}) do
      message =
        Enum.reduce(
          tracks |> Enum.sort_by(fn {{index, _}, _} -> index end),
          "Ergo has detected a cycle! Aborting parsing of #{printable_string(label)}:(#{cur_ref}) at: L#{line}:#{col}",
          fn {{index, ref}, {line, col, {type, label}}}, msg ->
            msg <> "\nL#{line}:#{col} #{type}/#{printable_string(label)}(#{ref}) #{if ref == cur_ref && index == curr_index, do: "<-- HERE"}"
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
            parser_fn: nil,
            ref: nil,
            err: nil,
            child_info: []

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
  `invoke/2` invokes the parsing function of the given parser on the specified
  `%Context{}` structure. It maintains housekeeping for the parser generally.
  """
  def invoke(%Context{} = ctx, %Parser{parser_fn: parser_fn} = parser) do
    ctx
    |> Context.push_parser(parser)
    |> Telemetry.enter()
    |> Context.reset_status()
    |> track_parser()
    |> push_entry_point()
    |> parser_fn.()
    |> pop_entry_point()
    |> Telemetry.result()
    |> Telemetry.leave()
    |> Context.pop_parser()
  end

  def push_entry_point(%Context{entry_points: entry_points, line: line, col: col} = ctx) do
    %{ctx | entry_points: [{line, col} | entry_points]}
  end

  def pop_entry_point(%Context{entry_points: [_ | entry_points]} = ctx) do
    %{ctx | entry_points: entry_points}
  end

  def child_info_for_telemetry(children) when is_list(children) do
    Enum.map(children, fn %Parser{ref: ref, type: type, label: label} -> {ref, type, label} end)
  end

  def child_info_for_telemetry(%{ref: ref, type: type, label: label}) do
    [{ref, type, label}]
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
  def track_parser(%Context{parser: %Parser{ref: ref, type: type, label: label} = parser} = ctx) do
    if Context.parser_tracked?(ctx, ref) do
      raise Ergo.Parser.CycleError, {ctx, parser}
    else
      Context.track_parser(ctx, ref, {type, label})
    end
  end
end
