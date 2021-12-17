
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
    Ergo.diagnose(parser, "12")

    assert [{[:ergo, :enter], %{type: :sequence, label: "two-digits"}},
            {[:ergo, :enter], %{type: :char_range, label: "digit-1"}},
            {[:ergo, :match], %{type: :char_range, label: "digit-1", ast: ?1}},
            {[:ergo, :leave], %{type: :char_range, label: "digit-1"}},
            {[:ergo, :enter], %{type: :char_range, label: "digit-2"}},
            {[:ergo, :match], %{type: :char_range, label: "digit-2", ast: ?2}},
            {[:ergo, :leave], %{type: :char_range, label: "digit-2"}},
            {[:ergo, :match], %{type: :sequence, label: "two-digits", ast: [49, 50]}},
            {[:ergo, :leave], %{type: :sequence, label: "two-digits", ast: [49, 50]}}] = TelemetryServer.get_events()
  end

  test "correct choice telemetry received" do
    case Supervisor.start_link([Ergo.TelemetryServer], strategy: :one_for_one) do
      {:error, {:shutdown, reason}} -> flunk("Cannot start Telemetry service! #{reason}")
      {:error, {:already_started, _pid} } -> TelemetryServer.reset()
      {:ok, _pid} -> nil
    end

    parser = Combinators.choice([Terminals.alpha(), Terminals.digit()], label: "alpha_or_digit")
    Ergo.diagnose(parser, "1")

    assert [{[:ergo, :enter], %{type: :choice, label: "alpha_or_digit"}},
            {[:ergo, :enter], %{type: :char_list, label: "alpha"}},
            {[:ergo, :enter], %{type: :char_range, label: "?(a..z)"}},
            {[:ergo, :error], %{type: :char_range, label: "?(a..z)"}},
            {[:ergo, :leave], %{type: :char_range, label: "?(a..z)"}},
            {[:ergo, :enter], %{type: :char_range, label: "?(A..Z)"}},
            {[:ergo, :error], %{type: :char_range, label: "?(A..Z)"}},
            {[:ergo, :leave], %{type: :char_range, label: "?(A..Z)"}},
            {[:ergo, :error], %{type: :char_list, label: "alpha"}},
            {[:ergo, :leave], %{type: :char_list, label: "alpha"}},
            {[:ergo, :enter], %{type: :char_range, label: "digit"}},
            {[:ergo, :match], %{type: :char_range, label: "digit", ast: ?1}},
            {[:ergo, :leave], %{type: :char_range, label: "digit", ast: ?1}},
            {[:ergo, :match], %{type: :choice, label: "alpha_or_digit", ast: ?1}},
            {[:ergo, :leave], %{type: :choice, label: "alpha_or_digit", ast: ?1}}] = TelemetryServer.get_events()
  end

end
