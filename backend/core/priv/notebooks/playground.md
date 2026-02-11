# Izi Hub Playground

A quick preview of the Livebook notebook content. Use the Livebook card to run the real
notebook on the same host.

## Setup

```elixir
Mix.install([
  {:req, "~> 0.5"},
  {:jason, "~> 1.4"},
  {:kino, "~> 0.18.0"}
])

support_path = Path.expand("notebooks/_support/http.ex", File.cwd!())
Code.require_file(support_path)

base_url = System.get_env("IZI_HUB_BASE_URL", "http://localhost:4000")
client = Core.Notebooks.HTTP.client(base_url: base_url)
```

## Recipe template

Replace the path and payload with real API endpoints.

```elixir
path = "/api/your_endpoint"
payload = %{example: "value"}

resp = Core.Notebooks.HTTP.post_json(client, path, payload)

%{status: resp.status, body: resp.body}
```

## Authenticated requests

```elixir
token = System.get_env("IZI_HUB_TOKEN") || "REPLACE_ME"

client_with_auth =
  Core.Notebooks.HTTP.client(
    base_url: base_url,
    headers: [
      {"authorization", "Bearer " <> token},
      {"content-type", "application/json"}
    ]
  )
```
