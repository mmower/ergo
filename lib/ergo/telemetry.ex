defmodule Ergo.Telemetry do
  alias Ergo.Context

  defdelegate get_events(id), to: Ergo.TelemetryServer

  def start() do
    Supervisor.start_link([{Ergo.TelemetryServer, {}}], strategy: :one_for_one)
  end

  def enter(%Context{
        id: id,
        created_at: created_at,
        parser: %{type: :many, ref: ref, label: label, min: min, max: max, child_info: child_info},
        input: _input,
        index: index,
        line: line,
        col: col,
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
      input: "",
      label: label,
      index: index,
      line: line,
      col: col,
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
        input: _input,
        index: index,
        line: line,
        col: col,
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
      input: "",
      index: index,
      line: line,
      col: col,
      child_info: child_info
    })

    %{ctx | depth: depth + 1}
  end

  def enter(%Context{
        id: id,
        created_at: created_at,
        parser: %{combinator: false, ref: ref, type: type, label: label, child_info: child_info},
        input: _input,
        index: index,
        line: line,
        col: col,
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
      input: "",
      index: index,
      line: line,
      col: col,
      child_info: child_info
    })

    %{ctx | depth: depth + 1}
  end

  def leave(%Context{
        id: id,
        status: status,
        created_at: created_at,
        parser: %{type: type, ref: ref, label: label},
        input: _input,
        index: index,
        line: line,
        col: col,
        ast: ast,
        depth: depth
      } = ctx) do
    :telemetry.execute([:ergo, :leave], %{system_time: System.system_time()}, %{
      id: id,
      status: status,
      event: :leave,
      depth: depth,
      created_at: created_at,
      ref: ref,
      type: type,
      label: label,
      input: "",
      index: index,
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
        input: _input,
        index: index,
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
      input: "",
      index: index,
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
        status: {code, errors} = status,
        input: _input,
        index: index,
        line: line,
        col: col,
        depth: depth,
      } = ctx) when code in [:error, :fatal] do
    :telemetry.execute([:ergo, :error], %{system_time: System.system_time()}, %{
      id: id,
      status: status,
      event: :error,
      depth: depth,
      created_at: created_at,
      ref: ref,
      type: type,
      input: "",
      index: index,
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
    input: _input,
    index: index,
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
      input: "",
      index: index,
      label: label,
      line: line,
      col: col
    })

    ctx
  end
end
