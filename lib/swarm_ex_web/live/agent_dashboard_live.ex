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
      model: "gpt-4o-mini",
      response_model: SwarmExWeb.AgentDashboardLive.DefaultResponse,
      messages: [
        %{
          role: "user",
          content: message
        }
      ]
    )
    case response do
      {:ok, reply } -> {:ok, reply, state }
      {:error, error } -> SwarmEx.Error.AgentError.exception(
        agent: __MODULE__, reason: error)
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
        agents: initial_agent_ids, # Populate with existing agent string IDs
        selected_agent: nil,
        new_agent_description: "",
        messages: Map.new(initial_agent_ids, fn id -> {id, []} end), # Initialize messages for existing agents
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
      {:ok, agent_id_string} -> # Now receives the string agent_id
        IO.puts("Agent created with ID: #{agent_id_string}")
        {:noreply,
         socket
         |> put_flash(:info, "Agent created successfully")
         |> assign(agents: [agent_id_string | socket.assigns.agents], # Store string ID
                   messages: Map.put(socket.assigns.messages, agent_id_string, []))} # Initialize messages for new agent
      {:error, error} ->
        {:noreply, put_flash(socket, :error, "Failed to create agent: #{inspect(error)}")}
    end
  end

  def handle_event("select_agent", %{"id" => agent_id_string}, socket) do
    # agent_id_string is the actual string ID from phx-value-id
    {:noreply, assign(socket, selected_agent: agent_id_string)}
  end

  def handle_event("send_message", %{"message" => message}, socket) do
    selected_agent_id = socket.assigns.selected_agent # This is now a string ID

    IO.inspect(selected_agent_id, label: "Selected Agent ID (should be string)")
    IO.puts("??")
    # Check if a string agent ID is selected
    if is_binary(selected_agent_id) && selected_agent_id != "" do
      IO.inspect(socket.assigns.client)
      IO.inspect(selected_agent_id, label: "Passing agent_id to Client.send_message")
      IO.inspect(message)
      # Call Client.send_message with the client PID, string agent ID, and message
      case Client.send_message(socket.assigns.client, selected_agent_id, message) do
        {:ok, response} ->
          IO.puts("yes this worked")
          messages = Map.update(
            socket.assigns.messages,
            selected_agent_id, # Use the correct string ID variable
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
    # agent_id_string is the actual string ID from phx-value-id
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
           messages: Map.delete(socket.assigns.messages, agent_id_string) # Clear messages by string ID
         )}
      {:error, :agent_not_found} ->
        {:noreply, put_flash(socket, :error, "Agent #{agent_id_string} not found.")}
      {:error, error} ->
        {:noreply, put_flash(socket, :error, "Failed to terminate agent: #{inspect(error)}")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="flex h-screen">
      <div class="w-1/4 bg-white p-4 border-r">
        <div class="mb-4">
          <form phx-submit="create_agent">
            <input type="text" name="description"
                   placeholder="Agent description..."
                   class="w-full p-2 border rounded"
                   value={@new_agent_description}/>
            <button type="submit" class="mt-2 w-full bg-blue-500 text-white p-2 rounded">
              Create Agent
            </button>
          </form>
        </div>

        <div class="space-y-2">
          <%= for agent_id <- @agents do %>
            <div class="flex justify-between items-center p-2 bg-gray-100 rounded">
              <button phx-click="select_agent" phx-value-id={agent_id}
                      class={"#{if @selected_agent == agent_id, do: "font-bold", else: ""}"}
                      >
                Agent <%= agent_id %>
              </button>
              <button phx-click="kill_agent" phx-value-id={agent_id}
                      class="text-red-500 hover:text-red-700">
                ×
              </button>
            </div>
          <% end %>
        </div>
      </div>

      <div class="flex-1 flex flex-col">
        <%= if @selected_agent do %>
          <div class="flex-1 p-4 overflow-y-auto">
            <%= for {type, raw_content} <- @messages[@selected_agent] || [] do %>
              <% content_to_display = if type == :agent, do: raw_content.text_response, else: raw_content %>
              <% content_for_id = if type == :agent, do: raw_content.text_response, else: raw_content %>
              <div class={"mb-4 #{if type == :user, do: "text-right"}"}
                   id={"msg-#{type}-#{content_for_id |> String.slice(0, 10) |> String.replace(~r/[^a-zA-Z0-9]/, "")}-#{System.unique_integer([:positive])}"}
              >
                <div class={"inline-block p-2 rounded #{if type == :user, do: "bg-blue-100", else: "bg-gray-100"}"}>
                  <%= content_to_display %>
                </div>
              </div>
            <% end %>
          </div>
          <div class="p-4 border-t">
            <form phx-submit="send_message" class="flex">
              <input type="text" name="message"
                     value={@current_message}
                     placeholder="Type your message..."
                     class="flex-1 p-2 border rounded-l"/>
              <button type="submit" class="bg-blue-500 text-white px-4 rounded-r">
                Send
              </button>
            </form>
          </div>
        <% else %>
          <div class="flex-1 flex items-center justify-center text-gray-500">
            Select an agent to start chatting
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
