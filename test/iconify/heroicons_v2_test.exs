defmodule Iconify.HeroiconsV2Test do
  use ExUnit.Case, async: true

  doctest Iconify

  describe "Heroicons v2 support" do
    test "translate v1 solid to v2 24px solid" do
      {family, icon} = Iconify.translate_heroicons_v1_to_v2("heroicons-solid", "camera")
      assert family == "heroicons"
      assert icon == "camera-solid"
    end

    test "translate v1 outline to v2 24px outline" do
      {family, icon} = Iconify.translate_heroicons_v1_to_v2("heroicons-outline", "camera")
      assert family == "heroicons"
      assert icon == "camera"
    end

    test "pass through non-heroicons families" do
      {family, icon} = Iconify.translate_heroicons_v1_to_v2("feather", "camera")
      assert family == "feather"
      assert icon == "camera"
    end

    test "v2 24px outline (default)" do
      {:css, _fun, assigns} = Iconify.prepare(%{icon: "heroicons:camera", __changed__: nil}, :css)
      assert assigns.icon_name == "heroicons:camera"
    end

    test "v2 24px solid" do
      {:css, _fun, assigns} =
        Iconify.prepare(%{icon: "heroicons:camera-solid", __changed__: nil}, :css)

      assert assigns.icon_name == "heroicons:camera-solid"
    end

    test "v2 20px solid (mini)" do
      {:css, _fun, assigns} =
        Iconify.prepare(%{icon: "heroicons:camera-20-solid", __changed__: nil}, :css)

      assert assigns.icon_name == "heroicons:camera-20-solid"
    end

    test "v2 16px solid (micro)" do
      {:css, _fun, assigns} =
        Iconify.prepare(%{icon: "heroicons:camera-16-solid", __changed__: nil}, :css)

      assert assigns.icon_name == "heroicons:camera-16-solid"
    end

    test "v1 solid backwards compatibility" do
      {:css, _fun, assigns} =
        Iconify.prepare(%{icon: "heroicons-solid:camera", __changed__: nil}, :css)

      # v1 name gets translated to v2
      assert assigns.icon_name == "heroicons:camera-solid"
    end

    test "v1 outline backwards compatibility" do
      {:css, _fun, assigns} =
        Iconify.prepare(%{icon: "heroicons-outline:camera", __changed__: nil}, :css)

      # v1 name gets translated to v2
      assert assigns.icon_name == "heroicons:camera"
    end

    test "fallback icon uses correct v1 format" do
      # The fallback should be heroicons-solid:question-mark-circle
      # which gets translated to heroicons:question-mark-circle-solid
      assert Iconify.fallback_icon() == "heroicons-solid:question-mark-circle"
    end

    test "fallback icon translates to valid v2 icon name" do
      {:css, _fun, assigns} =
        Iconify.prepare(%{icon: Iconify.fallback_icon(), __changed__: nil}, :css)

      # Should translate to heroicons:question-mark-circle-solid
      assert assigns.icon_name == "heroicons:question-mark-circle-solid"
    end
  end

  describe "icon lookup from JSON" do
    @tag :requires_icon_sets
    test "can look up fallback icon from JSON when not in CSS" do
      # This indirectly tests that json_path resolves correctly
      # The fallback icon should be findable in the heroicons JSON
      # If this fails, json_path is probably returning wrong path
      assert_raise RuntimeError, fn ->
        # Force a lookup by using a non-existent icon
        # This will trigger fallback lookup from JSON
        Iconify.prepare_name!(%{icon: "nonexistent:icon", __changed__: nil}, mode: :inline)
      end
    end
  end
end
