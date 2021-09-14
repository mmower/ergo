defmodule Ergo do
  @moduledoc "README.md"
             |> File.read!()
             |> String.split("<!-- MDOC !-->")
             |> Enum.fetch!(1)

  alias Ergo.{Context, Parser}

  use Application

  @doc ~S"""
  `start/2` should be called before

  """
  def start(_type, _args) do
    Supervisor.start_link([Ergo.ParserRefs], strategy: :one_for_one)
  end

  @doc ~S"""
  The `parser/2` function is a simple entry point to parsing inputs that constructs the Context record required.

  Options
    debug: [true | false]

  # Examples

      iex> alias Ergo.Terminals
      iex> parser = Terminals.literal("Hello")
      iex> assert %Ergo.Context{status: :ok, ast: "Hello", input: " World", index: 5, line: 1, col: 6} = Ergo.parse(parser, "Hello World")
  """
  def parse(%Parser{} = parser, input) when is_binary(input) do
    Parser.invoke(parser, Context.new(&Parser.call/2, input))
    # Parser.call(parser, Context.new(input, parser: &))
  end

  def diagnose(%Parser{} = parser, input) when is_binary(input) do
    Parser.invoke(parser, Context.new(&Parser.diagnose/2, input))
    # Parser.call(parser, Context.new(input, diagnose: true))

    # Put a reference to the parsing function into the context
    # &Parser.diagnose/2
    # &Parser.call/2
  end
end
