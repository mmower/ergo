defmodule Ergo.Parsers do
  alias Ergo.Context
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

      iex> alias Ergo.Context
      iex> import Ergo.Parsers
      iex> context = Context.new("2345")
      iex> parser = uint()
      iex> parser.(context)
      %Context{status: :ok, ast: 2345, char: ?5, index: 4, col: 5}
  """
  def uint() do
    parser = digits()

    fn ctx ->
      with %Context{status: :ok, ast: ast} = new_ctx <- parser.(ctx) do
        uint_value = ast |> Enum.join("") |> String.to_integer()
        %{new_ctx | ast: uint_value}
      end
    end
  end

  @doc ~S"""

  ## Examples

      iex> alias Ergo.Context
      iex> import Ergo.Parsers
      iex> context = Context.new("234.56")
      iex> parser = decimal()
      iex> assert %Context{status: :ok, ast: 234.56} = parser.(context)
  """
  def decimal() do
    parser = sequence([digits(), ignore(char(?.)), digits()])

    fn ctx ->
      with %Context{status: :ok, ast: ast} = new_ctx <- parser.(ctx) do
        [i_part | [d_part]] = ast
        i_val = i_part |> Enum.join("")
        d_val = d_part |> Enum.join("")
        %{new_ctx | ast: String.to_float("#{i_val}.#{d_val}")}
      end
    end
  end

  @doc ~S"""
  The `digits` parser matches a series of at least one digit and returns an enumeration
  of the digits.

  ## Examples

      iex> alias Ergo.{Context, Parsers}
      iex> context = Context.new("2345")
      iex> parser = Parsers.digits()
      iex> assert %Context{status: :ok, ast: [2, 3, 4, 5]} = parser.(context)
  """
  def digits() do
    many(digit(), min: 1, map: fn digits -> Enum.map(digits, fn digit -> digit - ?0 end) end)
  end

end
