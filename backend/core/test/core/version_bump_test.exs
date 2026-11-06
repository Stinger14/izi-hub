defmodule Core.VersionBumpTest do
  use ExUnit.Case, async: true

  alias Core.VersionBump

  defp commit(type, summary, opts \\ []) do
    %{
      type: type,
      scope: Keyword.get(opts, :scope),
      summary: summary,
      breaking?: Keyword.get(opts, :breaking?, false)
    }
  end

  describe "parse_commit/1" do
    test "reads type, scope and summary" do
      assert VersionBump.parse_commit(%{subject: "Feat(core): Add X", body: ""}) ==
               %{type: "feat", scope: "core", summary: "Add X", breaking?: false}
    end

    test "works without a scope and ignores the type's case" do
      assert %{type: "fix", scope: nil, summary: "Handle Y"} =
               VersionBump.parse_commit(%{subject: "FIX: Handle Y", body: ""})
    end

    test "a ! before the colon marks a breaking change" do
      assert %{type: "feat", breaking?: true} =
               VersionBump.parse_commit(%{subject: "Feat(web)!: Drop Z", body: ""})

      assert %{type: "chore", breaking?: true} =
               VersionBump.parse_commit(%{subject: "chore!: Drop Z", body: nil})
    end

    test "a BREAKING CHANGE line anywhere in the body marks a breaking change" do
      body = "Context first.\nBREAKING CHANGE: sessions are reset"

      assert %{type: "refactor", breaking?: true} =
               VersionBump.parse_commit(%{subject: "Refactor: Rework auth", body: body})

      assert %{breaking?: true} =
               VersionBump.parse_commit(%{subject: "Fix: X", body: "BREAKING-CHANGE: y"})
    end

    test "only a line starting with BREAKING CHANGE counts" do
      assert %{breaking?: false} =
               VersionBump.parse_commit(%{subject: "Docs: X", body: "no BREAKING CHANGE: here"})
    end

    test "subjects without a type become other" do
      assert VersionBump.parse_commit(%{
               subject: "Merge pull request #67 from x/develop",
               body: ""
             }) ==
               %{
                 type: "other",
                 scope: nil,
                 summary: "Merge pull request #67 from x/develop",
                 breaking?: false
               }
    end
  end

  describe "bump_level/1" do
    test "no commits means nothing to release" do
      assert VersionBump.bump_level([]) == :none
    end

    test "any breaking change wins" do
      assert VersionBump.bump_level([commit("fix", "a"), commit("docs", "b", breaking?: true)]) ==
               :major
    end

    test "a feature without breaking changes is minor" do
      assert VersionBump.bump_level([commit("fix", "a"), commit("feat", "b")]) == :minor
    end

    test "anything else is a patch" do
      assert VersionBump.bump_level([commit("chore", "a"), commit("docs", "b")]) == :patch
      assert VersionBump.bump_level([commit("other", "Merge …")]) == :patch
    end
  end

  describe "next_version/2" do
    test "bumps each level and resets the lower ones" do
      assert VersionBump.next_version("0.10.3", :patch) == "0.10.4"
      assert VersionBump.next_version("0.10.3", :minor) == "0.11.0"
      assert VersionBump.next_version("1.4.2", :major) == "2.0.0"
    end

    test "a breaking change before 1.0 bumps minor" do
      assert VersionBump.next_version("0.10.3", :major) == "0.11.0"
    end

    test "drops pre-release and build metadata" do
      assert VersionBump.next_version("0.11.0-rc.1+build.5", :patch) == "0.11.1"
    end

    test "rejects a version that isn't semver" do
      assert_raise Version.InvalidVersionError, fn -> VersionBump.next_version("0.10", :patch) end
    end
  end

  describe "put_version/2" do
    @mix_exs """
    def project do
      [
        app: :core,
        version: "0.10.0",
        elixir: "~> 1.15"
      ]
    end
    """

    test "replaces the version line only" do
      assert {:ok, source} = VersionBump.put_version(@mix_exs, "0.11.0")
      assert source =~ ~s(version: "0.11.0")
      refute source =~ "0.10.0"
      assert source =~ ~s(elixir: "~> 1.15")
    end

    test "errors when there's no version line or more than one" do
      assert {:error, "expected one version line in mix.exs, found 0"} =
               VersionBump.put_version("def project, do: []", "0.11.0")

      twice = @mix_exs <> ~s(# version: "0.9.0"\n)

      assert {:error, "expected one version line in mix.exs, found 2"} =
               VersionBump.put_version(twice, "0.11.0")
    end

    test "matches exactly one line in this app's mix.exs" do
      assert {:ok, _source} = "mix.exs" |> File.read!() |> VersionBump.put_version("9.9.9")
    end
  end

  describe "changelog_section/3" do
    test "groups commits under fixed headings, in order, with scopes when present" do
      commits = [
        commit("docs", "Document X", scope: "core"),
        commit("chore", "Bump deps"),
        commit("hotfix", "Patch Y", scope: "web"),
        commit("feat", "Add Z")
      ]

      assert VersionBump.changelog_section("0.11.0", ~D[2026-10-28], commits) == """
             ## v0.11.0 (2026-10-28)

             ### Features

             - Add Z

             ### Fixes

             - Patch Y (web)

             ### Chores

             - Bump deps

             ### Other

             - Document X (core)
             """
    end

    test "skips sections without commits" do
      section = VersionBump.changelog_section("0.10.1", ~D[2026-10-28], [commit("fix", "A")])

      assert section == "## v0.10.1 (2026-10-28)\n\n### Fixes\n\n- A\n"
    end

    test "keeps the given order within a section" do
      section =
        VersionBump.changelog_section("0.11.0", ~D[2026-10-28], [
          commit("feat", "Newest"),
          commit("feat", "Oldest")
        ])

      assert section =~ "- Newest\n- Oldest\n"
    end

    test "marks breaking changes, with or without a scope, and leaves others alone" do
      commits = [
        commit("feat", "Drop X", scope: "web", breaking?: true),
        commit("fix", "Rework Y", breaking?: true),
        commit("feat", "Add Z")
      ]

      section = VersionBump.changelog_section("0.11.0", ~D[2026-10-31], commits)

      assert section =~ "- **Breaking** Drop X (web)\n"
      assert section =~ "- **Breaking** Rework Y\n"
      assert section =~ "- Add Z\n"
      refute section =~ "**Breaking** Add Z"
    end
  end

  describe "put_changelog/2" do
    @section "## v0.11.0 (2026-10-28)\n\n### Features\n\n- Add Z\n"
    @older "## v0.10.0 (2026-10-12)\n\n### Fixes\n\n- Old fix\n"

    test "starts a new file with the title" do
      assert VersionBump.put_changelog("", @section) == {:ok, "# Changelog\n\n" <> @section}
    end

    test "puts the new section above older ones, one blank line apart" do
      assert VersionBump.put_changelog("# Changelog\n\n" <> @older, @section) ==
               {:ok, "# Changelog\n\n" <> @section <> "\n" <> @older}
    end

    test "adds the title to a file that lacks one and tidies stray blank lines" do
      assert VersionBump.put_changelog("\n\n" <> @older <> "\n\n", @section) ==
               {:ok, "# Changelog\n\n" <> @section <> "\n" <> @older}
    end

    test "refuses to add the same release twice" do
      {:ok, text} = VersionBump.put_changelog("", @section)

      assert {:error, "CHANGELOG.md already has ## v0.11.0 (2026-10-28)"} =
               VersionBump.put_changelog(text, @section)
    end
  end
end
