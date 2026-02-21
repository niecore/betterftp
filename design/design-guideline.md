# FTP.TEST — Design Guidelines v1.0

## Brand Identity

**App name:** FTP.TEST  
**Tagline:** Power Lab  
**Domain:** ftptests.icu  
**Purpose:** Cycling FTP (Functional Threshold Power) testing app  

---

## Design Philosophy

The design follows a **bold retro / boxy 2000s** aesthetic:
- Chunky bordered cards with colored headers
- Heavy monospace typography
- Strong visual hierarchy through color-coded sections
- No rounded "soft" UI — everything is purposefully blocky and bold
- Yellow appears ONLY on hover as confirmation feedback

---

## Typography

### Font Family
**Iosevka** — open-source monospace typeface  
CDN: `https://cdn.jsdelivr.net/fontsource/fonts/iosevka@latest/`

Iosevka is used for ALL text in the app: logo, headings, labels, body, values, and buttons. This creates a unified technical aesthetic.

### Font Weights
| Weight | Token    | Usage                              |
|--------|----------|------------------------------------|
| 400    | Regular  | Body text, subtitles, units        |
| 500    | Medium   | Logo tag, secondary labels         |
| 700    | Bold     | Block headers, labels, tags, names |
| 900    | Black    | Logo, headings, values, buttons    |

### Type Scale
| Class       | Size  | Weight | Tracking  | Usage                    |
|-------------|-------|--------|-----------|--------------------------|
| `logo-main` | 52px  | 900    | -2px      | App logo "FTP.TEST"      |
| `logo-tag`  | 11px  | 500    | +4px      | "POWER LAB" subtitle     |
| `value-xl`  | 68px  | 900    | -3px      | FTP result number         |
| `value-lg`  | 52px  | 900    | -2px      | Timer display             |
| `value-md`  | 30px  | 900    | -1px      | Stat card values          |
| `value-sm`  | 18px  | 900    | —         | Mode selection value      |
| `heading-lg`| 22px  | 900    | -1px      | Screen titles             |
| `heading-md`| 20px  | 900    | -0.5px    | Section titles            |
| `label-caps`| 9px   | 700    | +2px      | Block headers, uppercase  |
| `label-sm`  | 9px   | 700    | +1px      | Status text, descriptions |
| `unit`      | 9px   | 400    | +1px      | "Watts", "BPM", "RPM"    |

---

## Logo

### Construction
```
FTP.     ← teal (#0D9488), dot in pink (#EC4899)
TEST     ← teal (#0D9488)
```
- Font: Iosevka Black (900)
- Size: 52px
- Letter-spacing: -2px
- Line-height: 0.92
- The dot (`.`) between FTP and line break is pink — this is the brand mark

### Subtitle
- "POWER LAB" in uppercase
- Iosevka Medium (500), 11px, letter-spacing: 4px
- Color: #ccc

### Logo Clear Space
Maintain at least 1x the height of the "T" character around all sides.

---

## Layout & Components

### Block Component
The primary UI building block. A bordered card with a colored header strip.

```
┌─────────────────────────────┐  ← 3px border, #1a1a1a
│  HEADER LABEL               │  ← colored bg (teal/pink/dark), white text
├─────────────────────────────┤
│                             │
│  Content area               │  ← white background
│                             │
└─────────────────────────────┘  ← border-radius: 14px
```

- Border: 3px solid `#1a1a1a`
- Border-radius: 14px
- Header padding: 10px 16px
- Header font: 9px, bold, uppercase, 2px letter-spacing
- Body padding: 16px
- Margin-bottom: 10px
- Hover: border → yellow-deep, header bg → yellow-deep

### Block Header Colors
| Variant  | Background | Usage                          |
|----------|------------|--------------------------------|
| Teal     | `#0D9488`  | Mode select, timer, power stats|
| Pink     | `#EC4899`  | Pairing, HR stats, FTP result  |
| Dark     | `#1a1a1a`  | Test summary, speed stat       |

### Icon Box
Small bordered square for device/metric icons.
- Size: 36×36px
- Border: 2.5px solid `#1a1a1a`
- Border-radius: 10px
- Colored background per type (trainer: warm yellow, HR: warm pink)

### Tags
Small status indicators.
- Font: 9px bold, 1px letter-spacing
- Padding: 4px 10px
- Border: 2px solid
- Border-radius: 4px
- ON state: teal border + teal text + teal-bg
- OFF state: #ddd border + #ccc text

---

## Buttons

