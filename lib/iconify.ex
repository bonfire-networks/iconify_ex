defmodule Iconify do
  use Phoenix.Component
  use Arrows
  import Phoenix.LiveView.TagEngine
  # import Phoenix.LiveView.HTMLEngine
  require Logger

  # this is executed at compile time
  @cwd File.cwd!()

  def iconify(assigns) do
    with {_, fun, assigns} <- prepare(assigns, assigns[:mode]) do
      component(
        fun,
        assigns,
        {__ENV__.module, __ENV__.function, __ENV__.file, __ENV__.line}
      )
    end
  end

  def prepare(assigns, mode \\ nil) do
    icon = Map.fetch!(assigns, :icon)

    case mode || mode(emoji?(icon)) do
      :img_url ->
        {:img, maybe_prepare_icon_img(icon)}

      :img ->
        src = prepare_icon_img(icon)

        {:img, &render_svg_with_img/1, assigns |> Enum.into(%{src: src})}

      :inline ->
        {:inline, &prepare_icon_component(icon).render/1, assigns}

      :data ->
        {:data, prepare_icon_data(icon)}

      _ ->
        # :css by default
        icon_name = prepare_icon_css(icon)

        {:css, &render_svg_with_css/1, assigns |> Enum.into(%{icon_name: icon_name})}
    end
  end

  def manual(icon, opts \\ nil) do
    assigns = Map.put(opts[:assigns] || %{}, :icon, icon)
    mode = opts[:mode]

    case prepare(assigns, opts[:mode]) do
      {_, fun, assigns} when is_function(fun) ->
        fun.(assigns)

      {_, other} ->
        other
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

  defp mode(true), do: :img
  defp mode(_), do: Application.get_env(:iconify_ex, :mode, false)
  def using_svg_inject?, do: Application.get_env(:iconify_ex, :using_svg_inject, false)
  # def css_class, do: Application.get_env(:iconify_ex, :css_class, "iconify_icon")

  def emoji?(icon),
    do:
      String.starts_with?(to_string(icon), [
        "emoji",
        "noto",
        "openmoji",
        "twemoji",
        "fluent-emoji",
        "fxemoji",
        "streamline-emoji"
      ])

  defp prepare_icon_img(icon) do
    with img when is_binary(img) <- maybe_prepare_icon_img(icon) do
      img
    else
      _ ->
        icon_error(icon, "Could not process family_and_icon")
    end
  catch
    {:fallback, fallback_icon} when is_binary(fallback_icon) -> prepare_icon_img(fallback_icon)
    other -> raise other
  end

  defp maybe_prepare_icon_img(icon) do
    with [family_name, icon_name] <- family_and_icon(icon) do
      icon_name = String.trim_trailing(icon_name, "-icon")

      if dev_env?() do
        do_prepare_icon_img(family_name, icon_name)
      end

      "#{static_url()}/#{family_name}/#{icon_name}.svg"
    else
      _ ->
        nil
    end
  end

  defp do_prepare_icon_img(family_name, icon_name) do
    path = "#{static_path()}/#{family_name}"
    src = "#{path}/#{icon_name}.svg"

    if not File.exists?(src) do
      IO.inspect(src, label: "Iconify new icon found")

      json_path = json_path(family_name)

      svg = svg(json_path, icon_name)
      # |> IO.inspect()

      File.mkdir_p(path)
      File.write!(src, svg)

      IO.inspect(src, label: "Iconify icon added")
    else
      IO.inspect(src, label: "Iconify icon already exists")
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
    {:fallback, fallback_icon} when is_binary(fallback_icon) ->
      prepare_icon_component(fallback_icon)

    other ->
      raise other
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
    {:fallback, fallback_icon} when is_binary(fallback_icon) ->
      prepare_icon_component(fallback_icon)

    other ->
      raise other
  end

  defp prepare_icon_component(icon) do
    icon_error(
      icon,
      "Expected a binary icon name or an icon component module atom, got `#{inspect(icon)}`"
    )
  catch
    {:fallback, fallback_icon} when is_binary(fallback_icon) ->
      prepare_icon_component(fallback_icon)

    other ->
      raise other
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
    {:fallback, fallback_icon} when is_binary(fallback_icon) ->
      prepare_icon_component(fallback_icon)

    other ->
      raise other
  end

  def create_component_for_svg(family_name, icon_name, svg_code) do
    icon_name = String.trim_trailing(icon_name, "-icon")
    component_path = "#{path()}/#{family_name}"
    component_filepath = "#{component_path}/#{icon_name}.ex"
    module_name = module_name(family_name, icon_name)

    module_atom =
      "Elixir.#{module_name}"
      |> String.to_atom()

    # |> IO.inspect(label: "module_atom")

    component_content = build_component(module_name, full_svg_for_component(svg_code, icon_name))

    File.mkdir_p(component_path)
    File.write!(component_filepath, component_content)

    Code.compile_file(component_filepath)

    module_atom
  catch
    {:fallback, fallback_icon} when is_binary(fallback_icon) ->
      prepare_icon_component(fallback_icon)

    other ->
      raise other
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

  defp prepare_icon_data(icon) do
    with [family_name, icon_name] <- family_and_icon(icon) do
      icon_name = String.trim_trailing(icon_name, "-icon")

      icon_css_name = css_icon_name(family_name, icon_name)

      do_prepare_icon_data(family_name, icon_name, icon_css_name)
    else
      _ ->
        icon_error(icon, "Could not process family_and_icon")
    end
  catch
    {:fallback, fallback_icon} when is_binary(fallback_icon) -> nil
    other -> raise other
  end

  defp do_prepare_icon_data(family_name, icon_name, icon_css_name) do
    icons_dir = static_path()
    css_path = "#{icons_dir}/icons.css"

    with {:ok, file} <- file_open(css_path, [:read, :utf8]) do
      case extract_from_css_file(css_path, file, icon_css_name) do
        nil ->
          if dev_env?(), do: do_prepare_icon_css(family_name, icon_name, icon_css_name)

        svg_data ->
          svg_data
      end
    end
  end

  defp prepare_icon_css(icon) do
    with [family_name, icon_name] <- family_and_icon(icon) do
      icon_name = String.trim_trailing(icon_name, "-icon")

      icon_css_name = css_icon_name(family_name, icon_name)

      if dev_env?() do
        do_prepare_icon_css(family_name, icon_name, icon_css_name)
      end

      icon_css_name
    else
      _ ->
        icon_error(icon, "Could not process family_and_icon")
    end
  catch
    {:fallback, fallback_icon} when is_binary(fallback_icon) -> prepare_icon_css(fallback_icon)
    other -> raise other
  end

  defp do_prepare_icon_css(family_name, icon_name, icon_css_name) do
    icons_dir = static_path()
    css_path = "#{icons_dir}/icons.css"

    with {:ok, file} <- file_open(css_path, [:read, :append, :utf8]) do
      if !exists_in_css_file?(css_path, file, icon_css_name) do
        json_path = json_path(family_name)

        svg = svg(json_path, icon_name)
        # |> IO.inspect()

        data_svg = data_svg(svg)

        css = css_with_data_svg(icon_css_name, data_svg)
        # |> IO.inspect()

        append_css(file, css)

        data_svg
      end
    end
  end

  def add_icon_to_css(icon_css_name, svg_code) do
    icons_dir = static_path()
    css_path = "#{icons_dir}/icons.css"

    with {:ok, file} <- file_open(css_path, [:read, :append, :utf8]) do
      if !exists_in_css_file?(css_path, file, icon_css_name) do
        css = css_svg(icon_css_name, clean_svg(svg_code))
        # |> IO.inspect()

        append_css(file, css)
      end
    end
  end

  defp file_open(path, args) do
    # TODO: put args in key?
    key = "iconify_ex_file_#{path}_#{inspect(args)}"

    case Process.get(key) do
      nil ->
        # Logger.debug("open #{path}")

        with {:ok, file} <- File.open(path, args) do
          Process.put(key, file)
          {:ok, file}
        end

      io_device ->
        # Logger.debug("use available #{path}")
        {:ok, io_device}
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

  defp full_svg_for_component(svg_code, icon_name) do
    String.replace(
      clean_svg(svg_code, icon_name),
      "<svg",
      "<svg data-icon=\"#{icon_name}\" class={@class}"
    )
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
            "No icon named `#{icon_name}` found in icon set #{json_filepath} - Icons available include: #{Enum.join(Map.keys(icons), ", ")}"
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
         "question-mark-circle",
         "heroicons-solid:question-mark-circle",
         Iconify.HeroiconsSolid.QuestionMarkCircle
       ] do
      Logger.error(msg)
      Logger.info(icon)
      throw({:fallback, "heroicons-solid:question-mark-circle"})
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

        if File.regular?(path),
          do: [],
          else:
            File.ls!(path)
            |> Enum.map(fn file ->
              {css_icon_name(dir, Path.basename(file, ".svg")), Path.join(path, file)}
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

          {css_icon_name(icon_name(family), icon_name(icon)), mod}
        end)
      end)

    css =
      Enum.map(icons, fn {class_name, mod} ->
        css_svg(
          class_name,
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
    File.write!("#{icons_dir}/icons.css", Enum.join(css, "\n") <> "\n")
  end

  defp maybe_append_css(file_or_icons_dir \\ static_path(), icon_css_name, css)

  defp maybe_append_css(icons_dir, icon_css_name, css) when is_binary(icons_dir) do
    css_path = "#{icons_dir}/icons.css"

    with {:ok, file} <- File.open(css_path, [:read, :append, :utf8]) do
      maybe_append_css(file, icon_css_name, css)
    end
  end

  defp maybe_append_css(file, icon_css_name, css) do
    # TODO: optimise by reading line by line
    if String.contains?(IO.read(file, :all), "\"#{icon_css_name}\"") do
      :ok
    else
      append_css(file, css)
    end
  end

  defp append_css(file, css) when is_list(css) do
    append_css(file, Enum.join(css, "\n"))
  end

  defp append_css(file, css) when is_binary(css) do
    IO.write(file, "#{css}\n")
  end

  defp exists_in_css?(file_or_icons_dir \\ static_path(), icon_css_name)

  defp exists_in_css?(icons_dir, icon_css_name) when is_binary(icons_dir) do
    css_path = "#{icons_dir}/icons.css"

    with {:ok, file} <- File.open(css_path, [:read]) do
      exists_in_css_file?(css_path, file, icon_css_name)
    else
      e ->
        IO.warn(e)
        false
    end
  end

  defp read_css_file(css_path, file) do
    key = "iconify_ex_contents_#{css_path}"

    case Process.get(key) do
      nil ->
        # Logger.debug("read #{path}")
        contents = IO.read(file, :all)
        Process.put(key, contents)
        contents

      contents ->
        # Logger.debug("use cached #{path}")
        contents
    end
  end

  defp exists_in_css_file?(css_path, file, icon_css_name) do
    read_css_file(css_path, file)
    |> String.contains?("\"#{icon_css_name}\"")
  end

  defp extract_from_css_file(css_path, file, icon_css_name) do
    text = read_css_file(css_path, file)

    Regex.run(
      ~r/\[iconify="#{icon_css_name}"]{--Iy:url\("data:image\/svg\+xml;utf8,([^"]+)/,
      text,
      capture: :first
    )
  end

  defp json_path(family_name),
    do:
      "#{@cwd}/assets/node_modules/@iconify/json/json/#{family_name}.json"
      |> IO.inspect(label: "load JSON for #{family_name} icon family")

  defp css_svg(icon_name, svg) do
    css_with_data_svg(icon_name, data_svg(svg))
  end

  defp css_with_data_svg(icon_name, data_svg) do
    "[iconify=\"#{icon_name}\"]{--Iy:url(\"data:image/svg+xml;utf8,#{data_svg}\");-webkit-mask-image:var(--Iy);mask-image:var(--Iy)}"
  end

  defp data_svg(svg) do
    svg
    |> String.split()
    |> Enum.join(" ")
    |> URI.encode(&URI.char_unescaped?(&1))
    |> String.replace("%20", " ")
    |> String.replace("%22", "'")
  end

  defp css_icon_name(family, icon), do: "#{family}:#{icon}"

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
    <img
      src={@src}
      class={@class}
      onload={if using_svg_inject?(), do: "SVGInject(this)"}
      aria-hidden="true"
    />
    """
  end

  def render_svg_with_css(assigns) do
    ~H"""
    <div iconify={@icon_name} class={@class} aria-hidden="true" />
    """

    # <div class={"#{css_class()} #{@class}"} style={"-webkit-mask: var(--#{@icon_name}); mask: var(--#{@icon_name})"} aria-hidden="true" />
  end

  # def render_svg_with_css(assigns) do
  #   ~H"""
  #   <div class={"#{@icon_name} #{@class}"} aria-hidden="true" />
  #   """
  # end

  def maybe_set_favicon(socket, "<svg" <> _ = icon) do
    socket
    |> data_image_svg()
    |> Phx.Live.Favicon.set_dynamic("svg", icon)
  end

  def maybe_set_favicon(socket, icon) when is_binary(icon) do
    if String.contains?(icon, ":") do
      if Iconify.emoji?(icon) do
        maybe_set_favicon_emoji(socket, icon)
      else
        IO.inspect(icon, label: "not emojiii")
        do_set_favicon_iconify(socket, icon)
      end
    else
      IO.inspect(icon, label: "a manual emojiii or other text")
      do_set_favicon_text(socket, icon)
    end
  end

  def maybe_set_favicon(socket, _icon) do
    socket
    |> Phx.Live.Favicon.reset()
  end

  defp maybe_set_favicon_emoji(socket, icon) do
    case Iconify.manual(icon, mode: :img_url) do
      img when is_binary(img) ->
        img
        |> IO.inspect(label: "use emojiii from URL")
        |> Phx.Live.Favicon.set_dynamic(socket, "svg", ...)

      _ ->
        case Code.ensure_loaded?(Emote) and
               String.split(icon, ":", parts: 2)
               |> List.last()
               |> Recase.to_snake()
               |> Emote.lookup() do
          emoji when is_binary(emoji) ->
            IO.inspect(emoji, label: "emojiii in emote")
            do_set_favicon_text(socket, emoji)

          _ ->
            IO.inspect(icon, label: "no such emojiii")

            socket
            |> Phx.Live.Favicon.reset()
        end
    end
  end

  defp do_set_favicon_text(socket, text) do
    "<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 100 100%22><text y=%22.9em%22 font-size=%2290%22>#{text}</text></svg>"
    |> data_image_svg()
    |> Phx.Live.Favicon.set_dynamic(socket, "svg", ...)
  end

  defp do_set_favicon_iconify(socket, icon) do
    Iconify.manual(icon, mode: :data)
    |> IO.inspect(label: "iconify - not emojiii")
    |> data_image_svg()
    |> Phx.Live.Favicon.set_dynamic(socket, "svg", ...)
  end

  defp data_image_svg(svg), do: "data:image/svg+xml;utf8,#{svg}"

  # defp do_set_favicon_text(socket, icon) do
  # TODO
  #   <link rel="icon" href="data:image/svg+xml,&lt;svg viewBox=%220 0 100 100%22 xmlns=%22http://www.w3.org/2000/svg%22&gt;&lt;text y=%22.9em%22 font-size=%2290%22&gt;⏰&lt;/text&gt;&lt;rect x=%2260.375%22 y=%2238.53125%22 width=%2239.625%22 height=%2275.28125%22 rx=%226.25%22 ry=%226.25%22 style=%22fill: red;%22&gt;&lt;/rect&gt;&lt;text x=%2293.75%22 y=%2293.75%22 font-size=%2260%22 text-anchor=%22end%22 alignment-baseline=%22text-bottom%22 fill=%22white%22 style=%22font-weight: 400;%22&gt;1&lt;/text&gt;&lt;/svg&gt;">
  # end
end
