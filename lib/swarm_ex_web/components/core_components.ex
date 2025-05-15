
defmodule SwarmExWeb.CoreComponents do
  use Phoenix.Component

  def flash(assigns) do
    ~H"""
    <div class="fixed top-2 right-2 w-80 sm:w-96 z-50 animate-fade-in-scale">
      <div :if={msg = Phoenix.Flash.get(@flash, :info)} role="alert" class="bg-green-50 p-4 rounded-lg mb-2">
        <p class="text-sm text-green-700"><%= msg %></p>
      </div>
      <div :if={msg = Phoenix.Flash.get(@flash, :error)} role="alert" class="bg-red-50 p-4 rounded-lg mb-2">
        <p class="text-sm text-red-700"><%= msg %></p>
      </div>
    </div>
    """
  end

  def flash_group(assigns) do
    ~H"""
    <div class="fixed top-2 right-2 w-80 sm:w-96 z-50 animate-fade-in-scale">
      <.flash flash={@flash} />
    </div>
    """
  end
end
