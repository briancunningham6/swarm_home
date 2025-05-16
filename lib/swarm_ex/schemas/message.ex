
defmodule SwarmEx.Schemas.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "messages" do
    field :content, :string
    field :role, :string
    belongs_to :agent, SwarmEx.Schemas.Agent

    timestamps()
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:content, :role, :agent_id])
    |> validate_required([:content, :role, :agent_id])
  end
end
