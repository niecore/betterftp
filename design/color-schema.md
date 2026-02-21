# FTP.TEST — Color Schema

## Overview

The design uses a strict 3-color system with clear roles:
- **Teal** → Primary / data / structure
- **Pink** → Secondary / accent / health metrics
- **Yellow** → Confirmation only (hover states, never at rest)

---

## Color Palette

### Teal (Primary)
| Token              | Hex       | Usage                                           |
|--------------------|-----------|--------------------------------------------------|
| `teal`             | `#0D9488` | Block headers, power stats, connected states, progress bar, badges |
| `teal-dark`        | `#0F766E` | Hover darkened teal, cadence stat header          |
| `teal-light`       | `#5EEAD4` | Dark-mode text variant (reserved)                 |
| `teal-bg`          | `rgba(13,148,136,0.06)` | Tag backgrounds, selected option background |

### Pink (Secondary)
| Token              | Hex       | Usage                                           |
|--------------------|-----------|--------------------------------------------------|
| `pink`             | `#EC4899` | Pairing header, HR stats, logo dot, stop button, FTP result header |
| `pink-dark`        | `#DB2777` | Hover darkened pink (reserved)                    |
| `pink-light`       | `#F9A8D4` | Dark-mode text variant (reserved)                 |
| `pink-bg`          | `rgba(236,72,153,0.06)` | Warmup phase badge background          |

### Yellow (Confirm — Hover Only)
| Token              | Hex       | Usage                                           |
|--------------------|-----------|--------------------------------------------------|
| `yellow`           | `#FACC15` | Hover background for buttons and blocks           |
| `yellow-deep`      | `#EAB308` | Hover border color, deeper accent                 |
| `yellow-light`     | `#FDE047` | Reserved for lighter accents                      |
| `yellow-bg`        | `rgba(234,179,8,0.08)` | Hover background tint on overlay options  |

**RULE: Yellow must NEVER appear at rest. It only appears on `:hover` or `:active` states as visual confirmation that an element is interactive.**

### Neutrals
| Token              | Hex       | Usage                                           |
|--------------------|-----------|--------------------------------------------------|
| `dark`             | `#1a1a1a` | Borders, primary button default, text, block borders |
| `dark-soft`        | `#333333` | Secondary dark (reserved)                         |
| `bg`               | `#F5F5F0` | Page/app background                               |
| `card`             | `#FFFFFF` | Card/block body backgrounds                       |
| `muted`            | `#AAAAAA` | Placeholder text, subtitles, units                |
| `border-light`     | `#F0F0F0` | Separator lines between rows                      |

### Semantic Icon Backgrounds
| Token              | Hex       | Usage                    |
|--------------------|-----------|--------------------------|
| `trainer-bg`       | `#FEF3C7` | Trainer icon background  |
| `hr-bg`            | `#FCE7F3` | Heart rate icon bg       |
| `cadence-bg`       | `#F0FDF4` | Cadence icon bg          |
| `speed-bg`         | `#E0F2FE` | Speed icon bg            |

---

## Color Role Rules

### Teal is used for:
- Mode selector block header
- Power stat card header
- Cadence stat card header (darker variant)
- Timer block header
- Duration stat header
- "Test Complete" badge
- FTP change indicator border/text
- Connected status text
- ON tag
- Progress bar fill
- Save Result button (default)

### Pink is used for:
- Pairing block header
- Heart rate stat card header
- Estimated FTP result header
- Average HR stat header
- Stop Test button (default)
- Warmup phase badge
- Logo dot (`.`)

### Yellow is used for:
- Button `:hover` state (all button types turn yellow on hover)
- Block `:hover` border (border goes yellow-deep)
- Block header `:hover` (header bg turns yellow-deep, text goes dark)
- Skip button `:hover`
- Overlay option `:hover` (border + background tint)
- Close button `:hover`
- Logo color bar (subtle brand hint — only static decorative use)

### Dark is used for:
- All block borders (3px solid)
- All icon borders (2.5px solid)
- Primary button default state
- Speed stat card header
- Test Summary block header
- Body text color
- Overlay option borders

---

## Accessibility Notes

- Teal on white: contrast ratio ~4.6:1 (AA for large text)
- Pink on white: contrast ratio ~3.5:1 (AA for large text)
- Dark on white: contrast ratio ~16:1 (AAA)
- Yellow on dark: contrast ratio ~10.5:1 (AAA)
- All interactive elements have visible hover feedback (yellow)
