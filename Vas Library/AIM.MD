
---

## Loading

```lua
local aimLibrary = loadstring(game:HttpGet(""))()
aimLibrary:Load() -- or aimLibrary:Load(nil, espLibrary)
```

Call `:Load()` to start the aim loop. Optionally pass your `espLibrary` instance for better team/visibility integration. Call `:Unload()` to stop.

---

## Options

All options live in `aimLibrary.options`. Change them at any time.

### General

| Option | Type | Default | Description |
|---|---|---|---|
| `enabled` | bool | `true` | Master toggle |
| `aimMode` | string | `"Mouse"` (PC) / `"Camera"` (Mobile) | `"Mouse"` or `"Camera"` |
| `aimPart` | string | `"Head"` | Primary aim part (Head, Torso, HumanoidRootPart, etc.) |
| `aimPartDistribution` | table | `{ Head = 70, Torso = 30 }` | Weighted random part selection |
| `aimPartDistributionEnabled` | bool | `false` | Enable weighted random aiming |
| `aimPartRandomizePerShot` | bool | `false` | Re-randomize part every frame while aiming |
| `fov` | number | `90` | FOV radius in degrees (0 = unlimited) |
| `fovVisible` | bool | `false` | Show FOV circle (requires drawing setup) |
| `smoothness` | number | `10` | Smoothing steps (1 = instant) |
| `maxSmoothDistance` | number | `200` | Distance threshold for instant aim |
| `teamCheck` | bool | `true` | Skip teammates |
| `visibleOnly` | bool | `true` | Only target visible players |
| `lockTarget` | bool | `false` | Stick to current target until lost |
| `keyToAim` | Enum.KeyCode\|nil | `nil` | Hold key to aim |
| `keyToggle` | Enum.KeyCode\|nil | `nil` | Toggle enabled state |
| `prediction` | bool | `false` | Velocity prediction |
| `predictionMultiplier` | number | `1` | Prediction strength |
| `maxDistance` | number | `1000` | Max target distance in studs |
| `ignoreBlacklist` | bool | `true` | Skip blacklisted players from espLibrary |
| `ignoreWhitelist` | bool | `false` | Only target whitelisted players from espLibrary |
| `aimAtDowned` | bool | `false` | Target downed players |
| `boneNames` | table | `{"Head", "UpperTorso", "LowerTorso", "HumanoidRootPart"}` | Fallback part names |

### Integration

The library automatically detects and uses `espLibrary` if passed to `:Load()` for:
- Better team color detection
- Consistent visibility checks

---

## API

### `:Load(renderPriority?, espLib?)`
Starts the aim loop. 
- `renderPriority`: Custom `Enum.RenderPriority` (default: Camera + 2)
- `espLib`: Your loaded `espLibrary` instance

### `:Unload()`
Stops the aim loop and cleans up connections.

### `:Toggle()`
Flips `options.enabled`.

### `:SetOption(key, value)`
Safe setter that validates the key exists.
```lua
aimLibrary:SetOption("fov", 120)
aimLibrary:SetOption("smoothness", 5)
aimLibrary:SetOption("prediction", true)
```

### `:GetTarget()`
Returns `(player, aimPart)` of the current best target or `(nil, nil)`.

### `:IsMobile()`
Returns `true` if running on mobile/touch device.

---

## Whitelist & Blacklist

Works with `espLibrary`:
```lua
espLibrary.whitelist = { "PlayerName" }   -- only aim at these if ignoreWhitelist = true
espLibrary.blacklist = { "PlayerName" }   -- ignore these if ignoreBlacklist = true
```

---

## Example

```lua
local espLibrary = loadstring(game:HttpGet("ESP_RAW_URL"))()
local aimLibrary = loadstring(game:HttpGet("AIM_RAW_URL"))()

espLibrary:Load()
aimLibrary:Load(nil, espLibrary) -- pass espLibrary for best integration

aimLibrary.options.teamCheck = true
aimLibrary.options.visibleOnly = true
aimLibrary.options.smoothness = 8
aimLibrary.options.prediction = true
aimLibrary.options.aimPartDistributionEnabled = true
aimLibrary.options.fov = 80

-- Toggle with RightShift
game:GetService("UserInputService").InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == Enum.KeyCode.RightShift then
        aimLibrary:Toggle()
    end
end)
```

---

**Note**: This library is designed to work alongside `espLibrary`. While they can be used independently, passing the ESP instance to `:Load()` provides the best consistency for team checks and visibility. 
```
