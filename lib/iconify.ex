defmodule Iconify do
  use Phoenix.Component
  # import Phoenix.LiveView.TagEngine
  import Phoenix.LiveView.HTMLEngine
  require Logger

  # this is executed at compile time
  @cwd File.cwd!()

  def iconify(assigns) do
    icon = Map.fetch!(assigns, :icon)

    case mode() do
      :img ->
        src = prepare_icon_img(icon)

        component(
          &render_svg_with_img/1,
          assigns |> Enum.into(%{src: src}),
          {__ENV__.module, __ENV__.function, __ENV__.file, __ENV__.line}
        )

      :css ->
        icon_class = prepare_icon_css(icon)

        component(
          &render_svg_with_css/1,
          assigns |> Enum.into(%{icon_class: icon_class}),
          {__ENV__.module, __ENV__.function, __ENV__.file, __ENV__.line}
        )

      # :inline by default
      _ ->
        component(
          &prepare_icon_component(icon).render/1,
          assigns,
          {__ENV__.module, __ENV__.function, __ENV__.file, __ENV__.line}
        )
    end
  end

  def dev_env?, do: Code.ensure_loaded?(Mix)
  def path, do: Application.get_env(:iconify_ex, :generated_icon_modules_path, "./lib/web/icons")

  def static_path,
    do:
      Application.get_env(
        :iconify_ex,
        :generated_icon_static_path,
        "./assets/static/images/icons"
      )

  def static_url, do: Application.get_env(:iconify_ex, :generated_icon_static_url, "")

  def mode, do: Application.get_env(:iconify_ex, :mode, false)

  defp prepare_icon_img(icon) do
    with [family_name, icon_name] <- family_and_icon(icon) do
      icon_name = String.trim_trailing(icon_name, "-icon")

      if dev_env?() do
        do_prepare_icon_img(family_name, icon_name)
      end

      "#{static_url()}/#{family_name}/#{icon_name}.svg"
    else
      _ ->
        icon_error(icon, "Could not process family_and_icon")
    end
  catch
    fallback_module when is_atom(fallback_module) -> fallback_module
    other -> raise other
  end

  defp do_prepare_icon_img(family_name, icon_name) do
    path = "#{static_path()}/#{family_name}"
    src = "#{path}/#{icon_name}.svg"

    if not File.exists?(src) do
      json_path = json_path(family_name)

      svg = svg(json_path, icon_name)
      # |> IO.inspect()

      File.mkdir_p(path)
      File.write!(src, svg)
    end
  end

  defp prepare_icon_component(icon \\ "heroicons-solid:question-mark-circle")

  defp prepare_icon_component(icon) when is_binary(icon) do
    with [family_name, icon_name] <- family_and_icon(icon) do
      do_prepare_icon_component(family_name, icon_name)
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

  defp do_prepare_icon_component(family_name, icon_name) do
    icon_name = String.trim_trailing(icon_name, "-icon")
    component_path = "#{path()}/#{family_name}"
    component_filepath = "#{component_path}/#{icon_name}.ex"
    module_name = module_name(family_name, icon_name)

    module_atom =
      "Elixir.#{module_name}"
      |> String.to_atom()

    # |> IO.inspect(label: "module_atom")

    if not Code.ensure_loaded?(module_atom) do
      if dev_env?() do
        if not File.exists?(component_filepath) do
          json_path = json_path(family_name)

          component_content =
            build_component(module_name, svg_for_component(json_path, icon_name))

          File.mkdir_p(component_path)
          File.write!(component_filepath, component_content)
        end

        Code.compile_file(component_filepath)
      else
        icon_error(icon_name, "Icon module not found")
      end
    end

    module_atom
  catch
    fallback_module when is_atom(fallback_module) -> fallback_module
    other -> raise other
  end

  def list_components do
    with {:ok, modules} <-
           :application.get_key(
             Application.get_env(:iconify_ex, :generated_icon_app, :bonfire),
             :modules
           ) do
      modules
      |> Enum.filter(&String.starts_with?("#{&1}", "Elixir.Iconify"))
      |> Enum.group_by(fn mod ->
        String.split("#{mod}", ".", parts: 4)
        |> Enum.at(2)
      end)
    end
  end

  defp prepare_icon_css(icon) do
    with [family_name, icon_name] <- family_and_icon(icon) do
      icon_name = String.trim_trailing(icon_name, "-icon")

      icon_class = class_name(family_name, icon_name)

      if dev_env?() do
        do_prepare_icon_css(family_name, icon_name, icon_class)
      end

      icon_class
    else
      _ ->
        icon_error(icon, "Could not process family_and_icon")
    end
  catch
    fallback_module when is_atom(fallback_module) -> fallback_module
    other -> raise other
  end

  defp do_prepare_icon_css(family_name, icon_name, icon_class) do
    icons_dir = static_path()
    css_path = "#{icons_dir}/icons.css"

    with {:ok, file} <- File.open(css_path, [:read, :append, :utf8]) do
      if !exists_in_css?(file, icon_class) do
        json_path = json_path(family_name)

        svg = svg(json_path, icon_name)
        # |> IO.inspect()

        css = css_svg(icon_class, svg)
        # |> IO.inspect()

        append_css(file, css)
      end
    end
  end

  defp svg(json_path, icon_name) do
    {svg, w, h} = get_svg(json_path, icon_name)

    "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 #{w} #{h}\">#{clean_svg(svg, icon_name)}</svg>"
  end

  defp svg_for_component(json_path, icon_name) do
    {svg, w, h} = get_svg(json_path, icon_name)

    "<svg data-icon=\"#{icon_name}\" xmlns=\"http://www.w3.org/2000/svg\" role=\"img\" class={@class} viewBox=\"0 0 #{w} #{h}\" aria-hidden=\"true\">#{clean_svg(svg, icon_name)}</svg>"
  end

  defp clean_svg(svg, _icon_name \\ nil) do
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

  def generate_css_from_static_files() do
    icons_dir = static_path()

    icons =
      File.ls!(icons_dir)
      |> Enum.flat_map(fn dir ->
        path = Path.join(icons_dir, dir)

        File.ls!(path)
        |> Enum.map(fn file ->
          {"#{dir}:#{Path.basename(file, ".svg")}", Path.join(path, file)}
        end)
      end)
      |> IO.inspect()

    css =
      Enum.map(icons, fn {name, full_path} ->
        css_svg(name, File.read!(full_path))
      end)
      |> IO.inspect()

    write_css(icons_dir, css)
  end

  def generate_css_from_components() do
    icons =
      list_components()
      |> Enum.flat_map(fn {family, mods} ->
        mods
        |> Enum.map(fn mod ->
          icon =
            String.split("#{mod}", ".")
            |> List.last()

          {class_name(icon_name(family), icon_name(icon)), mod}
        end)
      end)

    css =
      Enum.map(icons, fn {name, mod} ->
        css_svg(
          name,
          mod.render([])
          |> Map.get(:static, [])
          |> Enum.join("")
          |> String.replace("aria-hidden=\"true\"", "")
          |> String.replace("class=\"\"", "")
        )
      end)
      |> IO.inspect()

    write_css(css)
  end

  defp write_css(icons_dir \\ static_path(), css) do
    File.write!("#{icons_dir}/icons.css", Enum.join(css, "\n"))
  end

  defp maybe_append_css(file_or_icons_dir \\ static_path(), icon_class, css)

  defp maybe_append_css(icons_dir, icon_class, css) when is_binary(icons_dir) do
    css_path = "#{icons_dir}/icons.css"

    with {:ok, file} <- File.open(css_path, [:read, :append, :utf8]) do
      maybe_append_css(file, icon_class, css)
    end
  end

  defp maybe_append_css(file, icon_class, css) do
    # TODO: optimise by reading line by line
    if String.contains?(IO.read(file, :all), icon_class) do
      :ok
    else
      append_css(file, css)
    end
  end

  defp append_css(file, css) when is_list(css) do
    append_css(file, Enum.join(css, "\n"))
  end

  defp append_css(file, css) when is_binary(css) do
    IO.write(file, "\n#{css}")
  end

  defp exists_in_css?(file_or_icons_dir \\ static_path(), icon_class)

  defp exists_in_css?(icons_dir, icon_class) when is_binary(icons_dir) do
    css_path = "#{icons_dir}/icons.css"

    with {:ok, file} <- File.open(css_path, [:read]) do
      exists_in_css?(file, icon_class)
    else
      e ->
        IO.warn(e)
        false
    end
  end

  defp exists_in_css?(file, icon_class) do
    # TODO: optimise by reading line by line
    if String.contains?(IO.read(file, :all), icon_class) do
      true
    end
  end

  defp json_path(family_name),
    do:
      "#{@cwd}/assets/node_modules/@iconify/json/json/#{family_name}.json"
      |> IO.inspect(label: "load JSON for #{family_name} icon family")

  defp css_svg(class_name, svg) do
    ".#{class_name}{content:url(\"data:image/svg+xml;utf8,#{svg |> String.split() |> Enum.join(" ") |> URI.encode(&URI.char_unescaped?(&1)) |> String.replace("%20", " ") |> String.replace("%22", "'")}\")}"
  end

  defp class_name(family, icon), do: "iconify_#{family}_#{icon}"

  defp family_and_icon(name) do
    name
    |> String.split(":")
    |> Enum.map(&icon_name/1)
  end

  defp icon_name(name) do
    Recase.to_kebab(name)
  end

  def render_svg_with_img(assigns) do
    ~H"""
    <img src={@src} class={@class} onload="SVGInject(this)" aria-hidden="true" />
    """
  end

  def render_svg_with_css(assigns) do
    ~H"""
    <div class={"#{@icon_class} #{@class}"} aria-hidden="true" />
    """
  end
end
