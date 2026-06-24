# espLibrary

A lightweight, performant Roblox ESP library with player boxes, health bars, skeletons, chams, tracers, out-of-view arrows, and object ESP.

---

## Loading

```lua
local espLibrary = loadstring(game:HttpGet("YOUR_RAW_URL"))()
espLibrary:Load()
```

Call `:Load()` once to start rendering. Call `:Unload()` to stop and clean up all drawings.

---

## Options

All options live in `espLibrary.options`. Change them at any time — they take effect on the next frame.

### General

| Option | Type | Default | Description |
|---|---|---|---|
| `enabled` | bool | `true` | Master toggle for all ESP |
| `limitDistance` | bool | `false` | Hide players beyond `maxDistance` |
| `maxDistance` | number | `1000` | Max render distance in studs |
| `visibleOnly` | bool | `false` | Only show players with line-of-sight |
| `teamCheck` | bool | `false` | Hide teammates |
| `teamColor` | bool | `false` | Use team color instead of custom colors |
| `fillColor` | Color3\|nil | `nil` | Override all colors with a single color |

### Scaling

| Option | Type | Default | Description |
|---|---|---|---|
| `scaleFactorX` | number | `5` | Box width scale (non-bounding-box mode) |
| `scaleFactorY` | number | `6` | Box height scale (non-bounding-box mode) |
| `minScaleFactorX` | number | `1` | Minimum box width |
| `maxScaleFactorX` | number | `10` | Maximum box width |
| `minScaleFactorY` | number | `1` | Minimum box height |
| `maxScaleFactorY` | number | `10` | Maximum box height |
| `boundingBox` | bool | `false` | Use accurate per-part bounding box ⚠️ performance heavy |
| `boundingBoxDescending` | bool | `true` | Use `GetDescendants` instead of `GetChildren` for bounding box |
| `excludedPartNames` | table | `{}` | Part names to skip in bounding box calculation |

### Names

| Option | Type | Default | Description |
|---|---|---|---|
| `names` | bool | `true` | Show name above box |
| `namesShowDisplayName` | bool | `false` | Show DisplayName instead of username |
| `nameColor` | Color3 | white | Name text color |
| `nameTransparency` | number | `1` | `0` = invisible, `1` = fully visible |
| `font` | number | `2` | Drawing font index |
| `fontSize` | number | `13` | Drawing font size |

### Boxes

| Option | Type | Default | Description |
|---|---|---|---|
| `boxes` | bool | `true` | Show bounding box outline |
| `boxesColor` | Color3 | red | Box outline color |
| `boxesTransparency` | number | `1` | Box outline transparency |
| `boxFill` | bool | `false` | Fill box with color |
| `boxFillColor` | Color3 | red | Box fill color |
| `boxFillTransparency` | number | `0.5` | Box fill transparency |

### Health

| Option | Type | Default | Description |
|---|---|---|---|
| `healthBars` | bool | `true` | Show health bar to the left of the box |
| `healthBarsSize` | number | `1` | Health bar width in pixels |
| `healthBarsColor` | Color3 | green | Health bar color |
| `healthBarsTransparency` | number | `1` | Health bar transparency |
| `healthText` | bool | `true` | Show health value to the right of the box |
| `healthTextColor` | Color3 | white | Health text color |
| `healthTextTransparency` | number | `1` | Health text transparency |
| `healthTextSuffix` | string | `"%"` | Appended to health value |

### Distance

| Option | Type | Default | Description |
|---|---|---|---|
| `distance` | bool | `true` | Show distance below box |
| `distanceColor` | Color3 | white | Distance text color |
| `distanceTransparency` | number | `1` | Distance text transparency |
| `distanceSuffix` | string | `" Studs"` | Appended to distance value |

### Tracers

| Option | Type | Default | Description |
|---|---|---|---|
| `tracers` | bool | `false` | Draw a line from screen origin to player |
| `tracerOrigin` | string | `"Bottom"` | Line start: `"Bottom"`, `"Top"`, or `"Mouse"` |
| `tracerColor` | Color3 | white | Tracer line color |
| `tracerTransparency` | number | `1` | Tracer line transparency |

