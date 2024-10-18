ExUnit.start()
  
Application.put_env(:iconify_ex, Iconify.TestEndpoint, [
    server: false,
  secret_key_base: String.duplicate("a", 64),
  live_view: [signing_salt: String.duplicate("b", 64)]
])

Iconify.TestEndpoint.start_link()

# Ecto.Adapters.SQL.Sandbox.mode(
#   Bonfire.Common.Config.repo(),
#   :manual
# )