### Core Rule
**All buttons turn yellow on hover.** This is the confirmation pattern — yellow = "yes, this will do something."

### Button Types
| Type     | Default BG  | Default Border | Default Text | Hover BG        |
|----------|-------------|----------------|--------------|-----------------|
| Primary  | `#1a1a1a`   | `#1a1a1a`      | `#fff`       | `#FACC15` (yellow) |
| Teal     | `#0D9488`   | `#0D9488`      | `#fff`       | `#FACC15` (yellow) |
| Pink     | `#EC4899`   | `#EC4899`      | `#fff`       | `#FACC15` (yellow) |
| Outline  | transparent | `#1a1a1a`      | `#1a1a1a`    | `#FACC15` (yellow) |

### Button Specs
- Border: 3px solid
- Border-radius: 14px
- Padding: 17px
- Font: Iosevka Black (900), 16px (primary) or 14px (secondary)
- Active state: scale(0.97)
- All hover borders become `#EAB308` (yellow-deep)
- All hover text becomes `#1a1a1a` (dark)

### Inline Button (e.g. Skip)
- Font: 9px bold, uppercase, 1px letter-spacing
- Padding: 6px 14px
- Border-radius: 6px
- Same yellow hover pattern

---

## Spacing

| Token   | Value | Usage                         |
|---------|-------|-------------------------------|
| `xs`    | 4px   | Tight gaps                    |
| `sm`    | 8px   | Between tags, small gaps      |
| `md`    | 12px  | Block margin-bottom, grid gap |
| `lg`    | 16px  | Block body padding            |
| `xl`    | 20px  | Screen side padding           |
| `2xl`   | 24px  | Overlay padding               |
| `3xl`   | 32px  | Large section spacing         |

Screen content padding: 52px top (for status bar), 22px sides, 32px bottom.

---

## Borders

| Element        | Width  | Color     | Radius |
|----------------|--------|-----------|--------|
| Block          | 3px    | `#1a1a1a` | 14px   |
| Icon box       | 2.5px  | `#1a1a1a` | 10px   |
| Tag            | 2px    | varies    | 4px    |
| Button         | 3px    | varies    | 14px   |
| Phase badge    | 2px    | varies    | 6px    |
| Progress track | 2px    | `#1a1a1a` | 5px    |
| Row separator  | 2px    | `#f0f0f0` | —      |

---

## Screens

### 1. Home Screen
- Logo (FTP.TEST / POWER LAB)
- Mode selector block (teal header)
- Pairing block (pink header) with trainer + HR rows
- Start Test button (primary/dark)

### 2. Test Running Screen
- Title bar with phase badge (warmup/testing)
- Timer block (teal header)
- Warmup bar with skip button (shown during warmup)
- 2×2 stat grid (power, HR, cadence, speed)
- Progress bar
- Stop Test (pink) + Finish & Calculate (outline) buttons

### 3. Result Screen
- "Test Complete" badge (teal)
- FTP result block (pink header, large value)
- Avg HR + Duration stat cards
- Test Summary detail block (dark header, row list)
- Save Result (teal) + Back to Home (outline) buttons

### Mode Selector Overlay
- Bottom sheet with backdrop
- Border-radius: 18px top corners
- Options as bordered cards
- Selected: teal border + teal bg
- Hover: yellow border + yellow bg tint

---

## Interaction Patterns

### Hover Feedback
Yellow confirmation appears on:
- Buttons (bg turns yellow)
- Interactive blocks (border + header turn yellow)
- Overlay options (border + bg tint turn yellow)
- Close buttons (bg turns yellow)
- Inline buttons like Skip (bg turns yellow)

### Transitions
- Block hover: `transform 0.12s ease, border-color 0.2s ease`
- Button hover: `all 0.2s ease`
- Screen transitions: `opacity 0.35s ease, transform 0.35s ease`
- Overlay: `opacity 0.25s ease` (backdrop), `transform 0.3s ease` (panel)

### Animations
- Phase badge pulse: `opacity 1→0.5→1` over 2s (warmup only)
- Live stat values: updated every 1s with simulated sensor data
- Progress bar: smooth width transition

---

## File Structure

```
ftptest-design/
├── clickdummy/
│   └── index.html          ← Interactive prototype (all 3 screens)
├── assets/
│   └── design-system.css   ← Full CSS with tokens + components
├── docs/
│   ├── design-guideline.md ← This file
│   └── color-schema.md     ← Color reference + usage rules
└── README.md               ← Project overview
```
