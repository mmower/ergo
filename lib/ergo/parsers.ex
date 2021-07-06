defmodule Ergo.Parsers do
  import Ergo.{Terminals, Combinators}

  @doc ~S"""
  The `unit` parser matches a series of at least one digit and returns the
  integer value of the digits.

  ## Examples

      iex> alias Ergo.{Context, Parsers}
      ...> context = Context.new("2345")
      ...> parser = Parsers.uint()
      ...> parser.(context)
      %Context{status: :ok, ast: 2345, char: ?5, index: 4, col: 5}
  """
  def uint() do
    fun = fn digit_list ->
      digit_list
      |> Enum.map(fn digit -> digit - ?0 end)
      |> Enum.join("")
      |> String.to_integer()
    end
    many(digit(), min: 1, map: fun )
  end

end
