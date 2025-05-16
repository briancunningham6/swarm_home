
defmodule SwarmExWeb.Live.Models.DefaultResponse do
  @moduledoc "Defines a default structure for AI responses."
  use Ecto.Schema

  @primary_key false
  embedded_schema do
    field :text_response, :string
  end
end
