# Iconify for Phoenix

Phoenix helpers for using 100,000+ SVG icons from 100+ icon sets from https://icon-sets.iconify.design

It can work one of 3 ways, including only the icons you use (preparing them on-the-fly when you first use an icon in a view or component, during dev):
- it places SVG files in your static assets, to include using `<img src` 
- it generates a Phoenix component for each icon, to include the SVGs inline 
- it adds icons to a single CSS file with all the icons as SVG classes

## Installation

```elixir
def deps do
  [
    {:iconify_ex, "~> 0.0.1"}
  ]
end
```

You then need to fetch the latest [iconify icon sets](https://github.com/iconify/icon-sets) by running:
```bash
cd deps/iconify_ex/assets && yarn
```

## Usage

Set one of these options in config:
`config :iconify_ex, :mode, :inline` to define a Phoenix Component for each icon used which embed the `svg` inline
`config :iconify_ex, :mode, :img` to include the SVGs loaded over HTTP and include using an `img` tag (you also need to include https://github.com/iconfu/svg-inject on your frontend to enable styling the SVGs)
`config :iconify_ex, :mode, :css` to generate a single CSS file with all the SVGs defined as classes

Add `import Iconify` in your Phoenix or LiveView module where you want to use it (or just once in the macros in your Web module).

Embed an icon using default classes:
```html
<.iconify icon="heroicons-solid:collection">
```

Specifying classes:
```html
<.iconify icon="heroicons-solid:collection" class="w-8 h-8 text-base-content" /> 
```
