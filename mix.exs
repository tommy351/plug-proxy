defmodule PlugProxy.Mixfile do
  use Mix.Project

  def project do
    [app: :plug_proxy,
     version: "0.1.0",
     elixir: "~> 1.2",
     elixirc_paths: elixirc_paths(Mix.env),
     deps: deps()]
  end

  def application do
    [applications: [:logger, :cowboy, :plug, :hackney]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  defp deps do
    [{:cowboy, "~> 1.0"},
     {:plug, "~> 1.0"},
     {:hackney, "~> 1.6"}]
  end
end
