defmodule Ergo.Utils do
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

  def printable_string(s) when is_binary(s) do
    for <<c <- s>>, c in 32..127, into: "", do: <<c>>
  end

  def format_tracks(tracks) do
    Enum.reduce(
      tracks |> Enum.sort_by(fn {{index, _}, _} -> index end),
      "",
      fn {{_index, ref}, {line, col, {type, label}}}, msg ->
        msg <> "\nL#{line}:#{col} #{type}/#{printable_string(label)}(#{ref})"
      end
    )
  end

  # From https://elixirforum.com/t/just-created-a-typeof-module/2583/5
  types =
    ~w[boolean binary bitstring float function integer list map nil pid port reference tuple atom]

  for type <- types do
    def typeof(x) when unquote(:"is_#{type}")(x), do: unquote(type)
  end

  def typeof(_) do "unknown" end

end
