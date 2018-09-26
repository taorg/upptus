defmodule Tus.Cache.Redis.MixProject do
  use Mix.Project

  @version File.read!("VERSION") |> String.trim()

  def project do
    [
      app: :tus_cache_redis,
      version: @version,
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      description: "Redis cache backend for the Tus server (https://hex.pm/packages/tus)",
      deps: deps(),
      package: package(),
      dialyzer: [ignore_warnings: "dialyzer.ignore-warnings"]
    ]
  end

  def package() do
    [
      files: ~w(lib mix.exs README.md LICENSE VERSION),
      licenses: ["BSD 3-Clause License"],
      maintainers: ["Juan-Pablo Scaletti", "juanpablo@jpscaletti.com"],
      links: %{github: "https://github.com/jpscaletti/tus-cache-redis"}
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
      {:tus, ">= 0.1.0"},
      {:redix, ">= 0.0.0"},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end
end
