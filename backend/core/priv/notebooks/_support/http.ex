defmodule Core.Notebooks.HTTP do
  @moduledoc false

  def client(opts \\ []) do
    base_url =
      Keyword.get(
        opts,
        :base_url,
        System.get_env("IZI_HUB_BASE_URL", "http://localhost:4000")
      )

    headers = Keyword.get(opts, :headers, default_headers())

    Req.new(base_url: base_url, headers: headers)
  end

  def get(client, path, params \\ %{}) do
    Req.request!(client, method: :get, url: path, params: params)
  end

  def post_json(client, path, body) do
    Req.request!(client, method: :post, url: path, json: body)
  end

  def put_json(client, path, body) do
    Req.request!(client, method: :put, url: path, json: body)
  end

  def delete(client, path) do
    Req.request!(client, method: :delete, url: path)
  end

  defp default_headers do
    [{"content-type", "application/json"}]
  end
end
