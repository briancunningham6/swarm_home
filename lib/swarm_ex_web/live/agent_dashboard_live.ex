
defmodule SwarmExWeb.AgentDashboardLive do
  use Phoenix.LiveView
  alias SwarmEx.Client

  defmodule DefaultResponse do
    @moduledoc "Defines a default structure for AI responses."
    use Ecto.Schema

    @primary_key false
    embedded_schema do
      field :text_response, :string
    end
  end

  defmodule DashboardAgent do
    use SwarmEx.Agent

    @impl true
    def init(opts) do
      {:ok, opts}
    end

    @impl true
    def handle_message(message, state) do
      response = Instructor.chat_completion(
        model: "gpt-3.5-turbo",
        response_model: SwarmExWeb.AgentDashboardLive.DefaultResponse,
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

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(SwarmEx.PubSub, "agents")
      {:ok, client} = SwarmEx.create_network()
      {:ok, initial_agent_ids} = Client.list_agents(client)

      {:ok, assign(socket,
        client: client,
        agents: initial_agent_ids,
        selected_agent: nil,
        new_agent_description: "",
        messages: Map.new(initial_agent_ids, fn id -> {id, []} end),
        current_message: ""
      )}
    else
      {:ok, assign(socket,
        client: nil,
        agents: [],
        selected_agent: nil,
        new_agent_description: "",
        messages: %{},
        current_message: ""
      )}
    end
  end

  def handle_event("create_agent", %{"description" => description}, socket) do
    case Client.create_agent(socket.assigns.client, DashboardAgent, instruction: description) do
      {:ok, agent_id_string} ->
        IO.puts("Agent created with ID: #{agent_id_string}")
        {:noreply,
         socket
         |> put_flash(:info, "Agent created successfully")
         |> assign(agents: [agent_id_string | socket.assigns.agents],
                   messages: Map.put(socket.assigns.messages, agent_id_string, []))}
      {:error, error} ->
        {:noreply, put_flash(socket, :error, "Failed to create agent: #{inspect(error)}")}
    end
  end

  def handle_event("select_agent", %{"id" => agent_id_string}, socket) do
    {:noreply, assign(socket, selected_agent: agent_id_string)}
  end

  def handle_event("send_message", %{"message" => message}, socket) do
    selected_agent_id = socket.assigns.selected_agent

    if is_binary(selected_agent_id) && selected_agent_id != "" do
      case Client.send_message(socket.assigns.client, selected_agent_id, message) do
        {:ok, response} ->
          messages = Map.update(
            socket.assigns.messages,
            selected_agent_id,
            [{:user, message}, {:agent, response}],
            &(&1 ++ [{:user, message}, {:agent, response}])
          )
          {:noreply, assign(socket, messages: messages, current_message: "")}
        {:error, error} ->
          {:noreply, put_flash(socket, :error, "Failed to send message: #{inspect(error)}")}
      end
    else
      {:noreply, put_flash(socket, :error, "No agent selected to send message.")}
    end
  end

  def handle_event("kill_agent", %{"id" => agent_id_string}, socket) do
    case Client.stop_agent(socket.assigns.client, agent_id_string) do
      :ok ->
        new_agents = List.delete(socket.assigns.agents, agent_id_string)
        new_selected_agent =
          if socket.assigns.selected_agent == agent_id_string do
            nil
          else
            socket.assigns.selected_agent
          end

        {:noreply,
         socket
         |> put_flash(:info, "Agent terminated successfully")
         |> assign(
           agents: new_agents,
           selected_agent: new_selected_agent,
           messages: Map.delete(socket.assigns.messages, agent_id_string)
         )}
      {:error, :agent_not_found} ->
        {:noreply, put_flash(socket, :error, "Agent #{agent_id_string} not found.")}
      {:error, error} ->
        {:noreply, put_flash(socket, :error, "Failed to terminate agent: #{inspect(error)}")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-purple-50 to-indigo-50 p-4">
      <div class="max-w-7xl mx-auto">
        <div class="grid grid-cols-1 lg:grid-cols-4 gap-6">
          <!-- Sidebar -->
          <div class="lg:col-span-1 bg-white rounded-xl shadow-lg p-6">
            <h2 class="text-2xl font-bold text-gray-800 mb-6">Agents</h2>
            <div class="mb-6">
              <form phx-submit="create_agent" class="space-y-4">
                <input type="text" 
                       name="description"
                       placeholder="Agent description..."
                       class="w-full px-4 py-2 rounded-lg border border-gray-200 focus:ring-2 focus:ring-indigo-400 focus:border-transparent"
                       value={@new_agent_description}/>
                <button type="submit" 
                        class="w-full bg-indigo-600 text-white py-2 px-4 rounded-lg hover:bg-indigo-700 transition duration-200">
                  Create Agent
                </button>
              </form>
            </div>

            <div class="space-y-3">
              <%= for agent_id <- @agents do %>
                <div class="flex items-center justify-between p-3 rounded-lg transition-all duration-200 
                           <%= if @selected_agent == agent_id, do: "bg-indigo-100 border-2 border-indigo-300", else: "bg-gray-50 hover:bg-gray-100" %>">
                  <button phx-click="select_agent" 
                          phx-value-id={agent_id}
                          class={"flex-1 text-left font-medium #{if @selected_agent == agent_id, do: "text-indigo-700", else: "text-gray-700"}"}>
                    Agent <%= agent_id %>
                  </button>
                  <button phx-click="kill_agent" 
                          phx-value-id={agent_id}
                          class="ml-2 text-red-500 hover:text-red-700 p-1 rounded-full hover:bg-red-50">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                      <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
                    </svg>
                  </button>
                </div>
              <% end %>
            </div>
          </div>

          <!-- Chat Area -->
          <div class="lg:col-span-3 bg-white rounded-xl shadow-lg flex flex-col h-[800px]">
            <%= if @selected_agent do %>
              <div class="flex-1 p-6 overflow-y-auto">
                <%= for {type, raw_content} <- @messages[@selected_agent] || [] do %>
                  <% content_to_display = if type == :agent, do: raw_content.text_response, else: raw_content %>
                  <% content_for_id = if type == :agent, do: raw_content.text_response, else: raw_content %>
                  <div class={"mb-4 #{if type == :user, do: "flex justify-end"}"}>
                    <div class={"max-w-[80%] p-4 rounded-2xl #{if type == :user, do: "bg-indigo-600 text-white", else: "bg-gray-100 text-gray-800"}"}>
                      <%= content_to_display %>
                    </div>
                  </div>
                <% end %>
              </div>
              <div class="p-6 border-t border-gray-100">
                <form phx-submit="send_message" class="flex space-x-4">
                  <input type="text" 
                         name="message"
                         value={@current_message}
                         placeholder="Type your message..."
                         class="flex-1 px-4 py-3 rounded-xl border border-gray-200 focus:ring-2 focus:ring-indigo-400 focus:border-transparent"/>
                  <button type="submit" 
                          class="px-6 py-3 bg-indigo-600 text-white rounded-xl hover:bg-indigo-700 transition duration-200 flex items-center">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                      <path d="M10.894 2.553a1 1 0 00-1.788 0l-7 14a1 1 0 001.169 1.409l5-1.429A1 1 0 009 15.571V11a1 1 0 112 0v4.571a1 1 0 00.725.962l5 1.428a1 1 0 001.17-1.408l-7-14z" />
                    </svg>
                  </button>
                </form>
              </div>
            <% else %>
              <div class="flex-1 flex items-center justify-center text-gray-500">
                <div class="text-center">
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-16 w-16 mx-auto text-gray-400 mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
                  </svg>
                  <p class="text-xl font-medium">Select an agent to start chatting</p>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
