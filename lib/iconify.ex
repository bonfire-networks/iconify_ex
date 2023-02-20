defmodule Iconify do
  use Phoenix.Component
  import Phoenix.LiveView.HTMLEngine
  require Logger

  # this is executed at compile time
  @cwd File.cwd!()

  def iconify(assigns) do
    component(
      &prepare_icon_component(Map.fetch!(assigns, :icon)).render/1,
      assigns,
      {__ENV__.module, __ENV__.function, __ENV__.file, __ENV__.line}
    )
  end

  def path, do: Application.get_env(:iconify_ex, :generated_icon_modules_path, "./lib/web/icons")

  defp prepare_icon_component(icon \\ "heroicons-solid:question-mark-circle")

  defp prepare_icon_component(icon) when is_binary(icon) do
    with [family_name, icon_name] <- family_and_icon(icon) do
      icon_name = String.trim_trailing(icon_name, "-icon")
      component_path = "#{path()}/#{family_name}"
      component_filepath = "#{component_path}/#{icon_name}.ex"
      module_name = module_name(family_name, icon_name)

      module_atom =
        "Elixir.#{module_name}"
        |> String.to_atom()

      # |> IO.inspect(label: "module_atom")

      if not Code.ensure_loaded?(module_atom) do
        if not File.exists?(component_filepath) do
          json_path =
            "#{@cwd}/assets/node_modules/@iconify/json/json/#{family_name}.json"
            |> IO.inspect(label: "load JSON for #{icon}")

          component_content = build_component(module_name, svg(json_path, icon_name))

          File.mkdir_p(component_path)
          File.write!(component_filepath, component_content)
        end

        Code.compile_file(component_filepath)
      end

      module_atom
    else
      _ ->
        icon_error(icon, "Could not process family_and_icon")
    end
  catch
    fallback_module when is_atom(fallback_module) -> fallback_module
    other -> raise other
  end

  defp prepare_icon_component(icon) when is_atom(icon) do
    if Code.ensure_loaded?(icon) do
      icon
    else
      icon_error(
        icon,
        "No component module is available in your app for this icon: `#{inspect(icon)}`. Using the binary icon name instead would allow it to be generated from Iconify. Find icon names at https://icones.js.org"
      )
    end
  catch
    fallback_module when is_atom(fallback_module) -> fallback_module
    other -> raise other
  end

  defp prepare_icon_component(icon) do
    icon_error(
      icon,
      "Expected a binary icon name or an icon component module atom, got `#{inspect(icon)}`"
    )
  catch
    fallback_module when is_atom(fallback_module) -> fallback_module
    other -> raise other
  end

  defp svg(json_path, icon_name) do
    {svg, w, h} = get_svg(json_path, icon_name)

    "<svg data-icon=\"#{icon_name}\" xmlns=\"http://www.w3.org/2000/svg\" aria-hidden=\"true\" role=\"img\" class={@class} viewBox=\"0 0 #{w} #{h}\" aria-hidden=\"true\">#{clean_svg(svg, icon_name)}</svg>"
  end

  defp clean_svg(svg, icon_name \\ nil) do
    with {:ok, svg} <- Floki.parse_fragment(svg) do
      Floki.traverse_and_update(svg, fn
        {tag, attrs, children} ->
          # IO.inspect(attrs, label: "iconiify #{icon_name} tag")
          {tag, Keyword.drop(attrs, ["id"]), children}

        other ->
          # IO.inspect(other, label: "iconiify #{icon_name} other")
          other
      end)
      |> Floki.raw_html()
    else
      _ ->
        svg
    end
  end

  defp get_svg(json_filepath, icon_name) do
    case get_json(json_filepath, icon_name) do
      json when is_map(json) ->
        icons = Map.fetch!(json, "icons")

        if Map.has_key?(icons, icon_name) do
          icon = Map.fetch!(icons, icon_name)

          {Map.fetch!(icon, "body"), Map.get(icon, "width") || Map.get(json, "width") || 16,
           Map.get(icon, "height") || Map.get(json, "height") || 16}
        else
          icon_error(
            icon_name,
            "No icon named `#{icon_name}` found in this icon set. Icons available include: #{Enum.join(Map.keys(icons), ", ")}"
          )
        end
    end
  end

  defp get_json(json_filepath, icon_name) do
    with {:ok, data} <- File.read(json_filepath) do
      data
      |> Jason.decode!()
    else
      _ ->
        icon_error(
          icon_name,
          "No icon set found at `#{json_filepath}` for the icon `#{icon_name}`. Find icon sets at https://icones.js.org"
        )
    end
  end

  defp family_and_icon(name) do
    name
    |> String.split(":")
    |> Enum.map(&icon_name/1)
  end

  defp icon_name(name) do
    Recase.to_kebab(name)
  end

  defp module_name(family_name, icon_name) do
    "Iconify" <> module_section(family_name) <> module_section(icon_name)
  end

  defp module_section(name) do
    "." <>
      (name
       |> String.split("-")
       |> Enum.map(&String.capitalize/1)
       |> Enum.join("")
       |> module_sanitise())
  end

  defp module_sanitise(str) do
    if is_numeric(String.at(str, 0)) do
      "X" <> str
    else
      str
    end
  end

  defp is_numeric(str) do
    case Float.parse(str) do
      {_num, ""} -> true
      _ -> false
    end
  end

  defp build_component(module_name, svg) do
    # hint: the import makes sure icons are generated before icon modules are compiled
    """
    defmodule #{module_name} do
      @moduledoc false
      use Phoenix.Component
      def render(assigns) do
        ~H\"\"\"
        #{svg}
        \"\"\"
      end
    end
    """
  end

  defp icon_error(icon, msg) do
    if icon not in [
         "heroicons-solid:question-mark-circle",
         Iconify.HeroiconsSolid.QuestionMarkCircle
       ] do
      Logger.error(msg)
      throw(prepare_icon_component("heroicons-solid:question-mark-circle"))
    else
      throw(msg)
    end
  end
end
