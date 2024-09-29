defmodule Ergo do
  @moduledoc "README.md"
             |> File.read!()
             |> String.split("<!-- MDOC !-->")
             |> Enum.fetch!(1)

  alias Ergo.Context
  alias Ergo.Parser

  @doc ~S"""
  The `parser/2` function is a simple entry point to parsing inputs that constructs the Context record required.

  Options
    debug: [true | false]

  # Examples

      iex> alias Ergo.Terminals
      iex> parser = Terminals.literal("Hello")
      iex> assert %Ergo.Context{status: :ok, ast: "Hello", input: " World", index: 5, line: 1, col: 6} = Ergo.parse(parser, "Hello World")
  """
  def parse(%Parser{} = parser, input, opts \\ []) when is_binary(input) do
    input
    |> Context.new(opts)
    |> Parser.invoke(parser)
  end
end
