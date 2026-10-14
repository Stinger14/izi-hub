defmodule CoreWeb.InvitationHTML do
  use CoreWeb, :html

  embed_templates "invitation_html/*"

  def inviter_name(%{full_name: name}) when is_binary(name) and name != "", do: name
  def inviter_name(%{username: name}) when is_binary(name) and name != "", do: name
  def inviter_name(_user), do: "A household member"

  def problem_message(:expired), do: "This invitation has expired. Ask for a new link."
  def problem_message(:used), do: "This invitation was already answered or cancelled."
  def problem_message(_reason), do: "This invitation link isn't valid."
end
