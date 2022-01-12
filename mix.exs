defmodule Ergo.MixProject do
  use Mix.Project

  @version "0.9.4"

  def project do
    [
      app: :ergo,
      name: "Ergo",
      description: "A pragmatic parser combinator library",
      version: @version,
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Ergo, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:mix_test_watch, "~> 1.0", only: :dev},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:ex_zipper, "~> 0.1.3"},
      {:telemetry, "~> 0.4 or ~> 1.0"},
    ]
  end

  def docs() do
    [
      main: "overview",
      extras: extras(),
      groups_for_extras: groups_for_extras()
    ]
  end

  def extras() do
    [
      "guides/overview.md",
      "guides/parser_combinator_intro.md",
      "guides/comparisons.md",
      "guides/basic_parser.md",
      "guides/debugging.md",
      "guides/recursion.md",
      "guides/guidance.md"
    ]
  end

  def groups_for_extras() do
    [
      Introduction: ~r/guides/
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"Github" => "https://github.com/mmower/ergo"}
    ]
  end
end