### Skeleton

| Option | Type | Default | Description |
|---|---|---|---|
| `skeletonLines` | bool | `false` | Draw R15 skeleton lines between joints |
| `skeletonColor` | Color3 | white | Skeleton line color |
| `skeletonTransparency` | number | `0.5` | Skeleton line transparency |

### Out-of-View Arrows

| Option | Type | Default | Description |
|---|---|---|---|
| `outOfViewArrows` | bool | `true` | Show arrow pointing toward off-screen players |
| `outOfViewArrowsFilled` | bool | `true` | Fill the arrow triangle |
| `outOfViewArrowsSize` | number | `25` | Arrow size in pixels |
| `outOfViewArrowsRadius` | number | `100` | Distance from screen center |
| `outOfViewArrowsColor` | Color3 | white | Arrow fill color |
| `outOfViewArrowsTransparency` | number | `0.5` | Arrow transparency |
| `outOfViewArrowsOutline` | bool | `true` | Show arrow outline |
| `outOfViewArrowsOutlineFilled` | bool | `false` | Fill arrow outline |
| `outOfViewArrowsOutlineColor` | Color3 | white | Arrow outline color |
| `outOfViewArrowsOutlineTransparency` | number | `1` | Arrow outline transparency |

### Chams (Highlight)

| Option | Type | Default | Description |
|---|---|---|---|
| `chams` | bool | `true` | Show character highlight (visible through walls) |
| `chamsFillColor` | Color3 | red | Highlight fill color |
| `chamsFillTransparency` | number | `0.5` | Highlight fill transparency |
| `chamsOutlineColor` | Color3 | black | Highlight outline color |
| `chamsOutlineTransparency` | number | `0` | Highlight outline transparency |

---

## Whitelist & Blacklist

```lua
espLibrary.whitelist = { "PlayerName" } -- shown in whitelistColor
espLibrary.blacklist = { "PlayerName" } -- hidden entirely

espLibrary.options.whitelistColor = Color3.fromRGB(255, 0, 0)
```

---

## API

### `:Load(renderPriority?)`
Starts the render loop. Optionally pass a custom `Enum.RenderPriority` value.

### `:Unload()`
Stops rendering and destroys all drawings and connections.

### `:Toggle()`
Flips `options.enabled`.

### `:SetOption(key, value)`
Safe option setter — throws if the key doesn't exist.
```lua
espLibrary:SetOption("boxes", false)
espLibrary:SetOption("maxDistance", 300)
```

### `:IsPlayerVisible(player)`
Returns `true` if the player's root part has line-of-sight from the camera.
```lua
if espLibrary:IsPlayerVisible(game.Players.SomePlayer) then
    print("visible")
end
```

### `:AddObjectEsp(object, options?) -> options`
Attaches a text label to any `BasePart` or `Model` in the workspace.
```lua
local opts = espLibrary:AddObjectEsp(workspace.Chest, {
    color    = Color3.fromRGB(255, 215, 0),
    text     = "Chest",
    fontSize = 14,
})
```

| Field | Type | Default |
|---|---|---|
| `enabled` | bool | `true` |
| `color` | Color3 | white |
| `transparency` | number | `1` |
| `text` | string | `object.Name` |
| `font` | number | `2` |
| `fontSize` | number | `13` |
| `limitDistance` | bool | `false` |
| `maxDistance` | number | `false` |
| `visibleOnly` | bool | `false` |

The returned table is a live reference — mutate it to update the label at any time.

---

## Example

```lua
local espLibrary = loadstring(game:HttpGet("YOUR_RAW_URL"))()

espLibrary.options.teamCheck   = true
espLibrary.options.skeletonLines = true
espLibrary.options.chams       = true
espLibrary.options.tracers     = true
espLibrary.options.tracerOrigin = "Bottom"

espLibrary:Load()

game:GetService("UserInputService").InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == Enum.KeyCode.RightShift then
        espLibrary:Toggle()
    end
end)
```
