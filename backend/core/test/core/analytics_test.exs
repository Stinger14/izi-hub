defmodule Core.AnalyticsTest do
  use Core.DataCase

  alias Core.Analytics

  describe "page_views" do
    alias Core.Analytics.PageView

    import Core.AnalyticsFixtures

    @invalid_attrs %{
      page_path: nil,
      referrer: nil,
      user_agent: nil,
      country: nil,
      city: nil,
      devive_type: nil
    }

    test "list_page_views/0 returns all page_views" do
      page_view = page_view_fixture()
      assert Analytics.list_page_views() == [page_view]
    end

    test "get_page_view!/1 returns the page_view with given id" do
      page_view = page_view_fixture()
      assert Analytics.get_page_view!(page_view.id) == page_view
    end

    test "create_page_view/1 with valid data creates a page_view" do
      valid_attrs = %{
        page_path: "some page_path",
        referrer: "some referrer",
        user_agent: "some user_agent",
        country: "some country",
        city: "some city",
        devive_type: "some devive_type"
      }

      assert {:ok, %PageView{} = page_view} = Analytics.create_page_view(valid_attrs)
      assert page_view.page_path == "some page_path"
      assert page_view.referrer == "some referrer"
      assert page_view.user_agent == "some user_agent"
      assert page_view.country == "some country"
      assert page_view.city == "some city"
      assert page_view.devive_type == "some devive_type"
    end

    test "create_page_view/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Analytics.create_page_view(@invalid_attrs)
    end

    test "update_page_view/2 with valid data updates the page_view" do
      page_view = page_view_fixture()

      update_attrs = %{
        page_path: "some updated page_path",
        referrer: "some updated referrer",
        user_agent: "some updated user_agent",
        country: "some updated country",
        city: "some updated city",
        devive_type: "some updated devive_type"
      }

      assert {:ok, %PageView{} = page_view} = Analytics.update_page_view(page_view, update_attrs)
      assert page_view.page_path == "some updated page_path"
      assert page_view.referrer == "some updated referrer"
      assert page_view.user_agent == "some updated user_agent"
      assert page_view.country == "some updated country"
      assert page_view.city == "some updated city"
      assert page_view.devive_type == "some updated devive_type"
    end

    test "update_page_view/2 with invalid data returns error changeset" do
      page_view = page_view_fixture()
      assert {:error, %Ecto.Changeset{}} = Analytics.update_page_view(page_view, @invalid_attrs)
      assert page_view == Analytics.get_page_view!(page_view.id)
    end

    test "delete_page_view/1 deletes the page_view" do
      page_view = page_view_fixture()
      assert {:ok, %PageView{}} = Analytics.delete_page_view(page_view)
      assert_raise Ecto.NoResultsError, fn -> Analytics.get_page_view!(page_view.id) end
    end

    test "change_page_view/1 returns a page_view changeset" do
      page_view = page_view_fixture()
      assert %Ecto.Changeset{} = Analytics.change_page_view(page_view)
    end
  end
end
