# Iconify for Phoenix

Phoenix Component generator for the SVG of 100,000+ icons from 100+ icon sets from https://icon-sets.iconify.design

Only generates a component on-the-fly when a particular icon is first included in a view or component. 

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

First add `import Iconify` in your Phoenix or LiveView module where you want to use it (or just once in the macros in your Web module).

Embed an icon using default classes:
```html
<.iconify icon="heroicons-solid:collection">
```

Specifying classes:
```html
<.iconify icon="heroicons-solid:collection" class="w-8 h-8 text-base-content" /> 
```
