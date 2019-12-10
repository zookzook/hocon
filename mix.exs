defmodule Hocon.MixProject do
  use Mix.Project

  @version "0.1.3"

  def project do
    [
      app: :hocon,
      version: @version,
      name: "hocon",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [docs: :docs, coveralls: :test, "coveralls.detail": :test, "coveralls.post": :test, "coveralls.html": :test],
      description: description(),
      package: package(),
      docs: docs()
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
      {:excoveralls, "~> 0.12.1", only: :test},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false}
    ]
  end

  defp description() do
    """
    Parse HOCON configuration files in Elixir following the HOCON specifications.
    """
  end

  defp package() do
    [maintainers: ["Michael Maier"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/zookzook/hocon"}]
  end

  defp docs() do
    [main: "readme",
      name: "HOCON",
      extras: ["README.md"],
      source_ref: "v#{@version}",
      canonical: "http://hexdocs.pm/hocon",
      source_url: "https://github.com/zookzook/hocon"]
  end

end
