defmodule Ergo.Telemetry do
  alias Ergo.{Context, Parser}
  import Ergo.Utils

  def child_list(%Parser{children: children}) do
    Enum.map(children, fn child -> {child.ref, child.type, child.label} end)
  end

  def enter(%Context{
        id: id,
        created_at: created_at,
        parser: %{type: :many, ref: ref, label: label, min: min, max: max} = parser,
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
      input: ellipsize(input),
      min: min,
      max: max,
      children: child_list(parser)
    })

    %{ctx | depth: depth + 1}
  end

  def enter(%Context{
        id: id,
        created_at: created_at,
        parser: %{combinator: true, ref: ref, type: type, label: label} = parser,
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
      input: ellipsize(input),
      children: child_list(parser)
    })

    %{ctx | depth: depth + 1}
  end

  def enter(%Context{
        id: id,
        created_at: created_at,
        parser: %{combinator: false, ref: ref, type: type, label: label},
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
      input: ellipsize(input)
    })

    %{ctx | depth: depth + 1}
  end

  def leave(%Context{
        id: id,
        created_at: created_at,
        parser: %{type: type, ref: ref, label: label},
        line: line,
        col: col,
        input: input,
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
      input: ellipsize(input),
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
        depth: depth
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

  def error(%Context{status: :ok} = ctx) do
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
    metadata =
      %{
        id: id,
        event: :event,
        user_event: event,
        depth: depth,
        created_at: created_at,
        ref: ref,
        type: type,
        label: label,
        line: line,
        col: col
      } |> Map.merge(details)

    :telemetry.execute([:ergo, :event], %{system_time: System.system_time()}, metadata)

    ctx
  end
end
