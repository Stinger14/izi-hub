defmodule Core.Accounts.UserAvatarTest do
  use Core.DataCase, async: true

  alias Core.Accounts

  @png <<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A, "rest-of-png">>

  test "accepts JPEG, PNG, GIF and WebP by their bytes" do
    user = user_fixture()

    for {bytes, type} <- [
          {<<0xFF, 0xD8, 0xFF, 0xE0, "jpeg">>, "image/jpeg"},
          {@png, "image/png"},
          {"GIF89a-gif", "image/gif"},
          {"RIFF" <> <<0, 0, 0, 0>> <> "WEBPVP8 ", "image/webp"}
        ] do
      assert {:ok, saved} = Accounts.put_user_avatar(user, bytes)
      assert saved.avatar_updated_at
      assert %{content_type: ^type, data: ^bytes} = Accounts.get_user_avatar(user.id)
    end
  end

  test "rejects SVG, other files and anything over the size limit" do
    user = user_fixture()

    assert {:error, :invalid_image} =
             Accounts.put_user_avatar(user, ~s(<svg xmlns="http://www.w3.org/2000/svg"/>))

    assert {:error, :invalid_image} = Accounts.put_user_avatar(user, "just text named .png")

    too_big = @png <> :binary.copy("a", Accounts.avatar_max_bytes())
    assert {:error, :too_large} = Accounts.put_user_avatar(user, too_big)

    assert Accounts.get_user_avatar(user.id) == nil
  end

  test "deleting clears the photo and its timestamp" do
    {:ok, user} = Accounts.put_user_avatar(user_fixture(), @png)

    assert {:ok, user} = Accounts.delete_user_avatar(user)
    assert user.avatar_updated_at == nil
    assert Accounts.get_user_avatar(user.id) == nil
  end
end
