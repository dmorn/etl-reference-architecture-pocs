defmodule POC.SUP.MixProject do
  use Mix.Project

  def project do
    [
      app: :poc_sup,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {POC.SUP.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:telemetry, "~> 1.0"},
      {:gen_stage, "~> 1.1"},
      {:jason, "~> 1.3"},
      {:statistex, "~> 1.0"},
      {:benchee, "~> 1.1"}
    ]
  end
end
