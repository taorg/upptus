defmodule Tus.Cache.Redis do
  @moduledoc """
  Redis cache backend for the [Tus server](https://hex.pm/packages/tus)

  Uses the [Redix](https://hex.pm/packages/redix) package for interfacing with Redis.

  ## Installation

  The package can be installed by adding `tus_cache_redis` to your list of dependencies in `mix.exs`:

  ```elixir
  def deps do
    [
      {:tus, "~> 0.1.0"},
      {:tus_cache_redis, "~> 0.1.0"},
    ]
  end
  ```

  ## Configuration

  - `cache`: Set it as `Tus.Cache.Redis`.
  - `redis_host`: Optional. "localhost" by default
  - `redis_port`: Optional. 6379 by default.

  """
  @doc """
  Start the Redix GenServer.

  Params:
  - `:redis_host`: "localhost"
  - `:redis_port`: 6379
  - `:cache_name`: The name of the server
  """
  def start_link(%{cache_name: cache_name} = config) do
    Redix.start_link(
      [
        host: Map.get(config, :redis_host, "localhost"),
        port: Map.get(config, :redis_port, 6379)
      ],
      name: cache_name
    )
  end

  @doc """
  Read a value from Redis. Returns `nil` is none is found.
  """
  def get(name, key) do
    case Redix.command(name, ["GET", key]) do
      {:ok, nil} -> nil
      {:ok, value} -> decode(value)
      _ -> nil
    end
  end

  @doc """
  Puts a value to Redis. Overwrites any value with the same key.
  """
  def put(name, key, file) do
    {:ok, _} = Redix.command(name, ["SET", key, encode(file)])
  end

  @doc """
  Delete a value from Redis. Doesn't fail if the key doesn't exist, so it can be
  called multiple times.
  """
  def delete(name, key) do
    _ = Redix.command(name, ["DEL", key])
  end

  defp encode(file) do
    :erlang.term_to_binary(file)
  end

  defp decode(value) do
    :erlang.binary_to_term(value)
  end
end
