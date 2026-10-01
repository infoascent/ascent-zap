# Ascent Zap

Menu bar app for macOS: **zero blue light, no PWM flicker.** Clone of Tap Zap, free.

- **WARMTH** fader: 6500K (neutral) down to **0K, pure red** (R=1, G=0, B=0). Chromaticity-based CIE curve
  (Kim et al. Planckian locus to sRGB), smooth red tail from 2000K to 0K.
- **BRIGHTNESS** fader: software dimming through gamma tables, floor 10%.
- **DAY / EVENING / NIGHT** presets: 4000K, 2700K, 0K. Slider glides to the preset; a preset lights up within 2%.
- **PWM-SAFE MODE**: pins the hardware backlight of Apple panels (built-in, Studio Display, Pro Display XDR) at 100%
  through the private DisplayServices framework, re-pins every 2 s, holds auto-brightness off while running.
  Hidden behind a "set brightness to 100%" tip when no display is controllable. Honest flicker warning
  (amber dot below 100%, red below 80%).
- **ZAP** toggles the filter. Menu bar bolt is red when on, monochrome when off.
- All displays, hot-plug, sleep/wake re-apply, re-assert if another app overwrites gamma.
- Everything reverts the instant the app quits (also on SIGTERM).
- Settings: launch at login, global hotkey ⌃⌥⌘Z, copy feedback for support, restore true colors, quit.
- Screenshots and screen shares are not tinted (gamma is applied after capture).

## Build

```bash
./build.sh          # universal arm64 + x86_64, ad-hoc signed, macOS 12+
open "build/Ascent Zap.app"
```

Output: `build/Ascent Zap.app` and `build/AscentZap-mac.dmg`. Only the Xcode Command Line Tools are needed.

`AscentZap --snapshot <dir>` renders the popover states to PNG for design QA without touching the displays.

Fonts: Anybody and JetBrains Mono (SIL Open Font License), bundled in `Resources/Fonts`.
