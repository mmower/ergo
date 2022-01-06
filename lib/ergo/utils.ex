defmodule Ergo.Utils do
  @doc """
  ## Examples

      iex> Ergo.Utils.char_to_string(?H)
      "H"

      iex> Ergo.Utils.char_to_string(?h)
      "h"

      iex> Ergo.Utils.char_to_string(?\\r)
      "\\r"

      iex> Ergo.Utils.char_to_string(?\\n)
      "\\n"

      iex> Ergo.Utils.char_to_string(?\\t)
      "\\t"
  """
  def char_to_string(c) when is_integer(c) do
    List.to_string([c])
  end

  @doc ~S"""
  If the string `str` is longer than `max` (default: 40) it is truncated to 37 chars and "..." is added to the end, otherwise it is returned unaltered.

  ## Examples

      iex> Ergo.Utils.ellipsize("frob")
      "frob"

      iex> Ergo.Utils.ellipsize("123456789012345678901234567890123456789012345678901")
      "1234567890123456789012345678901234567..."

      iex> Ergo.Utils.ellipsize("12345678901234567890", 10)
      "1234567..."

      iex> Ergo.Utils.ellipsize("12345", 4)
      "1..."
  """
  def ellipsize(str, max \\ 40) when is_binary(str) and max > 3 do
    if String.length(str) > max do
      String.slice(str, 0..(max-4)) <> "..."
    else
      str
    end
  end

  # From https://elixirforum.com/t/just-created-a-typeof-module/2583/5
  types =
    ~w[boolean binary bitstring float function integer list map nil pid port reference tuple atom]

  for type <- types do
    def typeof(x) when unquote(:"is_#{type}")(x), do: unquote(type)
  end

  def typeof(_) do "unknown" end

end
