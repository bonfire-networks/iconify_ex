defmodule Iconify.CacheTest do
  # global call tracing and app env
  use ExUnit.Case, async: false

  @moduletag :iconify_cache

  setup do
    tmp = Path.join(System.tmp_dir!(), "iconify_cache_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp)

    old_static = Application.get_env(:iconify_ex, :generated_icon_static_path)
    old_variants = Application.get_env(:iconify_ex, :weight_variants)

    Application.put_env(:iconify_ex, :generated_icon_static_path, tmp)
    Application.put_env(:iconify_ex, :weight_variants, %{"ph" => ["fill"]})

    on_exit(fn ->
      :erlang.trace(:new_processes, false, [:call])
      :erlang.trace_pattern({Jason, :decode!, 1}, false, [:global])
      :erlang.trace_pattern({File, :read, 1}, false, [:global])

      restore_env(:generated_icon_static_path, old_static)
      restore_env(:weight_variants, old_variants)
      File.rm_rf!(tmp)
    end)

    {:ok, tmp: tmp}
  end

  test "an icon set is decoded at most once per VM, across processes" do
    trace_calls({Jason, :decode!, 1})

    prepare_variant_in_own_process("gear")
    prepare_variant_in_own_process("bell")

    decodes =
      collect_calls(Jason, :decode!)
      |> Enum.count(fn [data] -> is_binary(data) and byte_size(data) > 1_000_000 end)

    assert decodes <= 1
  end

  test "the per-icon weight memo outlives the process that wrote it", %{tmp: tmp} do
    prepare_variant_in_own_process("house")

    trace_calls({File, :read, 1})

    prepare_variant_in_own_process("house")

    variant_css = Path.join(tmp, "icons-fill.css")

    reads =
      collect_calls(File, :read)
      |> Enum.count(fn [path] -> Path.expand(to_string(path)) == Path.expand(variant_css) end)

    assert reads == 0
  end

  test "a css-mode render doesn't re-read icons.css for an icon already prepared in another process",
       %{tmp: tmp} do
    render_css_icon_in_own_process("ph:acorn")

    trace_calls({File, :read, 1})

    render_css_icon_in_own_process("ph:acorn")

    icons_css = Path.join(tmp, "icons.css")

    reads =
      collect_calls(File, :read)
      |> Enum.count(fn [path] -> Path.expand(to_string(path)) == Path.expand(icons_css) end)

    assert reads == 0
  end

  defp render_css_icon_in_own_process(icon) do
    Task.async(fn -> Iconify.prepare(icon, :css) end)
    |> Task.await(30_000)
  end

  defp prepare_variant_in_own_process(icon) do
    Task.async(fn -> Iconify.prepare_icon_weight_variants("ph", icon, "ph:#{icon}") end)
    |> Task.await(30_000)
  end

  defp trace_calls({mod, _, _} = mfa) do
    # trace_pattern silently matches nothing for a module that isn't loaded yet
    Code.ensure_loaded!(mod)
    assert :erlang.trace_pattern(mfa, true, [:global]) == 1

    :erlang.trace(:new_processes, true, [:call, {:tracer, self()}])
  end

  defp collect_calls(mod, fun, acc \\ []) do
    receive do
      {:trace, _pid, :call, {^mod, ^fun, args}} -> collect_calls(mod, fun, [args | acc])
    after
      100 -> acc
    end
  end

  defp restore_env(key, nil), do: Application.delete_env(:iconify_ex, key)
  defp restore_env(key, value), do: Application.put_env(:iconify_ex, key, value)
end
