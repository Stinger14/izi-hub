defmodule Core.Studio.PoloClient do
  @moduledoc """
  HTTP client for the `polo_studio` service's writing helpers.

  Context: each helper builds its request from a piece and returns
  `{:ok, body}` (string keys) or `{:error, {status | :unreachable, message}}`,
  where `message` is safe to show the user (the service's `detail`). Calls
  can take a minute, so run them off the LiveView process (`start_async`).
  Tests stub requests through `config :core, :polo_client_req_options`.
  """

  require Logger

  @doc "Opening hooks from the piece's notes (or title)."
  def hooks(piece) do
    post("/api/v1/write/hooks", %{
      topic: piece.notes || piece.title,
      language: piece.language,
      kind: piece.kind
    })
  end

  @doc "A script outline from the piece's notes (or title)."
  def script(piece) do
    post("/api/v1/write/script", %{
      topic: piece.notes || piece.title,
      language: piece.language,
      kind: piece.kind
    })
  end

  @doc "Facebook caption variants from the transcript, notes or title, in that order."
  def caption(piece) do
    post("/api/v1/write/caption", %{
      source: piece.transcript || piece.notes || piece.title,
      language: piece.language
    })
  end

  defp post(path, body) do
    case Req.post(req(), url: path, json: body) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status, body: %{"detail" => detail}}} when is_binary(detail) ->
        {:error, {status, detail}}

      {:ok, %{status: status}} ->
        {:error, {status, "Polo Studio returned #{status}. Try again."}}

      {:error, exception} ->
        Logger.warning("Polo Studio #{path} failed: #{Exception.message(exception)}")
        {:error, {:unreachable, "Polo Studio is unreachable. Try again later."}}
    end
  end

  defp req do
    {:ok, base_url} = Core.Config.polo_studio_url()
    {:ok, key} = Core.Config.polo_studio_key()

    # AI calls can take a minute; retrying would pay for the same call twice
    Req.new(base_url: base_url, auth: {:bearer, key}, receive_timeout: 120_000, retry: false)
    |> Req.merge(Application.get_env(:core, :polo_client_req_options, []))
  end
end
