defmodule Tus.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    cowboy_opts = [
      scheme: :http,
      plug: Tus.Router,
      options: [port: 4001]
    ]

    children = [
      {Registry, keys: :unique, name: Tus.UploadRegistry},
      Tus.UploadSupervisor,
      Plug.Adapters.Cowboy.child_spec(cowboy_opts)
    ]

    opts = [strategy: :one_for_one, name: Tus.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
