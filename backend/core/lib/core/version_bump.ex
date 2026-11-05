defmodule Core.VersionBump do
  @moduledoc """
  Set of rules for bumping the app version from commit messages since the last release.

  Context: pure functions only, used by mix version.bump
  Commits are read as Type(scope)!: Summary; breaking changes bump minor before 1.0 and major after,
  features minor bump, all others are patch bumps.
  """

  @header ~r/^(?<type>[A-Za-z]+)(?:\((?<scope>[^)]*)\))?(?<bang>!)?:\s*(?<summary>.+)$/
  @version_line ~r/\bversion: "[^"]*"/
  @sections [features: "Features", fixes: "Fixes", chores: "Chores", other: "Other"]
  @changelog_title "# Changelog"

  def parse_commit(%{subject: subject, body: body}) do
    case Regex.named_captures(@header, subject) do
      %{"type" => type, "scope" => scope, "bang" => bang, "summary" => summary} ->
        %{
          type: String.downcase(type),
          scope: blank_to_nil(scope),
          summary: summary,
          breaking?: bang == "!" or breaking_body?(body)
        }

      nil ->
        %{type: "other", scope: nil, summary: subject, breaking?: breaking_body?(body)}
    end
  end

  def bump_level([]), do: :none

  def bump_level(commits) do
    cond do
      Enum.any?(commits, & &1.breaking?) -> :major
      Enum.any?(commits, &(&1.type == "feat")) -> :minor
      true -> :patch
    end
  end

  def next_version(current, level) do
    v = Version.parse!(current)

    case effective(level, v) do
      :major -> %{v | major: v.major + 1, minor: 0, patch: 0}
      :minor -> %{v | minor: v.minor + 1, patch: 0}
      :patch -> %{v | patch: v.patch + 1}
    end
    |> Map.merge(%{pre: [], build: nil})
    |> to_string()
  end

  def put_version(source, new_version) do
    case Regex.scan(@version_line, source) do
      [_one] -> {:ok, Regex.replace(@version_line, source, ~s(version: "#{new_version}"))}
      matches -> {:error, "expected one version line in mix.exs, found #{length(matches)}"}
    end
  end

  def changelog_section(version, %Date{} = date, commits) do
    groups = Enum.group_by(commits, &section/1)

    blocks =
      for {key, heading} <- @sections, entries = groups[key], entries != nil do
        lines = Enum.map_join(entries, "\n", &entry/1)
        "### #{heading}\n\n#{lines}\n"
      end

    Enum.join(["## v#{version} (#{Date.to_iso8601(date)})\n" | blocks], "\n")
  end

  def put_changelog(existing, section) do
    [heading | _] = String.split(section, "\n", parts: 2)

    if String.contains?(existing, heading) do
      {:error, "CHANGELOG.md already has #{heading}"}
    else
      rest =
        existing
        |> String.trim_leading()
        |> String.replace_prefix(@changelog_title, "")
        |> String.trim()

      body =
        if rest == "", do: section, else: section <> "\n" <> rest <> "\n"

      {:ok, @changelog_title <> "\n\n" <> body}
    end
  end

  defp effective(:major, %Version{major: 0}), do: :minor
  defp effective(level, _v), do: level

  defp breaking_body?(body), do: Regex.match?(~r/^BREAKING[ -]CHANGE:/m, body || "")

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(scope), do: scope

  defp section(%{type: "feat"}), do: :features
  defp section(%{type: type}) when type in ["fix", "hotfix"], do: :fixes
  defp section(%{type: "chore"}), do: :chores
  defp section(_commit), do: :other

  defp entry(commit), do: "- #{breaking_mark(commit)}#{commit.summary}#{scope_suffix(commit)}"

  defp breaking_mark(%{breaking?: true}), do: "**Breaking** "
  defp breaking_mark(_commit), do: ""

  defp scope_suffix(%{scope: nil}), do: ""
  defp scope_suffix(%{scope: scope}), do: " (#{scope})"
end
