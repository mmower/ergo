defmodule Ergo.MixProject do
  use Mix.Project

  def project do
    [
      app: :ergo,
      description: "A simple, macro free, parser combinator library",
      version: "0.1.4",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:mix_test_watch, "~> 1.0", only: :dev},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"Github" => "https://github.com/mmower/ergo"}
    ]
  end
end
