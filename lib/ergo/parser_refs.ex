defmodule Ergo.ParserRefs do
  use Agent

  @name :ergo_parser_refs_agent

  def start_link(_) do
    IO.puts(""); IO.puts("Starting ParserRefs Agent"); IO.puts("")
    Agent.start_link(fn -> 0 end, name: @name)
  end

  @doc ~S"""

  ## Examples

  iex> assert Regex.match?(~r/sequence-\d+/, Ergo.ParserRefs.ref_for(:sequence))
  """
  def ref_for(type) do
    ref = Agent.get_and_update(@name, fn state -> {state, state+1} end)
    "#{type}-#{ref}"
  end

end
