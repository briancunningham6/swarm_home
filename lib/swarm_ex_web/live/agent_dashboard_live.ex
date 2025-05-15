
defmodule SwarmExWeb.AgentDashboardLive do
  use Phoenix.LiveView
  alias SwarmEx.Client

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(SwarmEx.PubSub, "agents")
      {:ok, client} = SwarmEx.create_network()
      {:ok, assign(socket,
        client: client,
        agents: [],
        selected_agent: nil,
        new_agent_description: "",
        messages: %{},
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
    case Client.create_agent(socket.assigns.client, SwarmEx.Agent, instruction: description) do
      {:ok, agent_id} ->
        {:noreply, 
         socket 
         |> put_flash(:info, "Agent created successfully")
         |> assign(agents: [agent_id | socket.assigns.agents])}
      {:error, error} ->
        {:noreply, put_flash(socket, :error, "Failed to create agent: #{error}")}
    end
  end

  def handle_event("select_agent", %{"id" => agent_id}, socket) do
    {:noreply, assign(socket, selected_agent: agent_id)}
  end

  def handle_event("send_message", %{"message" => message}, socket) do
    case Client.send_message(socket.assigns.selected_agent, message) do
      {:ok, response} ->
        messages = Map.update(
          socket.assigns.messages,
          socket.assigns.selected_agent,
          [{:user, message}, {:agent, response}],
          &(&1 ++ [{:user, message}, {:agent, response}])
        )
        {:noreply, assign(socket, messages: messages, current_message: "")}
      {:error, error} ->
        {:noreply, put_flash(socket, :error, "Failed to send message: #{error}")}
    end
  end

  def handle_event("kill_agent", %{"id" => agent_id}, socket) do
    case Client.stop_agent(agent_id) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Agent terminated successfully")
         |> assign(agents: List.delete(socket.assigns.agents, agent_id),
                  selected_agent: nil)}
      {:error, error} ->
        {:noreply, put_flash(socket, :error, "Failed to terminate agent: #{error}")}
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
                      class={"#{if @selected_agent == agent_id, do: "font-bold", else: ""}"}>
                <%= agent_id %>
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
            <%= for {type, content} <- @messages[@selected_agent] || [] do %>
              <div class={"mb-4 #{if type == :user, do: "text-right"}"}>
                <div class={"inline-block p-2 rounded #{if type == :user, do: "bg-blue-100", else: "bg-gray-100"}"}>
                  <%= content %>
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
