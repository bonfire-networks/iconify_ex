defmodule Iconify do
  use Phoenix.Component

  @cwd File.cwd! # this is executed at compile time

  def iconify(assigns) do
    component(&prepare_icon_component(Map.fetch!(assigns, :icon)).render/1, assigns)
  end

  defp prepare_icon_component(icon \\ "heroicons-solid:question-mark-circle") do
    if icon do
      [family_name, icon_name] = family_and_icon(icon)
      icon_name = String.trim_trailing(icon_name, "-icon") # temporary
      component_path = "./lib/web/icons/#{family_name}"
      component_filepath = "#{component_path}/#{icon_name}.ex"
      module_name = module_name(family_name, icon_name)
      |> String.to_atom()

      if not Code.ensure_loaded?(module_name) or not File.exists?(component_filepath) do
        src_path = "#{@cwd}/assets/node_modules/@iconify/json/json/#{family_name}.json"

      svg_content =
          "<svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" aria-hidden=\"true\" role=\"img\" class={@class} viewBox=\"0 0 20 20\" aria-hidden=\"true\">#{get_svg(src_path, icon_name)}</svg>"

        component_content = build_component(module_name, svg_content)

        File.mkdir_p(component_path)
        File.write!(component_filepath, component_content)
        Code.compile_file(component_filepath)
      end

      "Elixir.#{module_name}"
      |> String.to_atom()
    else
      throw "Expected an icon name, got `#{inspect icon}`"
    end
  end

  defp get_svg(json_filepath, icon_name) do
    icons = get_json(json_filepath)
    |> Map.fetch!("icons")

    if Map.has_key?(icons, icon_name) do
      icons
      |> Map.fetch!(icon_name)
      |> Map.fetch!("body")
    else
      throw "No icon named `#{icon_name}` found in this icon set. Icons available include: #{Enum.join(Map.keys(icons), ", ")}"
    end
  end

  defp get_json(json_filepath) do
    File.read!(json_filepath)
    |> Jason.decode!()
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
    "Iconify"<>module_section(family_name)<>module_section(icon_name)
  end

  defp module_section(name) do
    "."<>(name
    |> String.split("-")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join("")
    |> module_sanitise())
  end

  defp module_sanitise(str) do
    if is_numeric(String.at(str,0)) do
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
      use Phoenix.Component
      def render(assigns) do
        ~H\"\"\"
        #{svg}
        \"\"\"
      end
    end
    """
  end
end
