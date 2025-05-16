defmodule SwarmExWeb.Live.Agents.DashboardAgent do
  use SwarmEx.Agent
  alias SwarmExWeb.Live.Models.DefaultResponse

  @impl true
  def init(opts) do
    state = Map.put(opts, :conversation_history, [])
    {:ok, state}
  end

  @impl true
  def handle_message(message, state) do
    history = state.conversation_history
    messages = build_conversation_messages(history, message)

    response = Instructor.chat_completion(
      model: "gpt-3.5-turbo",
      response_model: DefaultResponse,
      messages: messages
    )

    case response do
      {:ok, reply} ->
        IO.puts("Got GPT response: #{inspect(reply)}")

        # Save agent if not exists
        {:ok, db_agent} = case SwarmEx.Repo.get_by(SwarmEx.Schemas.Agent, agent_id: Atom.to_string(state.name)) do
          nil -> 
            SwarmEx.Repo.insert(%SwarmEx.Schemas.Agent{
              agent_id: Atom.to_string(state.name),
              instruction: state.instruction
            })
          existing -> {:ok, existing}
        end

        # Save messages
        SwarmEx.Repo.insert(%SwarmEx.Schemas.Message{
          content: message,
          role: "user",
          agent_id: db_agent.id
        })

        SwarmEx.Repo.insert(%SwarmEx.Schemas.Message{
          content: reply.text_response,
          role: "assistant", 
          agent_id: db_agent.id
        })

        new_history = history ++ [
          %{role: "user", content: message},
          %{role: "assistant", content: reply.text_response}
        ]
        {:ok, reply, %{state | conversation_history: new_history}}
      {:error, error} ->
        IO.puts("Error from GPT: #{inspect(error)}")
        {:error, SwarmEx.Error.AgentError.exception(
          agent: __MODULE__,
          reason: error,
          message: "Failed to get GPT response"
        )}
    end
  end

  defp build_conversation_messages(history, new_message) do
    # Convert history to ChatGPT message format and add system message
    [%{role: "system", content: "You are a helpful AI assistant."}] ++
    history ++
    [%{role: "user", content: new_message}]
  end
end