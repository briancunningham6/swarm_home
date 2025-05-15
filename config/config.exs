# File: swarm_ex/config/config.exs

import Config

config :tailwind, :version, "4.0.9"

config :swarm_ex,
  default_timeout: 5_000,
  max_retries: 3

# Configure esbuild (the version is fetched from your package.json or mix.lock)
config :esbuild,
  version: "0.25.0", # <-- Check your mix.lock for the exact version
  default: [
    args: ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../node_modules", __DIR__)}
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
