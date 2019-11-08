defmodule Egapp.MixProject do
  use Mix.Project

  def project do
    [
      app: :egapp,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Egapp, []},
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:fast_xml, "~> 1.1"},
      # {:fast_xml, git: "https://github.com/processone/fast_xml.git", tag: "1.1.37"},
    ]
  end
end