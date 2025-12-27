if Code.ensure_loaded?(Surface) do
  defmodule Iconify.Icon do
    @moduledoc """
    A `Surface` component for rendering icons using various methods.

    ## Specifying what icon to use

    - `iconify` or `icon`: Any icon from Iconify (https://icones.js.org)
    - `solid`: Shorthand for Heroicons solid icons
    - `outline`: Shorthand for Heroicons outline icons

    ## Extra Properties
    - `svg`: Optionally pass SVG markup directly
    - `mode`: Sets what rendering mode to use (see `Iconify` docs)
    - `class`: Any CSS classes to apply to the icon

    ## Examples

        iex> alias Iconify.Icon
        iex> ~F"<#Icon iconify=\"heroicons:user-solid\" class=\"w-6 h-6\" />"
        # Returns rendered icon HTML

        iex> ~F"<#Icon solid=\"user\" class=\"w-6 h-6\" />"
        # Shorthand for heroicons v2 24px solid

        iex> ~F"<#Icon outline=\"user\" class=\"w-6 h-6\" />"
        # Shorthand for heroicons v2 24px outline

        iex> ~F"<#Icon mini=\"user\" class=\"w-5 h-5\" />"
        # Shorthand for heroicons v2 20px solid

        iex> ~F"<#Icon micro=\"user\" class=\"w-4 h-4\" />"
        # Shorthand for heroicons v2 16px solid

        iex> ~F"<#Icon svg=\"<svg>...</svg>\" class=\"w-6 h-6\" />"
    """

    use Surface.MacroComponent

    # any icon from iconify: https://icones.js.org
    prop(iconify, :string, required: false, static: true)
    prop(icon, :string, required: false, static: true)

    # shorthand for heroicons v2 24px solid icons
    prop(solid, :string, required: false, static: true)
    # shorthand for heroicons v2 24px outline icons (default)
    prop(outline, :string, required: false, static: true)
    # shorthand for heroicons v2 20px solid icons (mini)
    prop(mini, :string, required: false, static: true)
    # shorthand for heroicons v2 16px solid icons (micro)
    prop(micro, :string, required: false, static: true)

    # pass SVG markup directly
    prop(svg, :string, default: nil, required: false, static: true)

    prop(mode, :atom, required: false, static: true)

    prop(class, :css_class, default: nil)

    @doc """

    """
    def expand(attributes, _content, meta) do
      static_props =
        Surface.MacroComponent.eval_static_props!(__MODULE__, attributes, meta.caller)

      svg = svg_icon(static_props)
      icon = prepare_icon_name(static_props)

      class =
        Surface.AST.find_attribute_value(attributes, :class) ||
          Application.get_env(:iconify_ex, :default_class, "w-4 h-4")

      # TODO? simply include the phoenix component like so instead of duplicating logic, see https://github.com/surface-ui/surface/pull/685#issuecomment-1505978390
      # quote_surface caller: meta.caller do
      #   ~F"""
      #   <Iconify.iconify class={^class} icon={^icon} />
      #   """
      # end

      if is_nil(svg) do
        case Iconify.prepare(icon, static_props[:mode]) do
          {:css, _fun, %{icon_name: icon_name}} ->
            # icon_class = "#{Iconify.css_class()} #{icon_css_name} #{class_to_string(class)}" 

            quote_surface do
              ~F"""
              <div iconify={^icon_name} class={^class} aria-hidden="true" />
              """
            end

          {:img, _fun, %{src: src}} ->
            quote_surface do
              ~F"""
              <img
                src={^src}
                class={^class}
                onload={if Iconify.using_svg_inject?(), do: "SVGInject(this)"}
                aria-hidden="true"
              />
              """
            end

          {:inline, fun, _assigns} ->
            quote_surface do
              ~F"""
              <{^fun} class={^class} />
              """
            end

          {:set, _fun, %{href: href}} ->
            quote_surface do
              ~F"""
              <svg class={^class} aria-hidden="true"><use href={^href} class={^class} /></svg>
              """
            end
        end
      else
        quote_surface do
          ~F"""
          <div class={^class} aria-hidden="true">{^svg}</div>
          """
        end
      end
    end

    defmacro icon_name(icon) do
      name = prepare_icon_name(icon)

      Iconify.prepare(name, :css)
      # |> IO.inspect(label: "prepared icon")

      name
    end

    defp svg_icon(%{svg: svg}) when is_binary(svg) do
      svg
    end

    defp svg_icon(%{iconify: "<svg" <> _ = svg}) do
      svg
    end

    defp svg_icon(_) do
      nil
    end

    defp prepare_icon_name(%{iconify: icon})
         when is_binary(icon) or (is_atom(icon) and not is_nil(icon)) do
      icon
    end

    defp prepare_icon_name(%{icon: icon})
         when is_binary(icon) or (is_atom(icon) and not is_nil(icon)) do
      icon
    end

    defp prepare_icon_name(%{solid: icon})
         when is_binary(icon) or (is_atom(icon) and not is_nil(icon)) do
      "heroicons:#{icon}-solid"
    end

    defp prepare_icon_name(%{outline: icon})
         when is_binary(icon) or (is_atom(icon) and not is_nil(icon)) do
      "heroicons:#{icon}"
    end

    defp prepare_icon_name(%{mini: icon})
         when is_binary(icon) or (is_atom(icon) and not is_nil(icon)) do
      "heroicons:#{icon}-20-solid"
    end

    defp prepare_icon_name(%{micro: icon})
         when is_binary(icon) or (is_atom(icon) and not is_nil(icon)) do
      "heroicons:#{icon}-16-solid"
    end

    defp prepare_icon_name(icon)
         when is_binary(icon) or (is_atom(icon) and not is_nil(icon)) do
      icon
    end

    defp prepare_icon_name(assigns) do
      e = "iconify: icon name not found in assigns"
      # IO.inspect(assigns, label: e)
      # raise e
      ""
    end

    def class_to_string(class) when is_binary(class) do
      class
    end

    def class_to_string(%{original: class}) do
      class
      # |> class_to_string()
    end

    def class_to_string(class) when is_list(class) do
      if Keyword.keyword?(class) do
        # IO.inspect(class, label: "kccccc")
        Surface.css_class(class)
      else
        # IO.inspect(class, label: "lccccc")
        Enum.join(class, " ")
      end
    end

    def class_to_string(class) do
      # IO.inspect(class, label: "occccc")
      Surface.css_class(class)
    end
  end
end
