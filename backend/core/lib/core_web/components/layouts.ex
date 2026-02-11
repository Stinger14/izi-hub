defmodule CoreWeb.Layouts do
  use CoreWeb, :html

  def app_version do
    :core
    |> Application.spec(:vsn)
    |> to_string()
  end

  embed_templates "layouts/*"
end
