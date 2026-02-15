defmodule CoreWeb.Presence do
  @moduledoc false

  use Phoenix.Presence,
    otp_app: :core,
    pubsub_server: Core.PubSub
end
