defmodule Ergo.TelemetryServer do
  use GenServer

  @name :ergo_telemetry_server

  defmodule State do
    defstruct runs: %{}
  end

  def init(args) do
    {:ok, args}
  end

  def get_events(id) do
    GenServer.call(@name, {:get_events, id})
  end

  def reset() do
    GenServer.call(@name, :reset)
  end

  def start_link(_) do
    events = [
      [:ergo, :enter],
      [:ergo, :leave],
      [:ergo, :match],
      [:ergo, :error],
      [:ergo, :event]
    ]

    :telemetry.attach_many(
      to_string(@name),
      events,
      &Ergo.TelemetryServer.handle_event/4,
      nil
    )

    GenServer.start(__MODULE__, %State{}, name: @name)
  end

  def handle_event(evt, _measurements, metadata, _config) do
    GenServer.cast(@name, {:log, evt, metadata})
  end

  def handle_cast({:log, _evt, %{id: id} = metadata}, %State{runs: runs} = state) do
    events =
      Map.get(runs, id, [])
      |> List.insert_at(0, metadata)

    {:noreply, %{state | runs: Map.put(runs, id, events)}}
  end

  def handle_cast(:reset, _state) do
    {:noreply, %State{}}
  end

  def handle_call({:get_events, id}, _from, %State{runs: runs} = state) do
    events =
      Map.get(runs, id, [])
      |> Enum.reverse()

    {:reply, events, state}
  end

end
