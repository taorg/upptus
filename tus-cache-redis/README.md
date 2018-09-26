# Tus.Cache.Redis

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
