defmodule POC.BP.MixProject do
  use Mix.Project

  def project do
    [
      app: :poc_bp,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :crypto],
      mod: {POC.BP.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:telemetry, "~> 1.0"},
      {:gen_stage, "~> 1.1"},
      {:vega_lite, "~> 0.1"},
      {:jason, "~> 1.3"},
      {:nimble_csv, "~> 1.1"},
      {:statistex, "~> 1.0"},
      {:benchee, "~> 1.1"}
    ]
  end
end
