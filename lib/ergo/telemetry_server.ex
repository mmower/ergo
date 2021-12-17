defmodule Ergo.TelemetryServer do
  use GenServer

  @name :ergo_telemetry_server

  defmodule State do
    defstruct events: []
  end

  def init(args) do
    {:ok, args}
  end

  def get_events() do
    GenServer.call(@name, :get_events)
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

  def handle_cast({:log, evt, metadata}, %State{events: events} = state) do
    new_state = %{state | events: events ++ [{evt, metadata}]}
    {:noreply, new_state}
  end

  def handle_cast(:reset, _state) do
    {:noreply, %State{}}
  end

  def handle_call(:get_events, _from, %State{events: events} = state) do
    {:reply, events, state}
  end

end
