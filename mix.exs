defmodule Hl7Poc.MixProject do
  use Mix.Project

  def project do
    [
      app: :hl7_poc,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Hl7Poc, []}
    ]
  end

  defp deps do
    [
      {:postgrex, "~> 0.17"},
      {:jason, "~> 1.4"}
    ]
  end
end
