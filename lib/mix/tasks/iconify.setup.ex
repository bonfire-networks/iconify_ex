defmodule Mix.Tasks.Iconify.Setup do
  @moduledoc """
  Installs the Iconify icon sets required by iconify_ex.

  This task downloads the @iconify/json npm package which contains
  all available icon sets (100,000+ icons from 100+ icon sets).

  ## Usage

      $ mix iconify.setup

  ## Options

      * `--if-missing` - only install if icon sets are not already present
      * `--path` - custom path to install (default: deps/iconify_ex/assets)

  ## When to run

  Run this task after `mix deps.get` to ensure icon sets are available:

      $ mix deps.get
      $ mix iconify.setup

  Or add it to your setup alias in mix.exs:

      defp aliases do
        [
          setup: ["deps.get", "iconify.setup", "ecto.setup", ...]
        ]
      end

  """

  @shortdoc "Installs Iconify icon sets"

  use Mix.Task

  @impl true
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [if_missing: :boolean, path: :string])

    assets_path = opts[:path] || find_assets_path()

    if opts[:if_missing] && icon_sets_installed?(assets_path) do
      Mix.shell().info("Iconify icon sets already installed.")
      :ok
    else
      install_icon_sets(assets_path)
    end
  end

  @doc """
  Checks if the Iconify icon sets are installed at the given path.
  """
  def icon_sets_installed?(assets_path \\ nil) do
    path = assets_path || find_assets_path()
    json_path = Path.join([path, "node_modules", "@iconify", "json", "json"])
    File.dir?(json_path)
  end

  @doc """
  Returns the path to a specific icon set JSON file, or nil if not found.
  """
  def icon_set_path(family_name, assets_path \\ nil) do
    path = assets_path || find_assets_path()
    json_path = Path.join([path, "node_modules", "@iconify", "json", "json", "#{family_name}.json"])

    if File.exists?(json_path) do
      json_path
    else
      nil
    end
  end

  defp find_assets_path do
    # Try to find iconify_ex in deps
    cond do
      # Running from within iconify_ex itself (development)
      File.exists?("assets/package.json") && iconify_package_json?("assets/package.json") ->
        "assets"

      # Running from a project that has iconify_ex as a dependency
      File.exists?("deps/iconify_ex/assets/package.json") ->
        "deps/iconify_ex/assets"

      # Fallback
      true ->
        "deps/iconify_ex/assets"
    end
  end

  defp iconify_package_json?(path) do
    case File.read(path) do
      {:ok, content} -> String.contains?(content, "@iconify/json")
      _ -> false
    end
  end

  defp install_icon_sets(assets_path) do
    unless File.exists?(Path.join(assets_path, "package.json")) do
      Mix.raise("""
      Could not find package.json at #{assets_path}.

      Make sure iconify_ex is installed as a dependency:

          mix deps.get
      """)
    end

    Mix.shell().info("Installing Iconify icon sets...")
    Mix.shell().info("Path: #{assets_path}")

    # Prefer yarn if available, fall back to npm
    {cmd, args} = detect_package_manager()

    case System.cmd(cmd, args, cd: assets_path, stderr_to_stdout: true) do
      {output, 0} ->
        Mix.shell().info(output)
        Mix.shell().info("Iconify icon sets installed successfully!")
        :ok

      {output, code} ->
        Mix.shell().error(output)

        Mix.raise("""
        Failed to install Iconify icon sets (exit code #{code}).

        Make sure you have npm or yarn installed and try running manually:

            cd #{assets_path} && #{cmd} #{Enum.join(args, " ")}
        """)
    end
  end

  defp detect_package_manager do
    cond do
      System.find_executable("yarn") -> {"yarn", ["install"]}
      System.find_executable("npm") -> {"npm", ["install"]}
      true -> Mix.raise("Neither yarn nor npm found. Please install one of them.")
    end
  end
end
