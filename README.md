# Iconify for Phoenix

A collection of Phoenix Components for Iconify

## Installation

```elixir
def deps do
  [
    {:iconify_ex, "~> 0.0.1"}
  ]
end
```

You need to fetch the latest [iconify icon sets](https://github.com/iconify/icon-sets) by running:
```bash
cd deps/iconify_ex/assets && yarn
```

## Usage

Add `import Iconify` in your Phoenix or LiveView module where you want to use it (or just once in the macros in your Web module)

Embed an icon using default classes:
```html
<.iconify icon="heroicons-solid:collection">
```

Specifying classes:
```html
<.iconify icon="heroicons-solid:collection" class="w-8 h-8 text-base-content" /> 
```
