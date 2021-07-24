defmodule Ergo do
  @moduledoc "README.md"
             |> File.read!()
             |> String.split("<!-- MDOC !-->")
             |> Enum.fetch!(1)

  alias Ergo.{Context, Parser}

  @doc ~S"""
  The `parser/2` function is a simple entry point to parsing inputs that constructs the Context record required.

  Options
    debug: [true | false]

  # Examples

      iex> alias Ergo.Terminals
      iex> parser = Terminals.literal("Hello")
      iex> Ergo.parse(parser, "Hello World")
      %Ergo.Context{status: :ok, ast: "Hello", char: ?o, input: " World", index: 5, line: 1, col: 6}
  """
  def parse(%Parser{} = parser, input, opts \\ []) when is_binary(input) do
    debug = Keyword.get(opts, :debug, false)
    Parser.call(parser, Context.new(input, debug))
  end
end
