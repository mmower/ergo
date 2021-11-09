defmodule Ergo.Parser do
  alias __MODULE__
  alias Ergo.{Context, ParserRefs, Utils}

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
  defstruct label: "*unknown*",
            combinator: false,
            parser_fn: nil,
            ref: nil,
            debug: false,
            err: nil

  @doc ~S"""
  Create a new combinator parser with the given label, parsing function, and
  optional metadata.
  """
  def combinator(label, parser_fn, meta \\ []) when is_binary(label) and is_function(parser_fn) do
    %Parser{combinator: true, label: label, parser_fn: parser_fn, ref: ParserRefs.next_ref()}
    |> Map.merge(Enum.into(meta, %{}))
  end

  @doc ~S"""
  Create a new terminal parser with the given label, parsing function, and
  optional metadata.
  """
  def terminal(label, parser_fn, meta \\ []) when is_binary(label) and is_function(parser_fn) do
    %Parser{combinator: false, label: label, parser_fn: parser_fn, ref: ParserRefs.next_ref()}
    |> Map.merge(Enum.into(meta, %{}))
  end

  # @doc ~S"""
  # `new/2` creates a new `Parser` from the given parsing function and with the specified metadata.
  # """
  # def new(label, parser_fn, meta \\ []) when is_binary(label) and is_function(parser_fn) do
  #   %Parser{label: label, parser_fn: parser_fn, ref: ParserRefs.next_ref()}
  #   |> Map.merge(Enum.into(meta, %{}))
  # end

  @doc ~S"""
  `invoke/2` is the main entry point for the parsing process. It looks up the parser control function within
  the `Context` and uses it to run the given `parser`.

  This indirection allows a different control function to be specified, e.g. by the diagnose entry point
  which can wrap the parser call, while still calling the same parsing function (i.e. we are not introducing
  debugging variants of the parsers that could be subject to different behaviours)
  """

  def invoke(%Parser{} = parser, %Context{invoke_fn: invoke_fn, called_from: called_from, parser: caller} = ctx) do
    if ctx.caller_logging do
      invoke_fn.(%{ctx | parser: parser, called_from: [caller | called_from]}, parser)
    else
      invoke_fn.(%{ctx | parser: parser}, parser)
    end
  end

  @doc """
  The rewrite_error/2 call allows a higher-level parser to rewrite the error returned by a subordinate
  parser, translating it into something a user is more likely to be able to understand.
  """

  def rewrite_error(%Context{status: {:error, _} = status} = ctx, %Parser{err: err}) when is_function(err) do
    IO.puts("\nREWRITE ERROR\n")
    try do
      %{ctx | status: err.(status)}
    rescue
      _e in FunctionClauseError -> ctx
    end
  end

  def rewrite_error(ctx, _parser) do
    ctx
  end

  @doc ~S"""
  `call/2` invokes the specified parser by calling its parsing function with the specified context having
  first reset the context status.
  """
  def call(%Context{} = ctx, %Parser{parser_fn: parser_fn} = parser) do
    ctx
    |> Context.reset_status()
    |> track_parser(parser)
    |> parser_fn.()
    |> rewrite_error(parser)
  end

  def trace_in(%Context{depth: depth, line: line, col: col} = ctx, label, debug) do
    Context.trace(ctx, debug, "#{depth}> #{label} @ #{line}:#{col} on: #{Context.clip(ctx)}")
  end

  def trace_out(%Context{depth: depth, status: status, ast: ast, message: message} = ctx, label, debug) do
    Context.trace(ctx, debug, "#{depth}> #{label} status: #{inspect(status)} message: #{message} ast: #{inspect(ast)}")
  end

  def process(%Context{process: process} = ctx, parser) do
    %{ctx | process: [process_entry(parser, ctx) | process]}
  end

  @doc ~S"""
  `diagnose/2` invokes the specified parser by calling its parsing function with the specific context while
  tracking the progress of the parser. The progress can be retrieved from the `progress` key of the returned
  context.

  ## Examples

      iex> alias Ergo.{Context, Parser}
      iex> import Ergo.{Combinators, Terminals}
      iex> context = Context.new(&Ergo.Parser.diagnose/2, "Hello World")
      iex> parser = many(wc())
      iex> assert %{status: :ok} = Parser.invoke(parser, context)
  """
  def diagnose(%Context{} = ctx, %Parser{label: label} = parser) do
    debug = should_debug?(parser, ctx)

    ctx
    |> Context.inc_depth()
    |> trace_in(label, debug)
    |> Parser.call(parser)
    |> trace_out(label, debug)
    |> Context.dec_depth()
    |> process(parser)
  end

  defp process_entry(%Parser{label: label, ref: ref}, %Context{status: status, line: line, col: col, input: input}) do
    {{line, col}, Utils.ellipsize(input, 20), ref, label, status}
  end

  defp should_debug?(%Parser{combinator: true}, %Context{}) do
    true
  end

  defp should_debug?(%Parser{combinator: false}, %Context{called_from: [caller | _]}) do
    !is_nil(caller) && caller.debug
  end

  @doc ~S"""
  `track_parser` first checks if the parser has already been tracked for the current input index and, if it has,
  raises a `CycleError` to indicate the parser is in a loop. Otherwise it adds the parser at the current index.

  ## Examples

    iex> alias Ergo.{Context, Parser}
    iex> import Ergo.{Terminals, Combinators}
    iex> context = Context.new(&Ergo.Parser.call/2, "Hello World")
    iex> parser = many(char(?H))
    iex> context2 = Parser.track_parser(context, parser)
    iex> assert Context.parser_tracked?(context2, parser.ref)
  """
  def track_parser(
        %Context{} = ctx,
        %Parser{ref: ref} = parser
      ) do
    if Context.parser_tracked?(ctx, ref) do
      raise Ergo.Parser.CycleError, %{context: ctx, parser: parser}
    else
      Context.track_parser(ctx, ref)
    end
  end

end
