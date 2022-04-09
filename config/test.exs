import Config

verbose = !true
concise_level = :error

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :tonka, Tonka.Repo,
  hostname: "localhost",
  username: "tonka_test",
  password: "tonka_test",
  port: 55444,
  database: "tonka_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :tonka, TonkaWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "8x8EP7ydJbHZV5rWxyIKVMAOIJLtP+ziEyRDxELOywdPP070jfVbmeVesnejeex2",
  server: false

config :logger, level: if(verbose, do: :debug, else: concise_level)

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
