defmodule Mix.Tasks.Iconify.WeightVariants do
  @shortdoc "Backfills weight-variant icon stylesheets (icons-<weight>.css)"

  @moduledoc """
  Generates the scoped weight-variant stylesheets for every icon already present in
  `icons.css`, according to the `config :iconify_ex, :weight_variants` map
  (e.g. `%{"ph" => ["thin", "duotone"]}` produces `icons-thin.css` and `icons-duotone.css`).

  Idempotent: only missing rules are appended, so it's safe to re-run. Newly used icons
  are kept in sync automatically when their module compiles; this task only backfills
  icons that were already prepared before the variant config existed. Delete the
  `icons-<weight>.css` files first to rebuild them from scratch.

      mix iconify.weight_variants
  """

  use Mix.Task

  @impl true
  def run(_argv) do
    Mix.Task.run("app.config")

    case Iconify.generate_weight_variant_css() do
      counts when is_map(counts) ->
        for {family, added} <- counts do
          Mix.shell().info("#{family}: #{added} variant rules added")
        end

      other ->
        Mix.raise("Could not generate weight variants: #{inspect(other)}")
    end
  end
end
