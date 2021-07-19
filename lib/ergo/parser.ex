defmodule Ergo.Parser do
  alias __MODULE__
  alias Ergo.Context

  @moduledoc """
  `Ergo.Parser` contains the Parser record type. Ergo parsers are anonymous functions but we embed
  them in a `Parser` record that can hold arbitrary metadata. The primary use for the metadata is
  the storage of debugging information.
  """
  defstruct [
    parser_fn: nil,
    description: "#"
  ]

  @doc ~S"""
  `new/2` creates a new `Parser` from the given parsing function and with the specified metadata.
  """
  def new(parser_fn, meta \\ []) when is_function(parser_fn) do
    %Parser{parser_fn: parser_fn}
    |> Map.merge(Enum.into(meta, %{}))
  end

  @doc ~S"""
  `call/2` invokes the specified parser by calling its parsing function with the specified context having
  first reset the context status.
  """
  def call(%Parser{parser_fn: p}, %Context{} = ctx) do
    p.(Context.reset_status(ctx))
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
