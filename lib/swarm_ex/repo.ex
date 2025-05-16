
defmodule SwarmEx.Repo do
  use Ecto.Repo,
    otp_app: :swarm_ex,
    adapter: Ecto.Adapters.Postgres
end
