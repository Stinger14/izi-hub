defmodule Core.Repo.Migrations.AddSessionTokensAndActivateUsers do
  use Ecto.Migration

  def change do
    # Session tokens are looked up by hash on every request.
    create unique_index(:user_tokens, [:token_type, :token])

    # Sign-in now requires an active account. Users were created inactive by
    # default without anyone deactivating them, so keep everyone's access as
    # it was and make new accounts active.
    alter table(:users) do
      modify :is_active, :boolean, default: true, from: {:boolean, default: false}
    end

    execute "UPDATE users SET is_active = true", ""
  end
end
