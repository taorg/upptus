# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# Configures the endpoint
config :demo, DemoWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "1BjNCs75OlJfaZoJlIGEkFm+ZESBHcYOAL8puPm7h5IfOTWljndAhZ9sL89Q5kOt",
  render_errors: [view: DemoWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Demo.PubSub, adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# This is the config for the DemoWeb.UploadController
config :tus, DemoWeb.UploadController,
  # storage: Tus.Storage.Local,
  # base_path: "priv/static/files/",

  storage: Tus.Storage.S3,
  s3_host: "s3.eu-west-1.amazonaws.com",
  s3_bucket: "phantaweb",
  # s3_prefix: "",

  cache: Tus.Cache.Memory,
  max_size: 1024 * 1024 * 20
  #cache: Tus.Cache.Redis,
  #redis_host: "localhost",
  #redis_port: 6379,
  # max supported file size, in bytes (default 20 MB)
  #max_size: 1024 * 1024 * 20

# List here all of your upload controllers
config :tus, controllers: [DemoWeb.UploadController]

config :ex_aws,
  debug_requests: true,
  region: "eu-west-1",
  access_key_id: [{:system, "AWS_ACCESS_KEY_ID"}, :instance_role],
  secret_access_key: [{:system, "AWS_SECRET_ACCESS_KEY"}, :instance_role]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
