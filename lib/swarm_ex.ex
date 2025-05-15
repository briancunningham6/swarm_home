defmodule SwarmEx do
  @moduledoc """
  SwarmEx is an Elixir library for lightweight, controllable, and testable AI agent orchestration.

  It provides a simple API for creating and managing networks of AI agents, with features including:

  - Agent lifecycle management
  - Message routing between agents
  - Network state management
  - Error handling and recovery

  ## Example

      # Create a new agent network
      {:ok, network} = SwarmEx.create_network()

      # Define a tool as a regular module with functions
      defmodule ClassifyTool do
        def classify(text) do
          # Perform classification
          {:ok, result}
        end
      end

      # Define an agent that uses the tool
      defmodule MyAgent do
        use SwarmEx.Agent

        def init(opts), do: {:ok, opts}

        def handle_message(msg, state) do
          case ClassifyTool.classify(msg) do
            {:ok, result} -> {:ok, result, state}
            error -> error
          end
        end
      end

      # Add an agent to the network
      {:ok, agent_pid} = SwarmEx.create_agent(network, MyAgent)

      # Send a message to the agent
      {:ok, response} = SwarmEx.send_message(agent_pid, "Hello!")
  """

  alias SwarmEx.{Client, Agent, Error, ClientSupervisor}

  @type network :: pid()
  @type agent :: pid() | String.t()
  @type message :: term()
  @type response :: {:ok, term()} | {:error, term()}

  @doc """
  Creates a new agent network with the given configuration.

  ## Options

    * `:name` - Optional name for the network
    * `:context` - Initial context map (default: %{})
    * All other options are passed to the underlying Client

  ## Examples

      {:ok, network} = SwarmEx.create_network()
      {:ok, named_network} = SwarmEx.create_network(name: "primary_network")

  """
  @spec create_network(keyword()) :: {:ok, network()} | {:error, term()}
  def create_network(opts \\ []) do
    case ClientSupervisor.start_client(opts) do
      {:ok, _pid} = success ->
        success

      {:error, reason} ->
        {:error, Error.NetworkError.exception(reason: reason)}
    end
  end

  @doc """
  Creates a new agent in the given network.

  ## Options

    * `:name` - Optional name for the agent
    * `:instruction` - Base instruction/prompt for the agent
    * All other options are passed to the agent's init/1 callback

  ## Examples

      {:ok, agent} = SwarmEx.create_agent(network, MyAgent)
      {:ok, agent} = SwarmEx.create_agent(network, MyAgent, name: "processor")
  """
  @spec create_agent(network(), module(), keyword()) :: {:ok, agent()} | {:error, term()}
  def create_agent(network, agent_module, opts \\ []) do
    case Client.create_agent(network, agent_module, opts) do
      {:ok, _pid} = success ->
        success

      {:error, reason} ->
        {:error, Error.AgentError.exception(agent: agent_module, reason: reason)}
    end
  end

  @doc """
  Sends a message to an agent identified by PID and waits for the response.

  ## Examples

      {:ok, response} = SwarmEx.send_message_to_pid(agent_pid, "Process this")
  """
  @spec send_message_to_pid(pid(), message()) :: response()
  def send_message_to_pid(agent_pid, message) when is_pid(agent_pid) do
    try do
      GenServer.call(agent_pid, {:message, message},:infinity)
    catch
      :exit, reason ->
        {:error,
         Error.AgentError.exception(
           agent: agent_pid,
           reason: reason,
           message: "Failed to send message to agent"
         )}
    end
  end

  @doc """
  Sends a message to an agent identified by ID within a network and waits for the response.

  ## Examples

      {:ok, response} = SwarmEx.send_message(network, "agent_id", "Process this")
  """
  @spec send_message(network(), String.t(), message()) :: response()
  def send_message(network, agent_id, message) when is_pid(network) and is_binary(agent_id) do
    case Client.send_message(network, agent_id, message) do
      {:ok, _response} = success ->
        success

      {:error, reason} ->
        {:error,
         Error.NetworkError.exception(
           network_id: agent_id,
           reason: reason,
           message: "Failed to send message through network"
         )}
    end
  end

  @doc """
  Lists all active agents in a network.

  ## Examples

      {:ok, agent_ids} = SwarmEx.list_agents(network)
  """
  @spec list_agents(network()) :: {:ok, [String.t()]} | {:error, term()}
  def list_agents(network) do
    case Client.list_agents(network) do
      {:ok, _agents} = success ->
        success

      {:error, reason} ->
        {:error, Error.NetworkError.exception(reason: reason)}
    end
  end

  @doc """
  Updates the shared context for a network of agents.

  ## Examples

      {:ok, context} = SwarmEx.update_context(network, %{key: "value"})
  """
  @spec update_context(network(), map()) :: {:ok, map()} | {:error, term()}
  def update_context(network, context) when is_map(context) do
    case Client.update_context(network, context) do
      {:ok, _context} = success ->
        success

      {:error, reason} ->
        {:error, Error.NetworkError.exception(reason: reason)}
    end
  end

  @doc """
  Gets the current context for a network of agents.

  ## Examples

      {:ok, context} = SwarmEx.get_context(network)
  """
  @spec get_context(network()) :: {:ok, map()} | {:error, term()}
  def get_context(network) do
    case Client.get_context(network) do
      {:ok, _context} = success ->
        success

      {:error, reason} ->
        {:error, Error.NetworkError.exception(reason: reason)}
    end
  end

  @doc """
  Registers a new tool that can be used by agents in the network.

  This function is deprecated. Instead of using the Tool API, define your tools as regular modules
  with functions. See the module documentation for examples.

  ## Examples

      SwarmEx.register_tool(MyTool, max_retries: 3)
  """
  @deprecated "Tools should be implemented as regular modules with functions instead of using the Tool API"
  @spec register_tool(module(), keyword()) :: :ok | {:error, term()}
  def register_tool(tool_module, opts \\ []) do
    require Logger

    Logger.warning(
      "SwarmEx.register_tool/2 is deprecated. Tools should be implemented as regular modules with functions."
    )

    case SwarmEx.Tool.register(tool_module, opts) do
      :ok ->
        :ok

      {:error, reason} ->
        {:error, Error.ToolError.exception(tool: tool_module, reason: reason)}
    end
  end

  @doc """
  Stops an agent and removes it from its network.

  ## Examples

      :ok = SwarmEx.stop_agent(agent)
      :ok = SwarmEx.stop_agent(agent, :shutdown)
  """
  @spec stop_agent(agent(), term()) :: :ok | {:error, term()}
  def stop_agent(agent, reason \\ :normal) do
    case Agent.stop(agent, reason) do
      :ok ->
        :ok

      {:error, reason} ->
        {:error, Error.AgentError.exception(agent: agent, reason: reason)}
    end
  end

  @doc """
  Returns the version of the SwarmEx library.
  """
  @spec version() :: String.t()
  def version, do: "0.2.0"
end
