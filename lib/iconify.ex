defmodule Iconify do
  @moduledoc "./README.md" |> File.stream!() |> Enum.drop(1) |> Enum.join()

  use Phoenix.Component
  use Arrows
  use Untangle
  import Phoenix.LiveView.TagEngine
  # import Phoenix.LiveView.HTMLEngine

  # this is executed at compile time
  @cwd File.cwd!()

  @doc """
  Renders an icon as a `Phoenix.Component` based on the given assigns.

  ## Examples

      iex> assigns = %{icon: "heroicons:user-solid", class: "w-6 h-6", __changed__: nil}
      iex> Iconify.iconify(assigns) # Returns rendered icon HTML

      iex> assigns = %{icon: "heroicons-solid:user", class: "w-6 h-6", __changed__: nil}
      iex> Iconify.iconify(assigns) # Returns rendered icon HTML (v1 backwards compat)
  """
  def iconify(assigns) do
    with {_, fun, assigns} <- prepare(assigns, assigns[:mode]) do
      component(
        fun,
        assigns,
        {__ENV__.module, __ENV__.function, __ENV__.file, __ENV__.line}
      )
    end
  end

  @doc """
  Prepares an icon based on the given assigns and mode (such as CSS, inline SVG, or image URL).

  Heroicons v1 names (heroicons-solid:*, heroicons-outline:*) are automatically translated to v2 equivalents.

  ## Examples

      iex> {:css, _function, %{icon: "heroicons:user-solid", class: "w-4 h-4", icon_name: "heroicons:user-solid"}} = Iconify.prepare(%{icon: "heroicons:user-solid", __changed__: nil}, :css)

      iex> {:inline, _fun, %{icon: "heroicons:user-solid"}} = Iconify.prepare(%{icon: "heroicons:user-solid", __changed__: nil}, :inline)

      iex> {:img, _fun, %{src: "/images/icons/heroicons/user-solid.svg"}} = Iconify.prepare(%{icon: "heroicons:user-solid", __changed__: nil}, :img)

      iex> {:set, _fun, %{href: "/images/icons/heroicons.svg#user-solid"}} = Iconify.prepare(%{icon: "heroicons:user-solid", __changed__: nil}, :set)

      iex> {:img, _fun, %{src: "/images/icons/twemoji/rabbit.svg"}} = Iconify.prepare(%{icon: "twemoji:rabbit", __changed__: nil})

      iex> {:css, _fun, %{icon_name: "heroicons:question-mark-circle-solid"}} = Iconify.prepare(%{icon: "non-existent-icon", __changed__: nil})

       > Iconify.prepare(%{icon: "<svg>...</svg>", __changed__: nil})
      {:inline, _fun, %{icon: "<svg>...</svg>"}}

  """
  def prepare(assigns, opts \\ [])

  def prepare(assigns, opts) when is_map(assigns) and is_list(opts) do
    do_prepare(assigns, opts)
  catch
    {:fallback, "<svg " <> _ = fallback_icon} ->
      {:inline, &custom_svg_component/1, assign(assigns, :icon, fallback_icon)}

    {:fallback, fallback_icon} when is_binary(fallback_icon) ->
      prepare(assign(assigns, :icon, fallback_icon), opts)

    other ->
      raise other
  end

  def prepare(icon, opts) when is_binary(icon) do
    prepare(%{icon: icon, __changed__: nil}, opts)
  end

  def prepare(icon, mode) when is_atom(mode) do
    prepare(icon, mode: mode)
  end

  def prepare_name!(assigns, opts \\ [])

  def prepare_name!(assigns, opts) when is_map(assigns) and is_list(opts) do
    with {_, _, %{} = assigns} <- do_prepare(assigns, opts) do
      assigns[:icon_name] || assigns[:icon]
    else
      _other ->
        assigns[:icon]
    end
  catch
    {:fallback, _} ->
      raise "Iconify could not find icon: #{inspect(assigns[:icon])}"

    other ->
      error(other)
      raise "Iconify error with icon: #{inspect(assigns[:icon])}"
  end

  def prepare_name!(icon, opts) when is_binary(icon) do
    prepare_name!(%{icon: icon, __changed__: nil}, opts)
  end

  def prepare_name!(icon, mode) when is_atom(mode) do
    prepare_name!(icon, mode: mode)
  end

  defp do_prepare(assigns, opts) when is_map(assigns) and is_list(opts) do
    assigns =
      assign_new(assigns, :class, fn ->
        Application.get_env(:iconify_ex, :default_class, "w-4 h-4")
      end)

    icon = Map.fetch!(assigns, :icon)

    case opts[:mode] || mode(icon) do
      :set ->
        href = href_for_prepared_set_icon(icon, opts)

        {:set, &render_svg_for_sprite/1, assigns |> assign(:href, href)}

      :img_url ->
        maybe_prepare_icon_img(icon, opts)

      :img ->
        src = prepare_icon_img(icon, opts)

        {:img, &render_svg_with_img/1, assigns |> assign(:src, src)}

      :inline ->
        {:inline, &prepare_icon_component(icon, opts).render/1, assigns}

      :data ->
        {:data, prepare_icon_data(icon, opts)}

      _ ->
        # :css by default
        icon_name = prepare_icon_css(icon, opts)

        {:css, &render_svg_with_css/1, assigns |> assign(:icon_name, icon_name)}
    end
  end

  @doc """
  Prepares and renders an icon.

  ## Examples

      iex> %Phoenix.LiveView.Rendered{} = Iconify.manual("heroicons:user-solid", mode: :css) # Returns rendered icon HTML or data

  """
  def manual(icon, opts \\ nil) do
    # FIXME: won't work if assigns are not tracked LiveView assigns
    assigns = assign(opts[:assigns] || %{__changed__: nil}, :icon, icon)
    mode = opts[:mode]

    case prepare(assigns, opts[:mode]) do
      {_, fun, assigns} when is_function(fun) ->
        fun.(assigns)

      {_, other} ->
        other

      other ->
        other
    end
  end

  @doc """
  Returns the fallback icon name.

  ## Examples

      iex> Iconify.fallback_icon()
      "heroicons-solid:question-mark-circle"
  """
  def fallback_icon,
    do: Application.get_env(:iconify_ex, :fallback_icon, "heroicons-solid:question-mark-circle")

  if Mix.env() == :prod do
    def preparation_enabled? do
      env_config = Application.get_env(:iconify_ex, :env)

      cond do
        is_nil(env_config) and Code.ensure_loaded?(Mix) -> true
        env_config != :prod -> true
        true -> false
      end
    end
  else
    def preparation_enabled?, do: true
  end

  @doc """
  Returns the configured path for generated icon modules.

  ## Examples

      iex> Iconify.path()
      "./lib/web/icons"
  """
  def path, do: Application.get_env(:iconify_ex, :generated_icon_modules_path, "./lib/web/icons")

  @doc """
  Returns the configured path for generated static icon assets.

  ## Examples

      iex> Iconify.static_path()
      "./priv/static/images/icons"
  """
  def static_path,
    do:
      Application.get_env(
        :iconify_ex,
        :generated_icon_static_path,
        "./priv/static/images/icons"
      )

  @doc """
  Returns the configured URL for generated static icon assets.

  ## Examples

      iex> Iconify.static_url()
      "/images/icons"
  """
  def static_url,
    do: Application.get_env(:iconify_ex, :generated_icon_static_url, "/images/icons")

  defp mode(icon) when is_atom(icon) and not is_nil(icon) and not is_boolean(icon), do: :inline
  defp mode(icon), do: or_mode(complex?(icon))
  defp or_mode(true), do: :img
  defp or_mode(_), do: Application.get_env(:iconify_ex, :mode, false)

  @doc """
  Checks if SVG injection is enabled in config.

  ## Examples

      iex> Iconify.using_svg_inject?()
      false
  """
  def using_svg_inject?, do: Application.get_env(:iconify_ex, :using_svg_inject, false)

  # def css_class, do: Application.get_env(:iconify_ex, :css_class, "iconify_icon")

  defp emoji_sets(),
    do:
      Application.get_env(:iconify_ex, :emoji_sets, [
        "emoji",
        "noto",
        "openmoji",
        "twemoji",
        "fluent-emoji",
        "fxemoji",
        "streamline-emoji"
      ])

  defp complex_sets(),
    do:
      Application.get_env(:iconify_ex, :complex_sets, [
        "line-md",
        "meteocons",
        "svg-spinners",
        "vscode",
        "devicon",
        "skill",
        "unjs",
        "flat-color",
        "flag",
        "circle-flags",
        "cif",
        "logos",
        "token-branded",
        "cryptocurrency-color"
      ])

  @doc """
  Checks if the icon is part of a known emoji set

  ## Examples

      iex> Iconify.emoji?("twemoji:smile")
      true
      iex> Iconify.emoji?("heroicons:user-solid")
      false
  """
  def emoji?(icon),
    do: String.starts_with?(to_string(icon), emoji_sets())

  @doc """
  Checks if the icon is part of a known emoji set or any set shouldn't use CSS mode (eg. includes color or animation).

  ## Examples

      iex> Iconify.complex?("twemoji:smile")
      true
      iex> Iconify.complex?("heroicons:user-solid")
      false
  """
  def complex?(icon),
    do: String.starts_with?(to_string(icon), emoji_sets() ++ complex_sets())

  defp href_for_prepared_set_icon(icon, opts) do
    with [family_name, icon_name] <- family_and_icon(icon) do
      # Translate v1 to v2 for backwards compatibility
      {family_name, icon_name} = translate_heroicons_v1_to_v2(family_name, icon_name)

      icon_name = String.trim_trailing(icon_name, "-icon")

      if preparation_enabled?() do
        do_prepare_set_icon_img(family_name, icon_name, opts)
      end

      "#{static_url()}/#{family_name}.svg##{icon_name}"
    else
      _ ->
        nil
    end
  end

  defp prepare_svg_for_set(family_name, icon_name, opts) do
    json_path = json_path(family_name)

    svg = svg_for_sprite(json_path, icon_name, opts)
    # |> IO.inspect()
  end

  defp do_prepare_set_icon_img(family_name, icon_name, opts \\ []) do
    path = "#{static_path()}"
    src = "#{path}/#{family_name}.svg"

    if not File.exists?(src) do
      svg = opts[:svg] || prepare_svg_for_set(family_name, icon_name, opts)

      sprite = """
      <?xml version="1.0" encoding="utf-8"?>
      <svg xmlns="http://www.w3.org/2000/svg"
          xmlns:xlink="http://www.w3.org/1999/xlink">
          <defs>
            #{svg}
          </defs>
      </svg>
      """

      File.mkdir_p(path)
      File.write!(src, sprite)

      IO.inspect(src,
        label: "Iconify set created: #{family_name} and icon added on family sprite: #{icon_name}"
      )
    else
      IO.inspect(src, label: "Iconify found existing family icon set: #{family_name}")

      {:ok, file} = file_open(src, [:read, :utf8])

      case read_file(src, file)
           # |> IO.inspect
           |> Floki.parse_fragment() do
        {:ok, content} ->
          svgs =
            content
            |> Floki.find("defs")
            |> List.first()
            |> Floki.children()

          # |> IO.inspect

          if Floki.find(svgs, "[id=#{icon_name}]") |> Enum.count() > 0 do
            IO.inspect(src, label: "Iconify icon already exists in set: #{icon_name}")
          else
            IO.inspect(src,
              label: "Iconify look for icon #{icon_name} in iconify icon set: #{family_name}"
            )

            svg = opts[:svg] || prepare_svg_for_set(family_name, icon_name, opts)
            # |> IO.inspect()

            sprite = """
            <?xml version="1.0" encoding="utf-8"?>
            <svg xmlns="http://www.w3.org/2000/svg"
                xmlns:xlink="http://www.w3.org/1999/xlink">
                <defs>
                  #{Floki.raw_html(svgs, encode: true, pretty: true)}
                  #{svg}
                </defs>
            </svg>
            """

            File.write!(src, sprite)
            cache_contents(src, sprite)

            IO.inspect(src, label: "Iconify icon added on family sprite: #{family_name}")
          end

        {:error, err} ->
          IO.inspect(err)
      end
    end
  end

  defp prepare_icon_img(icon, opts \\ []) do
    with img when is_binary(img) <- maybe_prepare_icon_img(icon, opts) do
      img
    else
      _ ->
        icon_error(icon, "Could not process family_and_icon")
    end
  end

  defp maybe_prepare_icon_img(icon, opts) do
    with [family_name, icon_name] <- family_and_icon(icon) do
      # Translate v1 to v2 for backwards compatibility
      {family_name, icon_name} = translate_heroicons_v1_to_v2(family_name, icon_name)

      icon_name = String.trim_trailing(icon_name, "-icon")

      if preparation_enabled?() do
        do_prepare_icon_img(family_name, icon_name, opts)
      end

      "#{static_url()}/#{family_name}/#{icon_name}.svg"
    else
      _ ->
        nil
    end
  end

  defp do_prepare_icon_img(family_name, icon_name, opts) do
    path = "#{static_path()}/#{family_name}"
    src = "#{path}/#{icon_name}.svg"

    if not File.exists?(src) do
      IO.inspect(src, label: "Iconify new icon found")

      json_path = json_path(family_name)

      svg = opts[:svg] || svg_as_is(json_path, icon_name, opts)
      # |> IO.inspect()

      File.mkdir_p(path)
      File.write!(src, svg)

      IO.inspect(src, label: "Iconify icon added")
    else
      IO.inspect(src, label: "Iconify icon already exists")
    end
  end

  defp prepare_icon_component(icon \\ fallback_icon(), opts \\ [])

  defp prepare_icon_component(icon, opts) when is_binary(icon) do
    with [family_name, icon_name] <- family_and_icon(icon) do
      # Translate v1 to v2 for backwards compatibility
      {family_name, icon_name} = translate_heroicons_v1_to_v2(family_name, icon_name)

      do_prepare_icon_component(family_name, icon_name, opts)
    else
      _ ->
        icon_error(icon, "Could not process family_and_icon")
    end
  end

  defp prepare_icon_component(icon, _opts) when is_atom(icon) do
    if Code.ensure_loaded?(icon) do
      icon
    else
      icon_error(
        icon,
        "No component module is available in your app for this icon: `#{inspect(icon)}`. Using the binary icon name instead would allow it to be generated from Iconify. Find icon names at https://icones.js.org"
      )
    end
  end

  defp prepare_icon_component(icon, _opts) do
    icon_error(
      icon,
      "Expected a binary icon name or an icon component module atom, got `#{inspect(icon)}`"
    )
  end

  defp do_prepare_icon_component(family_name, icon_name, opts) do
    icon_name = String.trim_trailing(icon_name, "-icon")
    component_path = "#{path()}/#{family_name}"
    component_filepath = "#{component_path}/#{icon_name}.ex"
    module_name = module_name(family_name, icon_name)

    module_atom =
      "Elixir.#{module_name}"
      |> String.to_atom()

    # |> IO.inspect(label: "module_atom")

    if not Code.ensure_loaded?(module_atom) do
      if preparation_enabled?() do
        if not File.exists?(component_filepath) do
          component_content =
            build_component(
              module_name,
              svg_for_component(json_path(family_name), icon_name, opts)
            )

          File.mkdir_p(component_path)
          File.write!(component_filepath, component_content)
        end

        Code.compile_file(component_filepath)
      else
        icon_error(icon_name, "Icon module not found")
      end
    end

    module_atom
  end

  @docp """
  Creates a component for a given SVG code.

  ## Examples

      iex> Iconify.create_component_for_svg("heroicons", "user-solid", "<svg>...</svg>")
      Iconify.Heroicons.UserSolid
  """
  defp create_component_for_svg(family_name, icon_name, svg_code) do
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
  end

  defp prepare_icon_data(icon, opts) do
    with [family_name, icon_name] <- family_and_icon(icon) do
      # Translate v1 to v2 for backwards compatibility
      {family_name, icon_name} = translate_heroicons_v1_to_v2(family_name, icon_name)

      icon_name = String.trim_trailing(icon_name, "-icon")

      icon_css_name = css_icon_name(family_name, icon_name)

      do_prepare_icon_data(family_name, icon_name, icon_css_name, opts)
    else
      _ ->
        icon_error(icon, "Could not process family_and_icon")
    end
  end

  defp do_prepare_icon_data(family_name, icon_name, icon_css_name, opts) do
    css_path = css_path()

    with {:ok, file} <- open_css_file(css_path) do
      case extract_from_css_file(css_path, file, icon_css_name) do
        nil ->
          if preparation_enabled?(),
            do: do_prepare_icon_css(family_name, icon_name, icon_css_name, opts)

        svg_data ->
          svg_data
      end
    end
  end

  defp prepare_icon_css(icon, opts \\ []) do
    with [family_name, icon_name] <- family_and_icon(icon) do
      # Translate v1 to v2 for backwards compatibility
      {family_name, icon_name} = translate_heroicons_v1_to_v2(family_name, icon_name)

      icon_name =
        icon_name
        |> String.trim_trailing("-icon")

      icon_css_name = css_icon_name(family_name, icon_name)

      if preparation_enabled?() do
        do_prepare_icon_css(family_name, icon_name, icon_css_name, opts)
      end

      icon_css_name
    else
      _ ->
        icon_error(icon, "Could not process family_and_icon")
    end
  end

  defp do_prepare_icon_css(family_name, icon_name, icon_css_name, opts) do
    css_path = css_path()

    with {:ok, file} <- open_css_file(css_path),
         {exists_in_css_file?, existing_contents} <-
           check_exists_in_css_file(css_path, file, icon_css_name) do
      if !exists_in_css_file? do
        svg = opts[:svg] || svg_as_is(json_path(family_name), icon_name, opts)
        # |> IO.inspect()

        data_svg = data_svg(svg)

        css = css_with_data_svg(icon_css_name, data_svg)
        # |> IO.inspect()

        append_css(css_path, file, css, existing_contents)

        data_svg
      end
    end
  end

  def add_icon_to_css(icon_css_name, svg_code) do
    css_path = css_path()

    with {:ok, file} <- open_css_file(css_path),
         {exists_in_css_file?, existing_contents} <-
           check_exists_in_css_file(css_path, file, icon_css_name) do
      if !exists_in_css_file? do
        css = css_svg(icon_css_name, svg_code)
        # |> IO.inspect()

        append_css(css_path, file, css, existing_contents)
      end
    end
  end

  defp css_path(icons_dir \\ static_path()) do
    "#{icons_dir || static_path()}/icons.css"
  end

  defp open_css_file(css_path \\ css_path()) do
    file_open(css_path || css_path(), [:read, :append, :utf8])
  end

  defp svg_as_is(json_path, icon_name, opts) do
    {svg, w, h} = get_svg(json_path, icon_name, opts)

    svg_wrap(svg, w, h)
  end

  defp svg_clean(json_path, icon_name, opts) do
    {svg, w, h} = get_svg(json_path, icon_name, opts)

    clean_svg(svg, icon_name)
    |> svg_wrap(w, h)
  end

  defp svg_wrap(svg, w, h) do
    "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 #{w} #{h}\">#{svg}</svg>"
  end

  defp svg_for_sprite(json_path, icon_name, opts) do
    {svg, w, h} = get_svg(json_path, icon_name, opts)

    "<svg id=\"#{icon_name}\" xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 #{w} #{h}\" fill=\"currentColor\" aria-hidden=\"true\">#{svg_as_is(json_path, icon_name, opts)}</svg>"
  end

  defp svg_for_component(json_path, icon_name, opts) do
    {svg, w, h} = get_svg(json_path, icon_name, opts)

    "<svg data-icon=\"#{icon_name}\" xmlns=\"http://www.w3.org/2000/svg\" role=\"img\" class={@class} viewBox=\"0 0 #{w} #{h}\" aria-hidden=\"true\">#{clean_svg(svg, icon_name)}</svg>"
  end

  defp full_svg_for_component(svg_code, icon_name) do
    String.replace(
      clean_svg(svg_code, icon_name),
      "<svg",
      "<svg data-icon=\"#{icon_name}\" class={@class}"
    )
  end

  defp custom_svg_component(assigns) do
    ~H"""
    <div data-icon="custom" class={@class}><%= Phoenix.HTML.raw(clean_svg(@icon)) %></div>
    """
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

  defp get_svg(json_filepath, icon_name, opts) do
    case list_json_svgs(json_filepath, icon_name, opts) do
      {:ok, json, icons} when is_map(icons) ->
        if opts[:icon_json] || Map.has_key?(icons, icon_name) do
          icon = opts[:icon_json] || Map.fetch!(icons, icon_name)

          return_svg(json, icon)
        else
          if icon_alias = Map.get(json["aliases"] || %{}, icon_name, %{}) |> Map.get("parent") do
            icon_error(
              icon_name,
              "This icon is an alias of another icon: #{inspect(icon_alias)} - Please directly use that one instead."
            )
          else
            icon_error(
              icon_name,
              "No such icon found in icon set #{json_filepath} - Icons available include: #{Enum.join(Map.keys(icons), ", ")}"
            )
          end
        end

      _ ->
        icon_error(
          icon_name,
          "No icons found in icon set #{json_filepath}"
        )
    end
  end

  defp return_svg(json, icon) do
    {
      Map.fetch!(icon, "body"),
      Map.get(icon, "width") || Map.get(json, "width") || 16,
      Map.get(icon, "height") || Map.get(json, "height") || 16
    }
  end

  defp list_json_svgs(json_filepath, icon_name \\ nil, opts \\ []) do
    case opts[:json] || get_json(json_filepath, icon_name) do
      json when is_map(json) ->
        {:ok, json |> Map.drop(["icons"]), Map.get(json, "icons", %{})}
    end
  end

  defp get_json(json_filepath, icon_name \\ nil) do
    with {:ok, data} <- File.read(json_filepath) do
      data
      |> Jason.decode!()
    else
      _ ->
        # Try to auto-install icon sets if missing
        if Code.ensure_loaded?(Mix.Tasks.Iconify.Setup) do
          case maybe_auto_install_icon_sets(json_filepath) do
            :ok ->
              # Retry after installation
              case File.read(json_filepath) do
                {:ok, data} -> Jason.decode!(data)
                _ -> icon_error_no_icon_set(json_filepath, icon_name)
              end

            :error ->
              icon_error_no_icon_set(json_filepath, icon_name)
          end
        else
          icon_error_no_icon_set(json_filepath, icon_name)
        end
    end
  end

  defp maybe_auto_install_icon_sets(json_filepath) do
    # Only attempt auto-install once per session to avoid repeated failures
    cache_key = :iconify_auto_install_attempted

    if :persistent_term.get(cache_key, false) do
      :error
    else
      :persistent_term.put(cache_key, true)

      Mix.shell().info("""
      Iconify icon sets not found. Auto-installing...
      (Missing: #{json_filepath})
      """)

      try do
        Mix.Tasks.Iconify.Setup.run([])
        :ok
      rescue
        _ -> :error
      end
    end
  end

  defp icon_error_no_icon_set(json_filepath, icon_name) do
    icon_error(
      icon_name,
      """
      No icon set found at `#{json_filepath}` for the icon `#{icon_name}`.

      Icon sets must be installed before use. Run:

          mix iconify.setup

      Or manually:

          cd deps/iconify_ex/assets && npm install

      Find available icons at https://icones.js.org
      """
    )
  end

  defp module_name(family_name, icon_name) do
    "Iconify" <> module_section(family_name) <> module_section(icon_name)
  end

  defp module_section(name) do
    "." <> module_camel(name)
  end

  defp module_camel(name) do
    name
    |> String.split("-")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join("")
    |> module_sanitise()
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

  defp icon_error("<svg " <> _ = icon, _msg) do
    throw({:fallback, icon})
  end

  defp icon_error(icon, msg) do
    if icon not in [
         "question-mark-circle",
         "question-mark-circle-solid",
         fallback_icon(),
         Iconify.Heroicons.QuestionMarkCircleSolid,
         Iconify.HeroiconsSolid.QuestionMarkCircle
       ] do
      error(msg, "Iconify error with icon: #{inspect(icon)}")
      throw({:fallback, fallback_icon()})
    else
      throw(msg)
    end
  end

  defp write_css(icons_dir \\ static_path(), css) do
    css = Enum.join(css, "\n") <> "\n"
    path = css_path(icons_dir)
    File.write!(path, css)
    # cache_contents(path, css)
  end

  defp append_css(css_path, file, css, existing_contents) when is_list(css) do
    append_css(css_path, file, Enum.join(css, "\n"), existing_contents)
  end

  defp append_css(css_path, file, css, existing_contents) when is_binary(css) do
    css = "#{css}\n"

    # file = if Process.alive?(file) do
    #   file
    # else
    #   file_open(path, args, :force)
    # end

    IO.write(file, css)
    # cache_contents(css_path, "#{existing_contents}\n#{css}", cache_contents_key(css_path))
  end

  # defp exists_in_css?(file_or_icons_dir \\ static_path(), icon_css_name)

  # defp exists_in_css?(icons_dir, icon_css_name) when is_binary(icons_dir) do
  #   css_path = css_path()
  #   with {:ok, file} <- open_css_file(css_path) do
  #     exists_in_css_file?(css_path, file, icon_css_name)
  #   else
  #     e ->
  #       IO.warn(e)
  #       false
  #   end
  # end

  # defp exists_in_css_file?(css_path, file, icon_css_name) do
  #   check_exists_in_css_file(css_path, file, icon_css_name) 
  #   |> Enum.at(0)
  # end

  defp check_exists_in_css_file(css_path, file, icon_css_name) do
    contents = read_file(css_path, file, :force)

    {
      contents
      |> String.contains?("\"#{icon_css_name}\""),
      #  |> debug(icon_css_name)
      contents
    }
  end

  defp extract_from_css_file(css_path, file, icon_css_name) do
    text = read_file(css_path, file, :force)

    Regex.run(
      ~r/\[iconify="#{icon_css_name}"]{--Iy:url\("data:image\/svg\+xml;utf8,([^"]+)/,
      text,
      capture: :first
    )
  end

  defp file_open(path, args, extra \\ nil)

  defp file_open(path, args, {:force, key}) do
    File.mkdir_p(Path.dirname(path))

    with {:ok, file} <- File.open(path, args) do
      Process.put(key, file)
      {:ok, file}
    end
  end

  defp file_open(path, args, _) do
    key = "iconify_ex_file_#{path}_#{inspect(args)}"

    case Process.get(key) do
      nil ->
        # debug(path, "open")
        file_open(path, args, {:force, key})

      io_device ->
        # if Process.alive?(io_device) do
        # debug(path, "use available")
        {:ok, io_device}
        # else
        #     debug(path, "re-open")
        #     file_open(path, args, {:force, key})
        # end
    end
  end

  defp read_file(path, file, extra \\ nil)

  defp read_file(path, file, :force) do
    with {:ok, contents} <- File.read(path) do
      contents
    else
      e ->
        error(e)
        ""
    end
  end

  defp read_file(path, file, _) do
    key = cache_contents_key(path)

    case get_cache(key) do
      nil ->
        # debug(path, "read")
        contents = IO.read(file, :all)
        cache_contents(path, contents, key)
        contents

      contents ->
        # debug(path, "use cached")
        contents
    end
  end

  defp init_cache do
    case :ets.whereis(:iconify_ex_cache) do
      :undefined ->
        :ets.new(:iconify_ex_cache, [:named_table, :set, :public])

      _ ->
        nil
        # already exists
    end
  end

  defp get_cache(key, fallback \\ nil) do
    # Process.get(key)

    init_cache()

    case :ets.lookup(:iconify_ex_cache, key) do
      [{key, value}] ->
        value

      _ ->
        # not found
        fallback
    end

    # |> debug
  end

  defp put_cache(key, value) do
    # Process.put(key)

    init_cache()

    :ets.insert(:iconify_ex_cache, {key, value})
    # |> debug
  end

  defp cache_contents_key(path) do
    "iconify_ex_contents_#{path}"
  end

  defp cache_contents(path, contents, key \\ nil) do
    key = key || cache_contents_key(path)

    put_cache(key, contents)
    # |> debug("#{key}")
  end

  # defp process_id do
  #   case :erlang.get(:elixir_compiler_info) do
  #     {compiler_pid, _file_pid} ->
  #       compiler_pid

  #     _ ->
  #       # debug("not compiling")
  #       self()
  #   end
  # end

  @doc """
  Translates Heroicons v1 naming to v2 naming for backwards compatibility.

  ## Examples

      iex> Iconify.translate_heroicons_v1_to_v2("heroicons-solid", "camera")
      {"heroicons", "camera-solid"}

      iex> Iconify.translate_heroicons_v1_to_v2("heroicons-outline", "camera")
      {"heroicons", "camera"}

      iex> Iconify.translate_heroicons_v1_to_v2("other-family", "icon")
      {"other-family", "icon"}
  """
  def translate_heroicons_v1_to_v2(family_name, icon_name) do
    case family_name do
      "heroicons-solid" ->
        # v1 solid → v2 24px solid
        {"heroicons", "#{icon_name}-solid"}

      "heroicons-outline" ->
        # v1 outline → v2 24px outline (default)
        {"heroicons", icon_name}

      _ ->
        # Not a v1 heroicons family, pass through
        {family_name, icon_name}
    end
  end

  defp json_path(family_name) do
    # __DIR__ is the directory containing this source file (lib/)
    # Go up one level to get the iconify_ex root, then into assets/
    lib_assets_path = Path.join([__DIR__, "..", "assets", "node_modules", "@iconify", "json", "json", "#{family_name}.json"]) |> Path.expand()

    # Also check the project's own assets folder (for projects that install directly)
    project_assets_path = Path.join([File.cwd!(), "assets", "node_modules", "@iconify", "json", "json", "#{family_name}.json"])

    cond do
      File.exists?(lib_assets_path) -> lib_assets_path
      File.exists?(project_assets_path) -> project_assets_path
      true -> lib_assets_path  # Return lib path for error message
    end
    |> IO.inspect(label: "load JSON for #{family_name} icon family")
  end

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

    # |> String.replace("='#", "='%23") # WIP: workaround for hex colors in params
  end

  defp css_icon_name(family, icon), do: "#{family}:#{icon}"

  defp family_and_icon(name) when is_binary(name) do
    name
    |> String.split(":")
    |> Enum.map(&icon_name/1)
  end

  defp family_and_icon(nil), do: {"heroicons-solid", "question-mark-circle"}

  defp family_and_icon(name) do
    name
    |> to_string()
    |> family_and_icon()
  end

  defp icon_name(name) do
    Recase.to_kebab(name)
    |> String.downcase()
  end

  defp render_svg_for_sprite(assigns) do
    # {_svg, w, h} = get_svg(json_path, icon_name)
    ~H"""
    <svg class={@class}>
      <use href={@href} class={@class}></use>
    </svg>
    """
  end

  defp render_svg_with_img(assigns) do
    ~H"""
    <img
      src={@src}
      class={@class}
      onload={if using_svg_inject?(), do: "SVGInject(this)"}
      aria-hidden="true"
    />
    """
  end

  defp render_svg_with_css(assigns) do
    ~H"""
    <div iconify={@icon_name} class={@class} aria-hidden="true" />
    """

    # <div class={"#{css_class()} #{@class}"} style={"-webkit-mask: var(--#{@icon_name}); mask: var(--#{@icon_name})"} aria-hidden="true" />
  end

  # defp render_svg_with_css(assigns) do
  #   ~H"""
  #   <div class={"#{@icon_name} #{@class}"} aria-hidden="true" />
  #   """
  # end

  @doc """
  Sets the favicon for a Phoenix LiveView socket.

  ## Examples

      iex> socket = %Phoenix.LiveView.Socket{}
      iex> %Phoenix.LiveView.Socket{} = Iconify.maybe_set_favicon(socket, "heroicons:star-solid")
  """
  def maybe_set_favicon(socket, "<svg" <> _ = icon) do
    socket
    |> maybe_phx_live_set_dynamic(data_image_svg(icon))
  end

  def maybe_set_favicon(socket, icon) when is_binary(icon) do
    if String.contains?(icon, ":") do
      if Iconify.emoji?(icon) do
        maybe_set_favicon_emoji(socket, icon)
      else
        # IO.inspect(icon, label: "not emojiii")
        do_set_favicon_iconify(socket, icon)
      end
    else
      # IO.inspect(icon, label: "a manual emojiii or other text")
      do_set_favicon_text(socket, icon)
    end
  end

  def maybe_set_favicon(socket, _icon) do
    socket
    |> Phx.Live.Favicon.reset()
  end

  def maybe_phx_live_set_dynamic(socket, icon, type \\ "svg")

  def maybe_phx_live_set_dynamic(socket, icon, type) when is_binary(icon) do
    socket
    |> Phx.Live.Favicon.set_dynamic(type, icon)
  end

  def maybe_phx_live_set_dynamic(socket, _icon, _type) do
    socket
    |> Phx.Live.Favicon.reset()
  end

  defp maybe_set_favicon_emoji(socket, icon) do
    case manual(icon, assign(socket.assigns, :mode, :img_url)) do
      img when is_binary(img) ->
        # img
        # |> IO.inspect(label: "use emojiii from URL")

        maybe_phx_live_set_dynamic(socket, img)

      _ ->
        case Code.ensure_loaded?(Emote) and
               String.split(icon, ":", parts: 2)
               |> List.last()
               |> Recase.to_snake()
               |> Emote.lookup() do
          emoji when is_binary(emoji) ->
            # IO.inspect(emoji, label: "emojiii in emote")
            do_set_favicon_text(socket, emoji)

          _ ->
            # IO.inspect(icon, label: "no such emojiii")

            socket
            |> Phx.Live.Favicon.reset()
        end
    end
  end

  defp do_set_favicon_text(socket, text) do
    "<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 100 100%22><text y=%22.9em%22 font-size=%2290%22>#{text}</text></svg>"
    |> data_image_svg()
    |> maybe_phx_live_set_dynamic(socket, ...)
  end

  defp do_set_favicon_iconify(socket, icon) do
    manual(icon, assign(socket.assigns, :mode, :data))
    # |> IO.inspect(label: "iconify - not emojiii")
    ~> data_image_svg()
    ~> maybe_phx_live_set_dynamic(socket, ...)
  end

  defp data_image_svg(svg), do: "data:image/svg+xml;utf8,#{svg}"

  # defp do_set_favicon_text(socket, icon) do
  # TODO
  #   <link rel="icon" href="data:image/svg+xml,&lt;svg viewBox=%220 0 100 100%22 xmlns=%22http://www.w3.org/2000/svg%22&gt;&lt;text y=%22.9em%22 font-size=%2290%22&gt;⏰&lt;/text&gt;&lt;rect x=%2260.375%22 y=%2238.53125%22 width=%2239.625%22 height=%2275.28125%22 rx=%226.25%22 ry=%226.25%22 style=%22fill: red;%22&gt;&lt;/rect&gt;&lt;text x=%2293.75%22 y=%2293.75%22 font-size=%2260%22 text-anchor=%22end%22 alignment-baseline=%22text-bottom%22 fill=%22white%22 style=%22font-weight: 400;%22&gt;1&lt;/text&gt;&lt;/svg&gt;">
  # end

  @doc """
  Prepares an entire icon family for a particular mode.

  ## Examples

      iex> Iconify.prepare_entire_icon_family("heroicons", :inline) # creates a Phoenix.Component module file for each icon in the set
  """
  def prepare_entire_icon_family(family_name, mode \\ nil) do
    case list_icon_family(family_name) do
      {:ok, json, icons} when is_map(icons) and icons != %{} ->
        for {icon_name, icon_json} <- icons do
          prepare("#{family_name}:#{icon_name}", json: json, icon_json: icon_json, mode: mode)
        end
    end
  end

  defp list_icon_family(family_name) do
    json_path(family_name)
    |> list_json_svgs()
  end

  def list_entire_icon_family(family_name) do
    case list_icon_family(family_name) do
      {:ok, json, icons} when is_map(icons) and icons != %{} ->
        for {icon_name, icon_json} <- icons do
          icon_name
        end
    end
  end

  @doc """
  Lists all available icon components.

  ## Examples

      > Iconify.list_components()
      %{
        "HeroiconsSolid" => [Iconify.HeroiconsSolid.User, Iconify.HeroiconsSolid.Star, _],
        "HeroiconsOutline" => [Iconify.HeroiconsOutline.User, Iconify.HeroiconsOutline.Star, _]
      }
  """
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
    else
      e ->
        error(e)
        []
    end

    # |> debug()
  end

  @doc """
  Lists all icons defined in the CSS file.

  ## Examples

      > Iconify.list_icons_in_css()
      %{
        "HeroiconsSolid" => ["user", "star", _],
        "HeroiconsOutline" => ["user", "star", _]
      }
  """
  def list_icons_in_css do
    css_path = css_path()

    with {:ok, file} <- open_css_file(css_path) do
      text =
        read_file(css_path, file, :force)
        |> String.split("\n")
        |> Enum.map(fn line ->
          line
          |> String.split("\"")
          |> Enum.at(1)
        end)
        |> group_for_listing()
    end
  end

  defp list_icon_images(icons_dir \\ static_path()) do
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
  end

  def list_icons_in_images() do
    list_icon_images()
    |> Enum.map(fn {icon, _path} ->
      icon
    end)
    |> group_for_listing()
  end

  defp group_for_listing(icons) do
    icons
    |> Enum.reject(&is_nil/1)
    |> Enum.group_by(fn icon ->
      String.split(icon, ":")
      |> List.first()
      |> module_camel()
    end)
  end

  @doc """
  Lists all existing icons (components and CSS).

  ## Examples

      > Iconify.list_all_existing()
      %{
        "HeroiconsSolid" => [Iconify.HeroiconsSolid.User, "user", _],
        "HeroiconsOutline" => [Iconify.HeroiconsOutline.User, "user", _]
      }
  """
  def list_all_existing do
    # TODO: include sprite icons too
    list_icons_in_css()
    |> merge_map_lists(list_components())
    |> merge_map_lists(list_icons_in_images())
  end

  defp merge_map_lists(a, b) do
    Map.merge(a, b, fn _k, v1, v2 ->
      v1 ++ v2
    end)
  end

  @doc """
  Generates icon sets from existing components.

  ## Examples

      > Iconify.generate_sets_from_components()
      [:ok, :ok, _]
  """
  def generate_sets_from_components() do
    icons = icon_from_components()

    css =
      Enum.map(icons, fn {family, icon, mod} ->
        svg =
          mod.render([])
          |> Map.get(:static, [])
          |> Enum.join("")
          |> String.replace("data-icon=", "id=")
          |> String.replace("aria-hidden=\"true\"", "")
          |> String.replace("class=\"\"", "")

        do_prepare_set_icon_img(family, icon, svg: svg)
      end)
      |> IO.inspect()
  end

  @doc """
  Generates CSS icons from existing static files.

  ## Examples

      iex> Iconify.generate_css_from_static_files()
      :ok
  """
  def generate_css_from_static_files() do
    icons_dir = static_path()

    icons = list_icon_images(icons_dir)

    css =
      Enum.map(icons, fn {name, full_path} ->
        css_svg(name, File.read!(full_path))
      end)
      |> IO.inspect()

    write_css(icons_dir, css)
  end

  @doc """
  Generates CSS icons from existing components.

  ## Examples

      iex> Iconify.generate_css_from_components()
      :ok
  """
  def generate_css_from_components() do
    icons = icon_from_components()

    css =
      Enum.map(icons, fn {family, icon, mod} ->
        css_svg(
          css_icon_name(family, icon),
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

  defp icon_from_components do
    list_components()
    |> Enum.flat_map(fn {family, mods} ->
      mods
      |> Enum.map(fn mod ->
        icon =
          String.split("#{mod}", ".")
          |> List.last()

        {icon_name(family), icon_name(icon), mod}
      end)
    end)
  end
end
