defmodule Mix.Tasks.Version.Bump do
  @shortdoc "Computes the next app version from commits since last v* tag"

  @moduledoc """
  Bumps the version from the commits since the last release tag.

      mix version.bump                  # dry run: show the next version and why
      mix version.bump --apply           # writes mix.exs and CHANGELOG.md
      mix version.bump --level patch     # Overrides the computed bump

  """
  use Mix.Task

  alias Core.VersionBump

  @switches [apply: :boolean, level: :string]
  @levels %{"major" => :major, "minor" => :minor, "patch" => :patch}

  # ------------------- Main Flow -------------------#

  @impl Mix.Task
  def run(args) do
    opts = parse_opts!(args)
    tag = last_tag!()
    current = Mix.Project.config()[:version]
    ensure_released!(current, tag)

    commits =
      tag
      |> commits_since()
      |> Enum.map(&VersionBump.parse_commit/1)

    case level(opts, commits) do
      :none ->
        Mix.shell().info("Nothing to release since #{tag}.")

      level ->
        next = VersionBump.next_version(current, level)
        print_summary(tag, commits, current, next, level)
        if opts[:apply], do: apply!(next, commits), else: Mix.shell().info(dry_run_hint())
    end
  end

  # ------------------- Flags and --level -------------------#
  defp parse_opts!(args) do
    {opts, _rest} = OptionParser.parse!(args, strict: @switches)
    opts
  end

  defp level(opts, commits) do
    case opts[:level] do
      nil -> VersionBump.bump_level(commits)
      name -> Map.get(@levels, name) || Mix.raise("--level must be major, minor or patch")
    end
  end

  defp last_tag! do
    case System.cmd("git", ~w(describe --tags --abbrev=0 --match v*), stderr_to_stdout: true) do
      {tag, 0} ->
        String.trim(tag)

      {_output, _status} ->
        Mix.raise("No v* tag found. Tag the last release first, e.g. git tag v0.0.1")
    end
  end

  defp commits_since(tag) do
    {out, 0} =
      System.cmd("git", ["log", "#{tag}..HEAD", "--no-merges", "--format=%s%x1f%b%x1e", "--", "."])

    out
    |> String.split("\x1e")
    |> Enum.map(&String.trim_leading/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(fn entry ->
      [subject, body] =
        entry
        |> String.trim_leading()
        |> String.split("\x1f", parts: 2)

      %{subject: subject, body: body}
    end)
  end

  # protection against bumping twice
  defp ensure_released!(current, tag) do
    if "v" <> current != tag do
      Mix.raise(
        "mix.exs is #{current} but the last tag is #{tag}. Already bumped? " <>
          "Tag the release (git tag v#{current}) before bumping again."
      )
    end
  end

  defp print_summary(tag, commits, current, next, level) do
    counts =
      commits
      |> Enum.frequencies_by(& &1.type)
      |> Enum.sort_by(fn {type, n} -> {-n, type} end)
      |> Enum.map_join(", ", fn {type, n} -> "#{n} #{type}" end)

    Mix.shell().info("""
    Last release: #{tag} · #{length(commits)} commits since (#{counts})
    Next version: #{current} → #{next} (#{level})
    """)
  end

  defp dry_run_hint,
    do: "Dry run: nothing written. Add --apply to update mix.exs and CHANGELOG.md."

  defp apply!(next, commits) do
    mix_file = Mix.Project.project_file()
    changelog_file = Path.join(File.cwd!(), "CHANGELOG.md")
    section = VersionBump.changelog_section(next, Date.utc_today(), commits)

    with {:ok, mix_source} <- VersionBump.put_version(File.read!(mix_file), next),
         {:ok, changelog} <- VersionBump.put_changelog(read_or_empty(changelog_file), section) do
      File.write!(mix_file, mix_source)
      File.write!(changelog_file, changelog)
      print_next_steps(next)
    else
      {:error, message} -> Mix.raise(message)
    end
  end

  defp read_or_empty(path) do
    case File.read(path) do
      {:ok, text} -> text
      {:error, :enoent} -> ""
    end
  end

  defp print_next_steps(next) do
    Mix.shell().info("""
    Updated mix.exs and CHANGELOG.md to #{next}. Review with git diff, then:

      git commit -am "Chore: bump version to v#{next}"
      # once merged to main branch
      git tag v#{next} && git push origin v#{next}
    """)
  end
end
