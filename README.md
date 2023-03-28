# Iconify for Phoenix

Phoenix helpers for using 100,000+ SVG icons from 100+ icon sets compiled by [Iconify](https://icon-sets.iconify.design) (visit that site to browse the sets available and preview the icons)

It copies only the icons you use from the iconify library into your project, preparing them on-the-fly when you first use an icon in a view or component, during development.

It can be configured to embed the icons one of three ways:
- `css` (default): generate a single CSS file containing SVGs of all the icons used 
- `img` (default for emojis): to create SVG files in your static assets, used to be included with `img` tags and loaded over HTTP (you may want to include https://github.com/iconfu/svg-inject on your site to enable styling of the SVGs, e.g. to change their colour)
- `inline`: to generate a Phoenix Component for each icon used, used to embed the icons as `svg` tags inline in the HTML of your views (meaning the SVG will be included in LiveView diffs)

## Installation

```elixir
def deps do
  [
    {:iconify_ex, "~> 0.0.2"}
  ]
end
```

You then need to fetch the latest [iconify icon sets](https://github.com/iconify/icon-sets) by running:
```bash
cd deps/iconify_ex/assets && yarn
```

## Usage

1. Add `import Iconify` in your Phoenix or LiveView module where you want to use it (or just once in the macros in your Web module). 

2. Set one of these options in config to choose which approach you want to use (see above for explanations):
- `config :iconify_ex, :mode, :css` 
- `config :iconify_ex, :mode, :img` 
- `config :iconify_ex, :mode, :inline` 

If using CSS mode, you'll need to set some default styles that apply to all icons, either by adding something like this to your app's main CSS:
```css
[iconify] {
  background-color: currentColor;
  -webkit-mask-size: cover;
  mask-size: cover;
  min-width: 0.5rem;
  min-height: 0.5rem;
}
```

3. In all three cases, usage is simple and remains the same:

Embed an icon using default classes (copy the icon name from the [iconify website](https://icon-sets.iconify.design)):
```html
<.iconify icon="heroicons-solid:collection" />
```

Specify custom classes:
```html
<.iconify icon="heroicons-solid:collection" class="w-8 h-8 text-base-content" /> 
```

Or if you use [Surface](https://surface-ui.org), it is highly recommended to use the macro component which means icons will be prepared at compile time rather than runtime:

Add `alias Iconify.Icon` to your Web module, and then:

```html
<#Icon iconify="heroicons-solid:collection" />
```

If your icon is dynamic, you'll still want to use the first form:
```html
<.iconify icon={@my_icon} />
```
