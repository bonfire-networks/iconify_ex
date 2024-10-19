defmodule Iconify.TestEndpoint do
  use Phoenix.Endpoint, otp_app: :iconify_ex

  @session_options [
    store: :cookie,
    key: "_my_app_key",
    signing_salt: "some_signing_salt"
  ]

  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]
end
