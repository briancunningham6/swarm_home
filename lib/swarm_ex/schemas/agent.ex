
defmodule SwarmEx.Schemas.Agent do
  use Ecto.Schema
  import Ecto.Changeset

  schema "agents" do
    field :agent_id, :string
    field :instruction, :string
    has_many :messages, SwarmEx.Schemas.Message

    timestamps()
  end

  def changeset(agent, attrs) do
    agent
    |> cast(attrs, [:agent_id, :instruction])
    |> validate_required([:agent_id])
  end
end
