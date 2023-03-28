if Code.ensure_loaded?(Surface) do
  defmodule Iconify.Icon do
    use Surface.MacroComponent

    # any icon from iconify: https://icones.js.org
    prop iconify, :string, required: false, static: true

    # shorthand for heroicons solid icons
    prop solid, :string, required: false, static: true
    # shorthand for heroicons outline icons
    prop outline, :string, required: false, static: true

    # pass SVG markup directly
    prop svg, :string, default: nil, required: false, static: true

    prop class, :css_class, default: "w-4 h-4"

    def expand(attributes, _content, meta) do
      static_props =
        Surface.MacroComponent.eval_static_props!(__MODULE__, attributes, meta.caller)

      svg = svg_icon(static_props)

      class = Surface.AST.find_attribute_value(attributes, :class) || ""

      icon = icon_name(static_props)

      if is_nil(svg) do
        case Iconify.prepare(%{icon: icon}) do
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
        end
      else
        quote_surface do
          ~F"""
          <div class={^class} aria-hidden="true">{^svg}</div>
          """
        end
      end
    end

    def svg_icon(%{svg: svg}) when is_binary(svg) do
      svg
    end

    def svg_icon(%{iconify: "<svg" <> _ = svg}) do
      svg
    end

    def svg_icon(_) do
      nil
    end

    def icon_name(%{iconify: icon})
        when is_binary(icon) or (is_atom(icon) and not is_nil(icon)) do
      icon
    end

    def icon_name(%{solid: icon})
        when is_binary(icon) or (is_atom(icon) and not is_nil(icon)) do
      "heroicons-solid:#{icon}"
    end

    def icon_name(%{outline: icon})
        when is_binary(icon) or (is_atom(icon) and not is_nil(icon)) do
      "heroicons-outline:#{icon}"
    end

    def icon_name(_assigns) do
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
        IO.inspect(class, label: "kccccc")
        Surface.css_class(class)
      else
        IO.inspect(class, label: "lccccc")
        Enum.join(class, " ")
      end
    end

    def class_to_string(class) do
      IO.inspect(class, label: "occccc")
      Surface.css_class(class)
    end
  end
end
