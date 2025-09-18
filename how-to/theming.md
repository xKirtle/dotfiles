# Theme Tokens Cheat Sheet (Neutral + Teal)

A minimal, Bootstrap-style palette you can copy into any config. No terminal/ANSI section.

## Core Tokens
- **Primary (text)**: `#d8dee9`
- **Secondary (text-2)**: `#cfd6dc`
- **Muted (text-muted)**: `#a7b0b8`

- **Background**: `#0f1115`
- **Surface**: `#1a1e24`
- **Surface Sunken**: `#11141a`
- **Surface Elevated**: `#2a2f37`
- **Border**: `#3a414c`

- **Accent (primary)**: `#5fb3b3`
- **Accent Hover**: `#58a6a6`
- **Accent Active/Focus**: `#4e9797`

### Optional Semantic
- **Success**: `#8bbf9f`
- **Warning**: `#c7b38b`
- **Danger**: `#cc6d6d`
- **Info**: `#88a7c9`

### Overlays
- **Shadow**: `rgba(0,0,0,0.40)`
- **Scrim/Overlay**: `rgba(15,17,21,0.60)`

---

## Copy Blocks

### CSS Variables (Waybar, Wofi, etc.)
```css
:root {
  --color-primary: #d8dee9;
  --color-secondary: #cfd6dc;
  --color-muted: #a7b0b8;

  --bg: #0f1115;
  --surface: #1a1e24;
  --surface-sunken: #11141a;
  --surface-elevated: #2a2f37;
  --border: #3a414c;

  --accent: #5fb3b3;
  --accent-hover: #58a6a6;
  --accent-active: #4e9797;

  --success: #8bbf9f;
  --warning: #c7b38b;
  --danger:  #cc6d6d;
  --info:    #88a7c9;
}
```

## GTK 3/4
```css
@define-color primary_text   #d8dee9;
@define-color secondary_text #cfd6dc;
@define-color muted_text     #a7b0b8;

@define-color base_bg        #0f1115;
@define-color surface_bg     #1a1e24;
@define-color surface_sunken #11141a;
@define-color surface_elev   #2a2f37;
@define-color border_col     #3a414c;

@define-color accent         #5fb3b3;
@define-color accent_hover   #58a6a6;
@define-color accent_active  #4e9797;

@define-color success        #8bbf9f;
@define-color warning        #c7b38b;
@define-color danger         #cc6d6d;
@define-color info           #88a7c9;
```

## Hyprland (ARGB)
```css
col.active_border   = 0xff5fb3b3  # accent
col.inactive_border = 0xff3a414c  # border
col.group_border    = 0xff4e9797  # accent-active
col.group_border_locked = 0xff58a6a6  # accent-hover
```