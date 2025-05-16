
defmodule SwarmExWeb.Live.Agents.DashboardAgent do
  use SwarmEx.Agent
  alias SwarmExWeb.Live.Models.DefaultResponse

  @impl true
  def init(opts) do
    {:ok, opts}
  end

  @impl true
  def handle_message(message, state) do
    response = Instructor.chat_completion(
      model: "gpt-3.5-turbo",
      response_model: DefaultResponse,
      messages: [
        %{
          role: "user",
          content: message
        }
      ]
    )

    case response do
      {:ok, reply} ->
        IO.puts("Got GPT response: #{inspect(reply)}")
        {:ok, reply, state}
      {:error, error} ->
        IO.puts("Error from GPT: #{inspect(error)}")
        {:error, SwarmEx.Error.AgentError.exception(
          agent: __MODULE__,
          reason: error,
          message: "Failed to get GPT response"
        )}
    end
  end
end
