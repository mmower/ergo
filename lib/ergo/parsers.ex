defmodule Ergo.Parsers do
  alias Ergo.{Context, Parser}
  import Ergo.{Terminals, Combinators}

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

      iex> alias Ergo.{Context, Parser}
      iex> import Ergo.Parsers
      iex> context = Context.new("2345")
      iex> parser = uint()
      iex> Parser.call(parser, context)
      %Context{status: :ok, ast: 2345, char: ?5, index: 4, col: 5}
  """
  def uint(opts \\ []) do
    label = Keyword.get(opts, :label, "")
    parser = digits()

    Parser.new(
      fn ctx ->
        with %Context{status: :ok, ast: ast} = new_ctx <- Parser.call(parser, ctx) do
          uint_value = ast |> Enum.join("") |> String.to_integer()
          %{new_ctx | ast: uint_value}
        end
      end,
      %{
        parser: "uint",
        label: label
      }
    )
  end

  @doc ~S"""

  ## Examples

      iex> alias Ergo.{Context, Parser}
      iex> import Ergo.Parsers
      iex> context = Context.new("234.56")
      iex> parser = decimal()
      iex> assert %Context{status: :ok, ast: 234.56} = Parser.call(parser, context)
  """
  def decimal(opts \\ []) do
    label = Keyword.get(opts, :label, "")
    parser = sequence([digits(), ignore(char(?.)), digits()])

    Parser.new(
      fn ctx ->
        with %Context{status: :ok, ast: ast} = new_ctx <- Parser.call(parser, ctx) do
          [i_part | [d_part]] = ast
          i_val = i_part |> Enum.join("")
          d_val = d_part |> Enum.join("")
          %{new_ctx | ast: String.to_float("#{i_val}.#{d_val}")}
        end
      end,
      %{
        parser: "decimal",
        label: label
      }
    )
  end

  @doc ~S"""
  The `digits` parser matches a series of at least one digit and returns an enumeration
  of the digits.

  ## Examples

      iex> alias Ergo.{Context, Parser}
      iex> import Ergo.Parsers
      iex> context = Context.new("2345")
      iex> parser = digits()
      iex> assert %Context{status: :ok, ast: [2, 3, 4, 5]} = Parser.call(parser, context)
  """
  def digits() do
    many(digit(), min: 1, map: fn digits -> Enum.map(digits, fn digit -> digit - ?0 end) end)
  end

end
