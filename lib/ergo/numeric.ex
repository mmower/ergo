defmodule Ergo.Numeric do
  alias Ergo.{Context, Parser}
  import Ergo.{Terminals, Combinators, Utils}
  require Logger

  @moduledoc """
  The Parsers module exists to house utility parsers that while they are terminals in the sense that they are not parameterised, they internally make use of parsers from the Combinators module.

  # Parsers

  * `uint`
  * `decimal`
  * `digits`

  """

  @doc ~S"""
  The `unit` parser matches a series of at least one digit and returns the
  integer value of the digits.

  ## Examples

      iex> alias Ergo.Context
      iex> import Ergo.Numeric
      iex> context = Ergo.parse(uint(), "2345")
      iex> assert %Context{status: :ok, ast: 2345, char: ?5, index: 4, col: 5} = context
  """
  def uint(opts \\ []) do
    label = Keyword.get(opts, :label, "#")
    parser = digits()

    Parser.new(
      :uint,
      fn %Context{input: input, debug: debug} = ctx ->
        if debug, do: Logger.info("Trying UInt<#{label}> on #{ellipsize(input, 20)}")

        with %Context{status: :ok, ast: ast} = new_ctx <- Parser.invoke(parser, ctx) do
          uint_value = ast |> Enum.join("") |> String.to_integer()
          %{new_ctx | ast: uint_value}
        end
      end,
      combinator: true,
      label: label
    )
  end

  @doc ~S"""

  ## Examples

      iex> alias Ergo.Context
      iex> import Ergo.Numeric
      iex> context = Ergo.parse(decimal(), "234.56")
      iex> assert %Context{status: :ok, ast: 234.56} = context
  """
  def decimal(opts \\ []) do
    label = Keyword.get(opts, :label, "#")
    parser = sequence([digits(), ignore(char(?.)), digits()], label: "ddd.dd")

    Parser.new(
      :decimal,
      fn %Context{input: input, debug: debug} = ctx ->
        if debug, do: Logger.info("Trying Decimal<#{label}> on [#{ellipsize(input, 20)}]")

        with %Context{status: :ok, ast: ast} = new_ctx <- Parser.invoke(parser, ctx) do
          [i_part | [d_part]] = ast
          i_val = i_part |> Enum.join("")
          d_val = d_part |> Enum.join("")
          %{new_ctx | ast: String.to_float("#{i_val}.#{d_val}")}
        end
      end,
      combinator: true,
      label: label
    )
  end

  @doc ~S"""
  The `digits` parser matches a series of at least one digit and returns an enumeration
  of the digits.

  ## Examples

      iex> alias Ergo.Context
      iex> import Ergo.Numeric
      iex> context = Ergo.parse(digits(), "2345")
      iex> assert %Context{status: :ok, ast: [2, 3, 4, 5]} = context
  """
  def digits(opts \\ []) do
    label = Keyword.get(opts, :label, "#")

    many(digit(),
      label: label,
      min: 1,
      map: fn digits -> Enum.map(digits, fn digit -> digit - ?0 end) end
    )
  end

  @doc ~S"""
  The `number` parser matches both integer and decimal string and converts them into their
  appropriate Elixir integer or float values.

  ## Examples

      iex> import Ergo.Numeric
      iex> assert %{status: :ok, ast: 42} = Ergo.parse(number(), "42")

      iex> import Ergo.Numeric
      iex> assert %{status: :ok, ast: -42} = Ergo.parse(number(), "-42")

      iex> import Ergo.Numeric
      iex> assert %{status: :ok, ast: 42.0} = Ergo.parse(number(), "42.0")

      iex> import Ergo.Numeric
      iex> assert %{status: :ok, ast: -42.0} = Ergo.parse(number(), "-42.0")

      iex> import Ergo.Numeric
      iex> assert %{status: :ok, ast: 0} = Ergo.parse(number(), "0")

      iex> import Ergo.Numeric
      iex> assert %{status: :ok, ast: 0} = Ergo.parse(number(), "0000")

      iex> import Ergo.Numeric
      iex> assert %{status: {:error, _}} = Ergo.parse(number(), "Fourty Two")

      iex> import Ergo.Numeric
      iex> assert %{status: :ok, ast: 42} = Ergo.parse(number(), "42Fourty Two")
  """
  def number(opts \\ []) do
    label = Keyword.get(opts, :label, "#")

    sequence(
      [
        optional(char(?-), map: fn _ -> -1 end, label: "-?"),
        choice(
          [
            decimal(),
            uint()
          ],
          label: "[i|d]"
        )
      ],
      type: :number,
      label: label,
      map: &Enum.product/1
    )
  end
end
