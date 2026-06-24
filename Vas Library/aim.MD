
---

# AimLibrary Documentation 📐

**A lightweight, feature‑rich aim assist module for Roblox exploits.**  
Designed to work seamlessly with [espLibrary](#), or standalone.

---

## Table of Contents
- [Overview](#overview)
- [Features](#features)
- [Installation](#installation)
- [Configuration Options](#configuration-options)
- [API Reference](#api-reference)
- [Integration with espLibrary](#integration-with-esplibrary)
- [Mobile Support](#mobile-support)
- [Examples](#examples)

---

## Overview

`AimLibrary` is a flexible aimbot (aim assist) that lets you:

- Automatically lock onto enemy players.
- Smoothly move your mouse or camera towards the target.
- Filter targets by **FOV**, **team**, **visibility**, **distance**, and more.
- Randomize which body part you aim at using **weighted distribution** (e.g., 70% head, 30% torso).
- Support both **PC** (mouse) and **mobile** (touch) devices out of the box.

It’s built to be modular and can be used with or without `espLibrary`.

---

## Features

| Feature | Description |
|---------|-------------|
| **Aim Modes** | `Mouse` (moves cursor) or `Camera` (silent aim). Auto‑detects mobile and falls back to `Camera`. |
| **FOV Filtering** | Restricts aiming to targets within a configurable field‑of‑view cone. |
| **Smoothness** | Interpolates the aim movement for a natural feel. |
| **Team Check** | Avoids aiming at teammates (uses `Team` property). |
| **Visibility Check** | Only aims at targets not occluded by walls (raycast). |
| **Target Lock** | Stays locked on a target until dead or out of range. |
| **Prediction** | Leads moving targets based on velocity. |
| **Weighted Aim‑Part Distribution** | Assign weights to different body parts (e.g., `Head = 70, Torso = 30`) and aim randomly per target or per frame. |
| **Key Bindings** | Hold‑to‑aim and toggle keys. |
| **Blacklist/Whitelist** | Integrates with `espLibrary`’s blacklist/whitelist (if available). |
| **Mobile Ready** | Automatically uses `Camera` mode when touch is detected. |

---

## Installation

1. Place the `aimLibrary.lua` file in your script’s path.
2. Require it:

```lua
local aimLibrary = require(script.Parent.aimLibrary)
```

> **Note:** If you plan to use it with `espLibrary`, load `espLibrary` first and pass it to `aimLibrary:Load()`.

---

## Configuration Options

All options are stored in `aimLibrary.options`. You can modify them directly or use `aimLibrary:SetOption(key, value)`.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enabled` | `boolean` | `true` | Master toggle. |
| `aimMode` | `string` | `"Mouse"` (PC) / `"Camera"` (mobile) | `"Mouse"` or `"Camera"`. |
| `aimPart` | `string` | `"Head"` | Default part if distribution is disabled. |
| `aimPartDistribution` | `table` | `{ Head = 70, Torso = 30 }` | Weighted table of part names → weights. |
| `aimPartDistributionEnabled` | `boolean` | `false` | Enable weighted random part selection. |
| `aimPartRandomizePerShot` | `boolean` | `false` | If `true`, re‑roll part every frame; otherwise stick per target. |
| `fov` | `number` | `90` | Field‑of‑view in degrees (0 = unlimited). |
| `fovVisible` | `boolean` | `false` | (Future) Draw FOV circle. |
| `smoothness` | `number` | `10` | Number of interpolation steps (higher = smoother). |
| `maxSmoothDistance` | `number` | `200` | If distance to target > this, snap instantly. |
| `teamCheck` | `boolean` | `true` | Avoid teammates. |
| `visibleOnly` | `boolean` | `true` | Only aim if target is visible. |
| `lockTarget` | `boolean` | `false` | Stay locked on target until dead/out of range. |
| `keyToAim` | `Enum.KeyCode` | `nil` | Hold key to activate aim (e.g., `Enum.KeyCode.LeftControl`). |
| `keyToggle` | `Enum.KeyCode` | `nil` | Press key to toggle aim on/off. |
| `prediction` | `boolean` | `false` | Lead moving targets. |
| `predictionMultiplier` | `number` | `1` | Strength of prediction. |
| `maxDistance` | `number` | `1000` | Ignore targets beyond this distance. |
| `ignoreBlacklist` | `boolean` | `true` | Use `espLibrary` blacklist. |
| `ignoreWhitelist` | `boolean` | `false` | If `true`, only aim at whitelisted players (requires `espLibrary`). |
| `aimAtDowned` | `boolean` | `false` | (Future) Aim at downed players. |
| `boneNames` | `table` | `{"Head","UpperTorso","LowerTorso","HumanoidRootPart"}` | Fallback parts to search for. |

---

## API Reference

### `aimLibrary:Load(renderPriority, espLibrary)`
Initializes the aimbot.

- **`renderPriority`** (optional) – Render priority (default: `Enum.RenderPriority.Camera.Value + 2`).
- **`espLibrary`** (optional) – Pass an `espLibrary` instance to reuse team/visibility/blacklist functions.

### `aimLibrary:Unload()`
Stops the aimbot and cleans up connections.

### `aimLibrary:SetOption(key, value)`
Safely updates an option.

### `aimLibrary:Toggle()`
Toggles `enabled` state.

### `aimLibrary:IsMobile()`
Returns `true` if the device uses touch and no mouse.

### `aimLibrary:GetTarget()`
Returns the current target player and the chosen aim part (for debugging). Usually called internally.

### `aimLibrary:GetRandomAimPart(character)`
Given a character, returns a part based on the weighted distribution.

---

## Integration with espLibrary

When you pass an `espLibrary` instance to `Load()`, `aimLibrary` will automatically use:

- `espLibrary.getTeam()` – team and team color.
- `espLibrary.visibleCheck()` – more accurate visibility detection.
- `espLibrary.blacklist` / `whitelist` – for filtering players.

This ensures consistent behavior between ESP and aimbot.

---

## Mobile Support

- The library detects mobile via `UserInputService.TouchEnabled` and `not UserInputService.MouseEnabled`.
- On mobile, `aimMode` is automatically set to `"Camera"` to avoid mouse‑related errors.
- If you manually set `aimMode = "Mouse"` on mobile, it gracefully falls back to `"Camera"`.

---

## Examples

### Basic Setup (Standalone)

```lua
local aimLibrary = require(script.Parent.aimLibrary)
aimLibrary:Load()
```

### With espLibrary

```lua
local espLibrary = require(script.Parent.espLibrary)
local aimLibrary = require(script.Parent.aimLibrary)

espLibrary:Load()
aimLibrary:Load(nil, espLibrary)  -- pass espLibrary instance
```

### Weighted Aim‑Part Distribution

```lua
aimLibrary:SetOption("aimPartDistributionEnabled", true)
aimLibrary:SetOption("aimPartDistribution", {
    Head = 70,
    Torso = 20,
    UpperTorso = 10,
})
aimLibrary:SetOption("aimPartRandomizePerShot", false)  -- stick per target
```

### Key Bindings

```lua
-- Hold LeftControl to aim
aimLibrary:SetOption("keyToAim", Enum.KeyCode.LeftControl)

-- Press F to toggle aim on/off
aimLibrary:SetOption("keyToggle", Enum.KeyCode.F)
```

### Custom Smoothness & FOV

```lua
aimLibrary:SetOption("smoothness", 15)
aimLibrary:SetOption("fov", 60)
aimLibrary:SetOption("maxSmoothDistance", 300)
```

---

## Notes & Tips

- **Prediction** assumes a constant bullet travel time (`distance / 1000`). Adjust `predictionMultiplier` per game.
- **VisibleOnly** uses a raycast from the camera to the target part. It may not work perfectly with all game geometries.
- The weighted distribution uses the part with the highest weight for **FOV screening**. This ensures consistent targeting.
- For **mouse aiming**, ensure your exploit supports `UserInputService:SetMouseLocation()`.
- **Camera aiming** (silent aim) may be more detectable; use responsibly.

---

## License

This library is provided as‑is. Feel free to modify and distribute.

---
Happy aiming! 🎯
---

**How to use:**  
- Copy the block above into a new file and save it as `aimLibraryDocs.lua` (or any name you like).  
- If you want to include the documentation inside your `aimLibrary.lua` file, simply paste this comment block at the very top of that file.  

You now have a Lua file containing the full markdown documentation as a comment – ready to download and keep alongside your library.
