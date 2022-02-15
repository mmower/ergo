defmodule Ergo.Telemetry do
  alias Ergo.Context

  @input_length 80

  defdelegate get_events(id), to: Ergo.TelemetryServer

  def start() do
    Supervisor.start_link([{Ergo.TelemetryServer, {}}], strategy: :one_for_one)
    IO.puts("Start returned")
  end

  def enter(%Context{
        id: id,
        created_at: created_at,
        parser: %{type: :many, ref: ref, label: label, min: min, max: max, child_info: child_info},
        line: line,
        col: col,
        input: input,
        depth: depth
      } = ctx) do
    :telemetry.execute([:ergo, :enter], %{system_time: System.system_time()}, %{
      id: id,
      event: :enter,
      depth: depth,
      type: :many,
      created_at: created_at,
      ref: ref,
      combinator: true,
      label: label,
      line: line,
      col: col,
      input: String.slice(input, 0..@input_length),
      min: min,
      max: max,
      child_info: child_info
    })

    %{ctx | depth: depth + 1}
  end

  def enter(%Context{
        id: id,
        created_at: created_at,
        parser: %{combinator: true, ref: ref, type: type, label: label, child_info: child_info},
        line: line,
        col: col,
        input: input,
        depth: depth
      } = ctx) do
    :telemetry.execute([:ergo, :enter], %{system_time: System.system_time()}, %{
      id: id,
      event: :enter,
      depth: depth,
      created_at: created_at,
      ref: ref,
      type: type,
      combinator: true,
      label: label,
      line: line,
      col: col,
      input: String.slice(input, 0..@input_length),
      child_info: child_info
    })

    %{ctx | depth: depth + 1}
  end

  def enter(%Context{
        id: id,
        created_at: created_at,
        parser: %{combinator: false, ref: ref, type: type, label: label, child_info: child_info},
        line: line,
        col: col,
        input: input,
        depth: depth
      } = ctx) do
    :telemetry.execute([:ergo, :enter], %{system_time: System.system_time()}, %{
      id: id,
      event: :enter,
      depth: depth,
      created_at: created_at,
      ref: ref,
      type: type,
      combinator: false,
      label: label,
      line: line,
      col: col,
      input: String.slice(input, 0..@input_length),
      child_info: child_info
    })

    %{ctx | depth: depth + 1}
  end

  def leave(%Context{
        id: id,
        created_at: created_at,
        parser: %{type: type, ref: ref, label: label},
        line: line,
        col: col,
        ast: ast,
        depth: depth
      } = ctx) do
    :telemetry.execute([:ergo, :leave], %{system_time: System.system_time()}, %{
      id: id,
      event: :leave,
      depth: depth,
      created_at: created_at,
      ref: ref,
      type: type,
      label: label,
      line: line,
      col: col,
      ast: ast
    })

    %{ctx | depth: depth - 1}
  end

  def result(%Context{
        status: :ok,
        id: id,
        created_at: created_at,
        parser: %{type: type, ref: ref, label: label},
        line: line,
        col: col,
        ast: ast,
        depth: depth
      } = ctx) do
    :telemetry.execute([:ergo, :match], %{system_time: System.system_time()}, %{
      id: id,
      event: :match,
      depth: depth,
      created_at: created_at,
      ref: ref,
      type: type,
      label: label,
      line: line,
      col: col,
      ast: ast
    })

    ctx
  end

  def result(%Context{
        id: id,
        created_at: created_at,
        parser: %{type: type, ref: ref, label: label},
        status: {:error, errors},
        line: line,
        col: col,
        depth: depth,
      } = ctx) do
    :telemetry.execute([:ergo, :error], %{system_time: System.system_time()}, %{
      id: id,
      event: :error,
      depth: depth,
      created_at: created_at,
      ref: ref,
      type: type,
      label: label,
      line: line,
      col: col,
      errors: errors
    })

    ctx
  end

  def event(%Context{
    id: id,
    created_at: created_at,
    parser: %{type: type, ref: ref, label: label},
    line: line,
    col: col,
    depth: depth
  } = ctx, event, details \\ %{}) do
    :telemetry.execute([:ergo, :event], %{system_time: System.system_time()}, %{
      id: id,
      event: :event,
      user_event: event,
      details: details,
      depth: depth,
      created_at: created_at,
      ref: ref,
      type: type,
      label: label,
      line: line,
      col: col
    })

    ctx
  end
end
