defmodule PlugProxy.Mixfile do
  use Mix.Project

  def project do
    [app: :plug_proxy,
     version: "0.1.0",
     elixir: "~> 1.2",
     deps: deps()]
  end

  def application do
    [applications: [:logger, :cowboy, :plug, :hackney]]
  end

  defp deps do
    [{:cowboy, "~> 1.0"},
     {:plug, "~> 1.0"},
     {:hackney, "~> 1.6"}]
  end
end
