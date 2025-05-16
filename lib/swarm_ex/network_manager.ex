
defmodule SwarmEx.NetworkManager do
  use GenServer
  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    {:ok, client} = SwarmEx.ClientSupervisor.start_client()
    Logger.info("Started default client process: #{inspect(client)}")
    {:ok, %{client: client}}
  end
end
