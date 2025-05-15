
defmodule SwarmExWeb.SettingsLive do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="bg-white shadow rounded-lg">
      <div class="px-4 py-5 sm:p-6">
        <h3 class="text-lg font-medium leading-6 text-gray-900">Settings</h3>
        <div class="mt-2 max-w-xl text-sm text-gray-500">
          <p>Configure your SwarmEx instance settings here.</p>
        </div>
        <div class="mt-5">
          <div class="rounded-md bg-gray-50 p-4">
            <div class="text-sm text-gray-700">
              Settings configuration will be added here.
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
