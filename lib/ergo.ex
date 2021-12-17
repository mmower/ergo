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
    # Telemetry is disabled by default. Start the Ergo.Telemetry application
    # to generate telemetry metadata
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
  def parse(%Parser{} = parser, input, opts \\ []) when is_binary(input) do
    data = Keyword.get(opts, :data, %{})
    ctx = Context.new(&Parser.call/1, input, data: data)
    Parser.invoke(parser, ctx)
  end

  def diagnose(%Parser{} = parser, input, opts \\ []) when is_binary(input) do
    data = Keyword.get(opts, :data, %{})
    ctx = Context.new(&Parser.diagnose/1, input, data: data)
    Parser.invoke(parser, ctx)
  end
end
