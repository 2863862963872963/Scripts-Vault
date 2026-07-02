
A comprehensive Roblox utility script providing ESP, Aimbot, Triggerbot, Radar, and other visual enhancements.  
**For educational purposes only.** Use at your own risk – violates Roblox ToS and may result in account bans.

---

## Features

### 👁️ ESP
- **Box**: 2D, 3D, or corner box around targets
- **Tracer**: Lines from screen edge to target  
- **Name** & **Distance** display  
- **HealthBar**: Color‑coded (green→yellow→red)  
- **Skeleton**: R6/R15 bone rendering  
- **LookVector**: Head orientation indicator  
- **Highlight**: Glow effect on target model  
- **Off‑Screen Indicators**: Arrows for targets outside view  

### 🎯 Aimbot
- Modes: **Hold** (key) or **Always**  
- Custom activation key (mouse or keyboard)  
- Priority: **Mouse** (closest to crosshair), **Distance**, or **Health**  
- Smooth aiming with configurable speed  
- FOV circle display  
- Prediction based on target velocity  
- Distance‑based offsets  
- Blacklist (break key) to ignore current target temporarily  

### 🔫 Triggerbot
- Configurable hit chance threshold (%)  
- Filter by hitbox (Head, UpperTorso, etc.)  
- Adjustable firing delay  

### 🗺️ Radar
- Mini‑radar with adjustable position and radius  

### 🎨 Other
- Custom crosshair  
- FOV circle  

---

## Configuration

```lua
local VasGG = loadstring(game:HttpGet("https://raw.githubusercontent.com/2863862963872963/Scripts-Vault/refs/heads/main/Vas%20Library/b.lua"))()
```

All settings are stored in `VasGG.Options`. Below are the most common ones – see the script for the full list.

```lua
local VasGG = loadstring(game:HttpGet("https://raw.githubusercontent.com/2863862963872963/Scripts-Vault/refs/heads/main/Vas%20Library/b.lua"))()

-- Enable / disable the entire system
VasGG.Options.Enabled = true

-- Team check (skip teammates)
VasGG.Options.TeamCheck = false

-- Maximum detection distance (studs)
VasGG.Options.MaxDistance = 1000

-- ESP toggles
VasGG.Options.Box = true
VasGG.Options.BoxType = "2D"          -- "2D", "3D", "Corner"
VasGG.Options.Tracer = false
VasGG.Options.Name = true
VasGG.Options.Distance = true
VasGG.Options.HealthBar = true
VasGG.Options.Skeleton = false
VasGG.Options.Highlight = false

-- Aimbot settings
VasGG.Options.Aimbot = false
VasGG.Options.AimMode = "Hold"        -- "Hold" or "Always"
VasGG.Options.AimKey = Enum.UserInputType.MouseButton2  -- right mouse
VasGG.Options.AimFOV = 100            -- pixels
VasGG.Options.AimSmoothness = 0.15    -- 0..1
VasGG.Options.AimPriority = "Mouse"   -- "Mouse", "Distance", "Health"
VasGG.Options.AimPrediction = false
VasGG.Options.AimPredictionFactor = 0.165

-- Aim part weights (table of {Part, Rate})
VasGG.Options.AimPartRate = {
    {Part = "Head", Rate = 70},
    {Part = "UpperTorso", Rate = 30}
}

-- Triggerbot
VasGG.Options.Triggerbot = false
VasGG.Options.TriggerbotHitchance = 100
VasGG.Options.TriggerbotHitboxes = {"Head", "UpperTorso"}

-- Radar
VasGG.Options.Radar = false
VasGG.Options.RadarPosition = Vector2.new(200, 200)
VasGG.Options.RadarRadius = 75

VasGG.AddPlayers()   -- auto‑adds all players (current + future)
VasGG.Init()
VasGG.InitAimbot()   -- if you need aimbot

```

---

## API Reference

| Method | Parameters | Description |
|--------|------------|-------------|
| `VasGG.Init()` | – | Starts the ESP update loop |
| `VasGG.InitAimbot()` | – | Starts the aimbot loop (optional) |
| `VasGG.Destroy()` | – | Clears all drawings and disconnects events |
| `VasGG.AddPlayers()` | – | Adds ESP to all current and future players |
| `VasGG.AddPlayer(player)` | `player` (Player) | Adds ESP to a single player |
| `VasGG.AddNPCsByTag(tag)` | `tag` (string) | Adds ESP to models with a specific tag |
| `VasGG.new(target, espType)` | `target`, `espType` | Creates a new ESP object for a target |

---

## Quick Use

1. **Load the script** into your Roblox executor (e.g., Synapse, Krnl, etc.).
2. **Add targets** – most games use players:
   ```lua
   VasGG.AddPlayers()   -- auto‑adds all players (current + future)
   ```
   For NPCs with a specific tag:
   ```lua
   VasGG.AddNPCsByTag("Enemy")
   ```
3. **Customise options** (as shown above) before calling `Init()`.
4. **Start the system**:
   ```lua
   VasGG.Init()
   VasGG.InitAimbot()   -- if you need aimbot
   ```
5. **Use the defaults** – by default ESP (boxes, names, health, distance) is enabled.  
   Toggle options anytime; changes apply immediately.
6. **To stop everything**:
   ```lua
   VasGG.Destroy()
   ```

---

## ⚠️ Disclaimer

This script is provided **solely for educational and research purposes**.  
Using it in Roblox violates the Terms of Service and can lead to permanent account suspension.  
The author assumes no responsibility for any consequences arising from its use.

---

*Repository: [Scripts-Vault](https://github.com/2863862963872963/Scripts-Vault)*
