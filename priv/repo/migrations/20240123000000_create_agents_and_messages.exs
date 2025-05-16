
defmodule SwarmEx.Repo.Migrations.CreateAgentsAndMessages do
  use Ecto.Migration

  def change do
    create table(:agents) do
      add :agent_id, :string, null: false
      add :instruction, :text

      timestamps()
    end

    create table(:messages) do
      add :content, :text, null: false
      add :role, :string, null: false
      add :agent_id, references(:agents, on_delete: :delete_all)

      timestamps()
    end

    create index(:agents, [:agent_id])
    create index(:messages, [:agent_id])
  end
end
