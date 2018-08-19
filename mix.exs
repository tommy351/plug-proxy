defmodule PlugProxy.Mixfile do
  use Mix.Project

  @version "0.3.2"
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
      lockfile: lockfile(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: preferred_cli_env(),
      source_url: @github_link,
      homepage_url: @github_link,
      docs: [main: "PlugProxy"]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp lockfile do
    case System.get_env("COWBOY_VERSION") do
      "1" <> _ -> "mix-cowboy1.lock"
      _ -> "mix.lock"
    end
  end

  defp deps do
    [
      {:cowboy, "~> 1.0 or ~> 2.4"},
      {:plug, "~> 1.5"},
      {:hackney, "~> 1.10"},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false},
      {:excoveralls, "~> 0.7", only: :test, runtime: false},
      {:inch_ex, "~> 0.5", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["Tommy Chen"],
      licenses: ["MIT License"],
      links: %{"GitHub" => @github_link}
    ]
  end

  defp preferred_cli_env do
    [
      coveralls: :test,
      "coveralls.travis": :test
    ]
  end
end
