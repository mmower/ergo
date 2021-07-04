defmodule Ergo.Utils do

  @doc """
  ## Examples

      iex> Ergo.Utils.char_to_string(?H)
      "H"

      iex> Ergo.Utils.char_to_string(?h)
      "h"
  """
  def char_to_string(c) when is_integer(c) do
    List.to_string([c])
  end

end
