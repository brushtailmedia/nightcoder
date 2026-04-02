# NightCoder

A minimal macOS menu bar app for developers who spend long hours in front of a screen.

## Why

I built NightCoder to help with eye strain during my coding work. Whether I'm coding in nvim, browsing documentation, or watching the occasional tutorial video, I can do so without feeling like my eyes are being burned out of my skull. It features an easy-to-revert color filter, so anytime I need to jump into design software or anything else where I need accurate colors, I can quickly flip it using the hotkey, disable button or by moving the sliders in the menu bar app back to the top.

The warmth slider cuts blue light, which is the main cause of eye fatigue during late-night sessions. The brightness slider caps harsh whites — the real culprit behind squinting and eye strain during long stints at the computer. The contrast slider softens the gap between dark and light areas on screen, reducing the constant pupil adjustment that comes from scanning between bright UI elements and dark editor backgrounds.

No dock icon, no window, no bloat. Just a moon in your menu bar. Three sliders give you independent control over warmth, brightness, and contrast, and a global hotkey and disable button let you instantly disable the filter when you need true colors for design work.

NightCoder is designed to be as unobtrusive as possible while still giving you powerful control over your display's color output.

## Features

- **Three sliders** — Warmth (blue light reduction), Brightness (caps max output), and Contrast (softens darks)
- **Menu bar icon** — moon when inactive, filled moon when filter is active
- **Global hotkey** — `Ctrl+Option+N` to toggle on/off instantly
- **Remembers your setting** between launches
- **Multi-display support** — handles plug/unplug automatically
- **Clean exit** — restores original display colors on quit or crash
- **No permissions required** — manipulates gamma tables directly, no accessibility access needed

## How it works

NightCoder adjusts your display's gamma lookup tables via CoreGraphics. This works system-wide — every pixel on screen is affected, whether it's your terminal, browser, Finder, or a video. The filter multiplies against your existing gamma curve, preserving any ICC calibration you have in place.

**Warmth** reduces blue light aggressively and green moderately to produce a warm tone that's easy on the eyes. Red is left untouched as it has the lowest impact on eye strain:

| Channel | Max reduction |
|---------|---------------|
| Blue    | 80%           |
| Green   | 45%           |
| Red     | 0%            |

**Brightness** caps the maximum output value, taming harsh whites and bright UI elements. At full effect it reduces peak brightness to 50%. This is the single biggest thing for reducing eye strain during long sessions — a `#ffffff` background becomes significantly less aggressive without making dark content unreadable.

**Contrast** raises the black point, lifting the darkest values on screen. At full effect it raises the floor to 20%. This reduces the harsh gap between dark backgrounds and bright text or UI elements, so your pupils aren't constantly adjusting as you scan the screen.

All three sliders are independent. Top position = stock display, bottom = max effect. Use warmth alone for late-night sessions, brightness alone to cut glare during the day, contrast to soften dark themes, or any combination for maximum comfort.

## Compatibility

macOS 13 (Ventura) and later — including Sonoma and Sequoia.

## Build

Requires Swift (included with Xcode or Command Line Tools).

```
make build
```

## Run

```
make run
```

## Install

```
make install
```

Copies `NightCoder.app` to `/Applications`.

**Note:** The "Launch at Login" checkbox requires the app to be running as a proper `.app` bundle with a valid bundle identifier. It will only take effect when installed via `make install` and launched from `/Applications`. Running the bare binary via `make run` will silently skip the login item registration.

## Uninstall

```
make uninstall
```

## License

MIT
