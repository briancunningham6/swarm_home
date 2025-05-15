# File: swarm_ex/config/config.exs

import Config

config :tailwind, :version, "4.0.9"

config :swarm_ex,
  default_timeout: 5_000,
  max_retries: 3,
  instructor: [
      adapter: Instructor.Adapters.OpenAI,
      openai: [api_key: System.fetch_env!("OPENAI_API_KEY")]
    ]


config :esbuild,
version: "0.25.0",
  default: [
    args: ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/js --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../node_modules", __DIR__)}
  ]



# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
