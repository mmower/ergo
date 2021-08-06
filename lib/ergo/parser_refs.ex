defmodule Ergo.ParserRefs do
  use Agent

  @name :ergo_parser_refs_agent

  @doc """
  Starts the refs agent. There is no need to call this directly as it will be started as part of the calling
  applications supervision tree via mix.exs
  """
  def start_link(_) do
    Agent.start_link(fn -> 0 end, name: @name)
  end

  @doc """
  Returns the next parser ref id, a monotonically increasing value starting at 0

  ## Examples

      iex> assert is_integer(Ergo.ParserRefs.next_ref())
  """
  def next_ref() do
    Agent.get_and_update(@name, fn state -> {state, state+1} end)
  end

end
