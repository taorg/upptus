defmodule Tus.Storage.S3.MixProject do
  use Mix.Project

  @version File.read!("VERSION") |> String.trim()

  def project do
    [
      app: :tus_storage_s3,
      version: @version,
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      description:
        "Amazon S3 (or compatible) storage backend for the Tus server (https://hex.pm/packages/tus)",
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
      links: %{github: "https://github.com/jpscaletti/tus-storage-s3"}
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
      {:tus, "~> 0.1.2"},
      {:ex_aws, "~> 2.0"},
      {:ex_aws_s3, "~> 2.0"},
      {:hackney, "~> 1.9"},
      {:sweet_xml, "~> 0.6"},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end
end
