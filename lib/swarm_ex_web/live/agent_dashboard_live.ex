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
    @spec handle_message(any(), any()) ::
            {:error, SwarmEx.Error.AgentError.t()} | {:ok, map(), any()}
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

      # Get all agents from database
      db_agents = SwarmEx.Repo.all(SwarmEx.Schemas.Agent)
      db_agent_ids = Enum.map(db_agents, & &1.agent_id)

      # Get running agents from client
      {:ok, running_agent_ids} = Client.list_agents(client)
      running_agent_ids = Enum.map(running_agent_ids, &to_string/1)

      # Merge both lists of agent IDs, ensuring running agents are recreated if not in DB
      all_agent_ids = Enum.uniq(running_agent_ids ++ db_agent_ids)

      # Load messages for each agent
      messages = db_agents
      |> Enum.map(fn agent -> 
        messages = SwarmEx.Repo.preload(agent, :messages).messages
        |> Enum.sort_by(& &1.inserted_at)
        |> Enum.map(fn msg -> 
          content = if msg.role == "assistant", do: %{text_response: msg.content}, else: msg.content
          {String.to_atom(msg.role), content}
        end)
        {agent.agent_id, messages}
      end)
      |> Map.new()

      # Ensure empty message list for any new running agents
      messages = Enum.reduce(running_agent_ids, messages, fn agent_id, acc ->
        Map.put_new(acc, agent_id, [])
      end)

      {:ok, assign(socket,
        client: client,
        agents: all_agent_ids,
        selected_agent: nil,
        new_agent_description: "",
        messages: messages,
        current_message: "",
        loading: false
      )}
    else
      {:ok, assign(socket,
        client: nil,
        agents: [], # Already empty, so no conversion needed here
        selected_agent: nil,
        new_agent_description: "",
        messages: %{},
        current_message: ""
      )}
    end
  end


  def handle_event("create_agent", %{"description" => description}, socket) do
    case Client.create_agent(socket.assigns.client, DashboardAgent, instruction: description) do
      {:ok, agent_id} -> # agent_id could be an atom or string from client
        string_agent_id = to_string(agent_id)
        IO.puts("Agent created with ID: #{string_agent_id}")
        {:noreply,
         socket
         |> put_flash(:info, "Agent created successfully")
         |> assign(agents: [string_agent_id | socket.assigns.agents],
                   messages: Map.put(socket.assigns.messages, string_agent_id, []))}
      {:error, error} ->
        IO.puts("Failed to create agent: #{inspect(error)}")
        {:noreply,
         socket
         |> put_flash(:error, "Failed to create agent: #{inspect(error)}")
         |> assign(agents: socket.assigns.agents)}
        {:noreply, put_flash(socket, :error, "Failed to create agent: #{inspect(error)}")}
    end
  end

  def handle_event("select_agent", %{"id" => agent_id_string}, socket) do
    {:noreply, assign(socket, selected_agent: agent_id_string)}
  end

  def handle_event("send_message", %{"message" => message}, socket) do
    selected_agent_id = socket.assigns.selected_agent

    if is_binary(selected_agent_id) && selected_agent_id != "" do
      socket = assign(socket, loading: true)
      case Client.send_message(socket.assigns.client, selected_agent_id, message) do
        {:ok, response} ->
          messages = Map.update(
            socket.assigns.messages,
            selected_agent_id,
            [{:user, message}, {:agent, response}],
            &(&1 ++ [{:user, message}, {:agent, response}])
          )
          {:noreply, assign(socket, messages: messages, current_message: "", loading: false)}
        {:error, error} ->
          {:noreply, put_flash(socket, :error, "Failed to send message: #{inspect(error)}")}
      end
    else
      {:noreply, put_flash(socket, :error, "No agent selected to send message.")}
    end
  end

  import Ecto.Query

  def handle_event("kill_agent", %{"id" => agent_id_string}, socket) do
    # First, stop the agent process
    process_result = Client.stop_agent(socket.assigns.client, agent_id_string)
    
    # Then, delete the agent and its messages from the database
    db_result = with {:ok, agent} <- SwarmEx.Repo.get_by(SwarmEx.Schemas.Agent, agent_id: agent_id_string) do
      # Delete all associated messages first
      query = from(m in SwarmEx.Schemas.Message, where: m.agent_id == ^agent.id)
      SwarmEx.Repo.delete_all(query)
      
      # Then delete the agent
      SwarmEx.Repo.delete(agent)
    end

    case {process_result, db_result} do
      {:ok, {:ok, _}} ->
        new_agents = List.delete(socket.assigns.agents, agent_id_string)
        new_selected_agent =
          if socket.assigns.selected_agent == agent_id_string do
            nil
          else
            socket.assigns.selected_agent
          end

        {:noreply,
         socket
         |> put_flash(:info, "Agent terminated and records deleted successfully")
         |> assign(
           agents: new_agents,
           selected_agent: new_selected_agent,
           messages: Map.delete(socket.assigns.messages, agent_id_string)
         )}
      
      {{:error, :agent_not_found}, _} ->
        {:noreply, put_flash(socket, :error, "Agent #{agent_id_string} not found")}
      
      {error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to terminate agent: #{inspect(error)}")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-purple-50 to-indigo-50 p-6">
      <div class="max-w-screen-2xl mx-auto">
        <div class="grid grid-cols-12 gap-8">
          <!-- Sidebar -->
          <div class="col-span-3 bg-white rounded-xl shadow-lg p-6 h-[85vh] flex flex-col">
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
                <div phx-key={agent_id} class="flex items-center justify-between p-4 rounded-lg transition-all duration-200 hover:bg-indigo-50 border border-indigo-100 mb-2">
                  <button phx-click="select_agent"
                          phx-value-id={agent_id}
                          class={"flex-1 text-left font-medium #{if @selected_agent == agent_id, do: "text-indigo-600", else: "text-gray-700"}"}>
                    Agent <%= agent_id %>
                  </button>
                  <button phx-click="kill_agent"
                          phx-value-id={agent_id}
                          class="ml-2 text-gray-400 hover:text-red-500 p-2 rounded-full hover:bg-red-50 transition-colors duration-200">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                    </svg>
                  </button>
                </div>
              <% end %>
            </div>
          </div>

          <!-- Chat Area -->
          <div class="col-span-9 bg-white rounded-xl shadow-lg flex flex-col h-[85vh]">
            <%= if @selected_agent do %>
              <div class="flex-1 p-6 overflow-y-auto">
                <%= for {type, content} <- @messages[@selected_agent] || [] do %>
                  <div class={"mb-4 #{if type == :user, do: 'flex justify-end'}"}>
                    <div class={"max-w-[80%] p-4 rounded-2xl #{if type == :user, do: 'bg-indigo-600 text-white', else: 'bg-gray-100 text-gray-800'}"}>
                      <%= if is_map(content) and Map.has_key?(content, :text_response) do %>
                        <%= content.text_response %>
                      <% else %>
                        <%= content %>
                      <% end %>
                    </div>
                  </div>
                <% end %>
              </div>
              <div :if={@loading} class="flex justify-center items-center p-4">
                <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600"></div>
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