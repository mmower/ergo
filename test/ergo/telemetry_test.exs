
defmodule Ergo.TelemetryTest do
  use ExUnit.Case
  doctest Ergo.Telemetry
  alias Ergo.{Terminals, Combinators, TelemetryServer}

  test "correct sequence telemetry received" do
    case Supervisor.start_link([Ergo.TelemetryServer], strategy: :one_for_one) do
      {:error, {:shutdown, reason}} -> flunk("Cannot start Telemetry service! #{reason}")
      {:error, {:already_started, _pid} } -> TelemetryServer.reset()
      {:ok, _pid} -> nil
    end

    parser = Combinators.sequence([Terminals.digit(label: "digit-1"), Terminals.digit(label: "digit-2")], label: "two-digits")
    %{status: :ok, id: id} = Ergo.parse(parser, "12")

    assert [%{event: :enter, type: :sequence, label: "two-digits"},
            %{event: :enter, type: :char_range, label: "digit-1"},
            %{event: :match, type: :char_range, label: "digit-1", ast: ?1},
            %{event: :leave, type: :char_range, label: "digit-1"},
            %{event: :enter, type: :char_range, label: "digit-2"},
            %{event: :match, type: :char_range, label: "digit-2", ast: ?2},
            %{event: :leave, type: :char_range, label: "digit-2"},
            %{event: :match, type: :sequence, label: "two-digits", ast: [49, 50]},
            %{event: :leave, type: :sequence, label: "two-digits", ast: [49, 50]}] = TelemetryServer.get_events(id)
  end

  test "correct choice telemetry received" do
    case Supervisor.start_link([Ergo.TelemetryServer], strategy: :one_for_one) do
      {:error, {:shutdown, reason}} -> flunk("Cannot start Telemetry service! #{reason}")
      {:error, {:already_started, _pid} } -> TelemetryServer.reset()
      {:ok, _pid} -> nil
    end

    parser = Combinators.choice([Terminals.alpha(), Terminals.digit()], label: "alpha_or_digit")
    %{status: :ok, id: id} = Ergo.parse(parser, "1")

    assert [%{event: :enter, type: :choice, label: "alpha_or_digit"},
            %{event: :enter, type: :char_list, label: "alpha"},
            %{event: :enter, type: :char_range, label: "?(a..z)"},
            %{event: :error, type: :char_range, label: "?(a..z)"},
            %{event: :leave, type: :char_range, label: "?(a..z)"},
            %{event: :enter, type: :char_range, label: "?(A..Z)"},
            %{event: :error, type: :char_range, label: "?(A..Z)"},
            %{event: :leave, type: :char_range, label: "?(A..Z)"},
            %{event: :error, type: :char_list, label: "alpha"},
            %{event: :leave, type: :char_list, label: "alpha"},
            %{event: :enter, type: :char_range, label: "digit"},
            %{event: :match, type: :char_range, label: "digit", ast: ?1},
            %{event: :leave, type: :char_range, label: "digit", ast: ?1},
            %{event: :match, type: :choice, label: "alpha_or_digit", ast: ?1},
            %{event: :leave, type: :choice, label: "alpha_or_digit", ast: ?1}] = TelemetryServer.get_events(id)
  end

end
