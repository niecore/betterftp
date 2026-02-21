# FTP.TEST Design System

**App:** FTP.TEST — Power Lab  
**Domain:** ftptests.icu  
**Version:** 1.0  
**Style:** Bold retro / boxy 2000s, full Iosevka monospace  

---

## Quick Start

1. Open `clickdummy/index.html` in a browser for the interactive prototype
2. Read `docs/design-guideline.md` for full design specs
3. Reference `docs/color-schema.md` for color values and usage rules
4. Import `assets/design-system.css` in your project for tokens + components

---

## 3-Color System

| Color  | Hex       | Role                                |
|--------|-----------|-------------------------------------|
| Teal   | `#0D9488` | Primary — data, structure, power    |
| Pink   | `#EC4899` | Secondary — accent, health metrics  |
| Yellow | `#FACC15` | Confirm — hover states ONLY         |

**Key rule:** Yellow never appears at rest. It only shows on `:hover` as confirmation feedback.

---

## Font

**Iosevka** (monospace) — weights 400, 500, 700, 900  
Used for ALL text: logo, headings, labels, body, values, buttons.

CDN:
```css
@font-face {
  font-family: 'Iosevka';
  src: url(https://cdn.jsdelivr.net/fontsource/fonts/iosevka@latest/latin-{weight}-normal.woff2) format('woff2');
}
```

---

## Screens

1. **Home** — Logo, mode selector, device pairing, start button
2. **Test Running** — Timer, live stats (power/HR/cadence/speed), progress bar
3. **Result** — FTP value, comparison, detailed summary

---

## File Structure

```
ftptest-design/
├── README.md                ← This file
├── clickdummy/
│   └── index.html           ← Interactive 3-screen prototype
├── assets/
│   └── design-system.css    ← CSS tokens + component classes
└── docs/
    ├── design-guideline.md  ← Full design specs & rules
    └── color-schema.md      ← Color palette & usage reference
```
