defmodule CoreWeb.Layouts do
  use CoreWeb, :html

  def app_version do
    :core
    |> Application.spec(:vsn)
    |> to_string()
  end

  def liveview_version do
    case Application.spec(:phoenix_live_view, :vsn) do
      nil -> "unknown"
      vsn when is_list(vsn) -> List.to_string(vsn)
      vsn -> to_string(vsn)
    end
  end

  embed_templates "layouts/*"
end
