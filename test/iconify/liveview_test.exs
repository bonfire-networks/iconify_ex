defmodule Iconify.LiveViewTest do
  use ExUnit.Case
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  alias Phoenix.LiveView.Socket

  @endpoint Iconify.TestEndpoint

  # Define a simple LiveView for testing
  defmodule TestLive do
    use Phoenix.LiveView
    import Iconify

    def mount(_params, _session, socket) do
      {:ok, assign(socket, icon: "heroicons:chat-bubble-left-ellipsis-solid")}
    end

    def render(assigns) do
      ~H"""
      <.iconify icon={@icon} class={@icon} />
      """
    end

    def handle_event("change_icon", %{"icon" => new_icon}, socket) do
      {:noreply, assign(socket, icon: new_icon)}
    end
  end

  test "icon updates correctly when assign changes (v2 naming)" do
    {:ok, view, html} = live_isolated(build_conn(), TestLive)

    assert html =~ ~s(class="heroicons:chat-bubble-left-ellipsis-solid")
    assert html =~ ~s(iconify="heroicons:chat-bubble-left-ellipsis-solid")

    html = render_click(view, "change_icon", %{"icon" => "heroicons:envelope-solid"})

    assert html =~ ~s(class="heroicons:envelope-solid")
    assert html =~ ~s(iconify="heroicons:envelope-solid")
  end

  defmodule TestLiveV1 do
    use Phoenix.LiveView
    import Iconify

    def mount(_params, _session, socket) do
      {:ok, assign(socket, icon: "heroicons-solid:chat-bubble-left-ellipsis")}
    end

    def render(assigns) do
      ~H"""
      <.iconify icon={@icon} class={@icon} />
      """
    end

    def handle_event("change_icon", %{"icon" => new_icon}, socket) do
      {:noreply, assign(socket, icon: new_icon)}
    end
  end

  test "icon updates correctly with v1 backwards compatibility" do
    {:ok, view, html} = live_isolated(build_conn(), __MODULE__.TestLiveV1)

    # v1 name gets translated to v2 in the iconify attribute
    assert html =~ ~s(class="heroicons-solid:chat-bubble-left-ellipsis")
    assert html =~ ~s(iconify="heroicons:chat-bubble-left-ellipsis-solid")

    html = render_click(view, "change_icon", %{"icon" => "heroicons-solid:envelope"})

    assert html =~ ~s(class="heroicons-solid:envelope")
    assert html =~ ~s(iconify="heroicons:envelope-solid")
  end
end
