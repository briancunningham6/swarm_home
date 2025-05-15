
import Config

# Configure your database
config :swarm_ex, SwarmEx.Repo,
  database: Path.expand("../swarm_ex_dev.db", Path.dirname(__ENV__.file)),
  pool_size: 5,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true

# For development, we disable any cache and enable
# debugging and code reloading.
config :swarm_ex, SwarmExWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4005],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "developmentkeysupersecrethelloworld12345678901234567890",
  watchers: []

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime
