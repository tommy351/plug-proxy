defmodule PlugProxy.Mixfile do
  use Mix.Project

  @version "0.3.1"
  @github_link "https://github.com/tommy351/plug-proxy"

  def project do
    [
      app: :plug_proxy,
      version: @version,
      elixir: "~> 1.6",
      description: "A plug for reverse proxy server",
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      package: package(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: preferred_cli_env(),
      docs: [main: "PlugProxy", source_ref: @version, source_url: @github_link]
    ]
  end

  def application do
    [applications: [:logger, :cowboy, :plug, :hackney]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:cowboy, "~> 1.0"},
      {:plug, "~> 1.5.0"},
      {:hackney, "~> 1.10"},
      {:ex_doc, "~> 0.18", only: :dev, runtime: false},
      {:excoveralls, "~> 0.7", only: :test},
      {:inch_ex, "~> 0.5", only: [:dev, :test]}
    ]
  end

  defp package do
    [maintainers: ["Tommy Chen"], licenses: ["MIT License"], links: %{"GitHub" => @github_link}]
  end

  defp preferred_cli_env do
    [
      coveralls: :test,
      "coveralls.travis": :test
    ]
  end
end
