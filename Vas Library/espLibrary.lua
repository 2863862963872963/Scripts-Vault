local espLibrary = {
    instances = {},
    espCache = {},
    chamsCache = {},
    objectCache = {},
    conns = {},
    whitelist = {},
    blacklist = {},
    options = {
        enabled = true,
        minScaleFactorX = 1,
        maxScaleFactorX = 10,
        minScaleFactorY = 1,
        maxScaleFactorY = 10,
        scaleFactorX = 5,
        scaleFactorY = 6,
        boundingBox = false,
        boundingBoxDescending = true,
        excludedPartNames = {},
        font = 2,
        fontSize = 13,
        limitDistance = false,
        maxDistance = 1000,
        visibleOnly = false,
        teamCheck = false,
        teamColor = false,
        fillColor = nil,
        whitelistColor = Color3.new(1, 0, 0),
        outOfViewArrows = true,
        outOfViewArrowsFilled = true,
        outOfViewArrowsSize = 25,
        outOfViewArrowsRadius = 100,
        outOfViewArrowsColor = Color3.new(1, 1, 1),
        outOfViewArrowsTransparency = 0.5,
        outOfViewArrowsOutline = true,
        outOfViewArrowsOutlineFilled = false,
        outOfViewArrowsOutlineColor = Color3.new(1, 1, 1),
        outOfViewArrowsOutlineTransparency = 1,
        names = true,
        namesShowDisplayName = false,
        nameTransparency = 1,
        nameColor = Color3.new(1, 1, 1),
        boxes = true,
        boxesTransparency = 1,
        boxesColor = Color3.new(1, 0, 0),
        boxFill = false,
        boxFillTransparency = 0.5,
        boxFillColor = Color3.new(1, 0, 0),
        healthBars = true,
        healthBarsSize = 1,
        healthBarsTransparency = 1,
        healthBarsColor = Color3.new(0, 1, 0),
        healthText = true,
        healthTextTransparency = 1,
        healthTextSuffix = "%",
        healthTextColor = Color3.new(1, 1, 1),
        distance = true,
        distanceTransparency = 1,
        distanceSuffix = " Studs",
        distanceColor = Color3.new(1, 1, 1),
        tracers = false,
        tracerTransparency = 1,
        tracerColor = Color3.new(1, 1, 1),
        tracerOrigin = "Bottom",
        skeletonLines = false,
        skeletonColor = Color3.new(1, 1, 1),
        skeletonTransparency = 0.5,
        chams = true,
        chamsFillColor = Color3.new(1, 0, 0),
        chamsFillTransparency = 0.5,
        chamsOutlineColor = Color3.new(),
        chamsOutlineTransparency = 0,
    },
}
espLibrary.__index = espLibrary

local getService      = game.GetService
local instanceNew     = Instance.new
local drawingNew      = Drawing.new
local vector2New      = Vector2.new
local vector3New      = Vector3.new
local cframeNew       = CFrame.new
local color3New       = Color3.new
local raycastParamsNew = RaycastParams.new
local abs             = math.abs
local tan             = math.tan
local rad             = math.rad
local clamp           = math.clamp
local floor           = math.floor
local find            = table.find
local insert          = table.insert
local findFirstChild  = game.FindFirstChild
local getChildren     = game.GetChildren
local getDescendants  = game.GetDescendants
local isA             = workspace.IsA
local raycast         = workspace.Raycast
local emptyCFrame     = cframeNew()
local pointToObjectSpace = emptyCFrame.PointToObjectSpace
local getComponents   = emptyCFrame.GetComponents
local cross           = vector3New().Cross
local inf             = 1 / 0

local defaultBoxSize  = vector3New(5, 6, 0)

local workspace        = getService(game, "Workspace")
local runService       = getService(game, "RunService")
local players          = getService(game, "Players")
local coreGui          = getService(game, "CoreGui")
local userInputService = getService(game, "UserInputService")

local currentCamera = workspace.CurrentCamera
local localPlayer   = players.LocalPlayer
local screenGui     = instanceNew("ScreenGui", coreGui)

local skeletonJoints = {
    { "Head",             "UpperTorso" },
    { "UpperTorso",       "LowerTorso"  },
    { "UpperTorso",       "LeftUpperArm" },
    { "LeftUpperArm",     "LeftLowerArm" },
    { "LeftLowerArm",     "LeftHand"    },
    { "UpperTorso",       "RightUpperArm" },
    { "RightUpperArm",    "RightLowerArm" },
    { "RightLowerArm",    "RightHand"   },
    { "LowerTorso",       "LeftUpperLeg" },
    { "LeftUpperLeg",     "LeftLowerLeg" },
    { "LeftLowerLeg",     "LeftFoot"    },
    { "LowerTorso",       "RightUpperLeg" },
    { "RightUpperLeg",    "RightLowerLeg" },
    { "RightLowerLeg",    "RightFoot"   },
}

local wtvp = currentCamera.WorldToViewportPoint

local function isDrawing(t)
    return t == "Square" or t == "Text" or t == "Triangle"
        or t == "Image" or t == "Line" or t == "Circle"
end

local function create(t, props)
    local drawing = isDrawing(t)
    local obj = drawing and drawingNew(t) or instanceNew(t)
    if props then
        for k, v in next, props do
            obj[k] = v
        end
    end
    if not drawing then
        insert(espLibrary.instances, obj)
    end
    return obj
end

local function worldToViewportPoint(pos)
    local sp, onScreen = wtvp(currentCamera, pos)
    return vector2New(sp.X, sp.Y), onScreen, sp.Z
end

local function round(n)
    return typeof(n) == "Vector2"
        and vector2New(floor(n.X), floor(n.Y))
        or  floor(n)
end

local function resolveColor(self, player, teamColor)
    local o = self.options
    local color = o.teamColor and teamColor or nil
    if o.fillColor ~= nil then color = o.fillColor end
    if find(self.whitelist, player.Name) then color = o.whitelistColor end
    return color
end

local function isDisabled(self, player, distance, team)
    local o = self.options
    if not o.enabled then return true end
    if find(self.blacklist, player.Name) then return true end
    if o.limitDistance and distance > o.maxDistance then return true end
    if o.teamCheck and team == espLibrary.getTeam(localPlayer) then return true end
    return false
end

function espLibrary.getTeam(player)
    local team = player.Team
    return team, player.TeamColor.Color
end

function espLibrary.getCharacter(player)
    local character = player.Character
    return character, character and findFirstChild(character, "HumanoidRootPart")
end

function espLibrary.getBoundingBox(character, torso)
    if espLibrary.options.boundingBox then
        local minX, minY, minZ = inf, inf, inf
        local maxX, maxY, maxZ = -inf, -inf, -inf
        local iter = espLibrary.options.boundingBoxDescending
            and getDescendants(character)
            or  getChildren(character)
        for _, part in next, iter do
            if isA(part, "BasePart") and not find(espLibrary.options.excludedPartNames, part.Name) then
                local sz = part.Size
                local sx, sy, sz2 = sz.X, sz.Y, sz.Z
                local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = getComponents(part.CFrame)
                local wx = 0.5 * (abs(r00)*sx + abs(r01)*sy + abs(r02)*sz2)
                local wy = 0.5 * (abs(r10)*sx + abs(r11)*sy + abs(r12)*sz2)
                local wz = 0.5 * (abs(r20)*sx + abs(r21)*sy + abs(r22)*sz2)
                if minX > x - wx then minX = x - wx end
                if minY > y - wy then minY = y - wy end
                if minZ > z - wz then minZ = z - wz end
                if maxX < x + wx then maxX = x + wx end
                if maxY < y + wy then maxY = y + wy end
                if maxZ < z + wz then maxZ = z + wz end
            end
        end
        local oMin = vector3New(minX, minY, minZ)
        local oMax = vector3New(maxX, maxY, maxZ)
        return (oMax + oMin) * 0.5, oMax - oMin
    else
        return torso.Position, vector2New(espLibrary.options.scaleFactorX, espLibrary.options.scaleFactorY)
    end
end

do
    local lastFov, lastScale
    function espLibrary.getScaleFactor(fov, depth)
        if fov ~= lastFov then
            lastScale = tan(rad(fov * 0.5)) * 2
            lastFov   = fov
        end
        return 1 / (depth * lastScale) * 1000
    end
end

function espLibrary.getBoxData(position, size)
    local torsoPos, onScreen, depth = worldToViewportPoint(position)
    local scaleFactor = espLibrary.getScaleFactor(currentCamera.FieldOfView, depth)
    local clampX = clamp(size.X, espLibrary.options.minScaleFactorX, espLibrary.options.maxScaleFactorX)
    local clampY = clamp(size.Y, espLibrary.options.minScaleFactorY, espLibrary.options.maxScaleFactorY)
    local s = round(vector2New(clampX * scaleFactor, clampY * scaleFactor))
    return onScreen, s, round(vector2New(torsoPos.X - s.X * 0.5, torsoPos.Y - s.Y * 0.5)), torsoPos
end

function espLibrary.getHealth(player, character)
    local humanoid = findFirstChild(character, "Humanoid")
    if humanoid then
        return humanoid.Health, humanoid.MaxHealth
    end
    return 100, 100
end

function espLibrary.visibleCheck(character, position)
    local origin = currentCamera.CFrame.Position
    local params = raycastParamsNew()
    params.FilterDescendantsInstances = { espLibrary.getCharacter(localPlayer), currentCamera, character }
    params.FilterType  = Enum.RaycastFilterType.Blacklist
    params.IgnoreWater = true
    return not raycast(workspace, origin, position - origin, params)
end

function espLibrary.addEsp(player)
    if player == localPlayer then return end
    local skeletonDrawings = {}
    for i = 1, #skeletonJoints do
        skeletonDrawings[i] = create("Line", { Thickness = 1 })
    end
    espLibrary.espCache[player] = {
        arrow = create("Triangle", { Thickness = 1 }),
        arrowOutline = create("Triangle", { Thickness = 1 }),
        top = create("Text", { Center = true, Size = 13, Outline = true, OutlineColor = color3New(), Font = 2 }),
        side = create("Text", { Size = 13, Outline = true, OutlineColor = color3New(), Font = 2 }),
        bottom = create("Text", { Center = true, Size = 13, Outline = true, OutlineColor = color3New(), Font = 2 }),
        boxFill = create("Square", { Thickness = 1, Filled = true }),
        boxOutline = create("Square", { Thickness = 3, Color = color3New() }),
        box = create("Square", { Thickness = 1 }),
        healthBarOutline = create("Square", { Thickness = 1, Color = color3New(), Filled = true }),
        healthBar = create("Square", { Thickness = 1, Filled = true }),
        line = create("Line"),
        skeleton = skeletonDrawings,
    }
end

function espLibrary.removeEsp(player)
    local cache = espLibrary.espCache[player]
    if not cache then return end
    espLibrary.espCache[player] = nil
    for _, obj in next, cache do
        if type(obj) == "table" then
            for _, line in next, obj do line:Remove() end
        else
            obj:Remove()
        end
    end
end

function espLibrary.addChams(player)
    if player == localPlayer then return end
    espLibrary.chamsCache[player] = create("Highlight", { Parent = screenGui })
end

function espLibrary.removeChams(player)
    local highlight = espLibrary.chamsCache[player]
    if highlight then
        espLibrary.chamsCache[player] = nil
        highlight:Destroy()
    end
end

function espLibrary.addObject(object, options)
    espLibrary.objectCache[object] = {
        options = options,
        text = create("Text", { Center = true, Size = 13, Outline = true, OutlineColor = color3New(), Font = 2 }),
    }
end

function espLibrary.removeObject(object)
    local cache = espLibrary.objectCache[object]
    if cache then
        espLibrary.objectCache[object] = nil
        cache.text:Remove()
    end
end

function espLibrary:AddObjectEsp(object, defaultOptions)
    assert(object and object.Parent, "invalid object passed")
    local options = defaultOptions or {}
    options.enabled      = options.enabled      ~= nil and options.enabled      or true
    options.limitDistance = options.limitDistance ~= nil and options.limitDistance or false
    options.maxDistance  = options.maxDistance   or false
    options.visibleOnly  = options.visibleOnly   ~= nil and options.visibleOnly  or false
    options.color        = options.color         or color3New(1, 1, 1)
    options.transparency = options.transparency  or 1
    options.text         = options.text          or object.Name
    options.font         = options.font          or 2
    options.fontSize     = options.fontSize      or 13
    self.addObject(object, options)
    insert(self.conns, object.Parent.ChildRemoved:Connect(function(child)
        if child == object then self.removeObject(child) end
    end))
    return options
end

function espLibrary:SetOption(key, value)
    assert(self.options[key] ~= nil, "unknown option: " .. tostring(key))
    self.options[key] = value
end

function espLibrary:Toggle()
    self.options.enabled = not self.options.enabled
end

function espLibrary:IsPlayerVisible(player)
    local character, torso = self.getCharacter(player)
    if not character or not torso then return false end
    return self.visibleCheck(character, torso.Position)
end

function espLibrary:Unload()
    for _, conn in next, self.conns do conn:Disconnect() end
    for _, player in next, players:GetPlayers() do
        self.removeEsp(player)
        self.removeChams(player)
    end
    for object in next, self.objectCache do self.removeObject(object) end
    for _, obj in next, self.instances do obj:Destroy() end
    screenGui:Destroy()
    runService:UnbindFromRenderStep("esp_rendering")
end

local function setHidden(obj)
    if obj.Visible ~= nil then
        obj.Visible = false
    elseif obj.Enabled ~= nil then
        obj.Enabled = false
    end
end

local function renderPlayer(self, player, objects, mouseLocation)
    local character, torso = self.getCharacter(player)

    if not (character and torso) then
        for _, obj in next, objects do
            if type(obj) == "table" then
                for _, line in next, obj do setHidden(line) end
            else
                setHidden(obj)
            end
        end
        return
    end

    local o            = self.options
    local torsoPos3    = torso.Position
    local onScreen, size, position, torsoPos2 = self.getBoxData(torsoPos3, defaultBoxSize)
    local distance     = (currentCamera.CFrame.Position - torsoPos3).Magnitude
    local team, teamColor = self.getTeam(player)
    local disabled     = isDisabled(self, player, distance, team)

    if o.visibleOnly and not self.visibleCheck(character, torsoPos3) then
        disabled = true
    end

    local color        = resolveColor(self, player, teamColor)
    local show         = onScreen and (size and position) and not disabled
    local viewportSize = currentCamera.ViewportSize
    local screenCenter = vector2New(viewportSize.X * 0.5, viewportSize.Y * 0.5)

    local objectSpacePoint = (pointToObjectSpace(currentCamera.CFrame, torsoPos3) * vector3New(1, 0, 1)).Unit
    local crossVector      = cross(objectSpacePoint, vector3New(0, 1, 1))
    local rightVector      = vector2New(crossVector.X, crossVector.Z)
    local arrowRadius, arrowSize = o.outOfViewArrowsRadius, o.outOfViewArrowsSize
    local arrowPosition    = screenCenter + vector2New(objectSpacePoint.X, objectSpacePoint.Z) * arrowRadius
    local arrowDirection   = (arrowPosition - screenCenter).Unit
    local pointA = arrowPosition
    local pointB = screenCenter + arrowDirection * (arrowRadius - arrowSize) + rightVector  * arrowSize
    local pointC = screenCenter + arrowDirection * (arrowRadius - arrowSize) + -rightVector * arrowSize

    local health, maxHealth   = self.getHealth(player, character)
    local healthBarSz         = round(vector2New(o.healthBarsSize, -(size.Y * (health / maxHealth))))
    local healthBarPos        = round(vector2New(position.X - (3 + healthBarSz.X), position.Y + size.Y))
    local arrowVisible        = not onScreen and not disabled

    objects.arrow.Visible      = arrowVisible and o.outOfViewArrows
    objects.arrow.Filled       = o.outOfViewArrowsFilled
    objects.arrow.Transparency = o.outOfViewArrowsTransparency
    objects.arrow.Color        = color or o.outOfViewArrowsColor
    objects.arrow.PointA, objects.arrow.PointB, objects.arrow.PointC = pointA, pointB, pointC

    objects.arrowOutline.Visible      = arrowVisible and o.outOfViewArrowsOutline
    objects.arrowOutline.Filled       = o.outOfViewArrowsOutlineFilled
    objects.arrowOutline.Transparency = o.outOfViewArrowsOutlineTransparency
    objects.arrowOutline.Color        = color or o.outOfViewArrowsOutlineColor
    objects.arrowOutline.PointA, objects.arrowOutline.PointB, objects.arrowOutline.PointC = pointA, pointB, pointC

    local nameText = o.namesShowDisplayName and player.DisplayName or player.Name
    objects.top.Visible      = show and o.names
    objects.top.Font         = o.font
    objects.top.Size         = o.fontSize
    objects.top.Transparency = o.nameTransparency
    objects.top.Color        = color or o.nameColor
    objects.top.Text         = nameText
    objects.top.Position     = round(position + vector2New(size.X * 0.5, -(objects.top.TextBounds.Y + 2)))

    objects.side.Visible      = show and o.healthText
    objects.side.Font         = o.font
    objects.side.Size         = o.fontSize
    objects.side.Transparency = o.healthTextTransparency
    objects.side.Color        = color or o.healthTextColor
    objects.side.Text         = floor(health) .. o.healthTextSuffix
    objects.side.Position     = round(position + vector2New(size.X + 3, -3))

    objects.bottom.Visible      = show and o.distance
    objects.bottom.Font         = o.font
    objects.bottom.Size         = o.fontSize
    objects.bottom.Transparency = o.distanceTransparency
    objects.bottom.Color        = color or o.distanceColor
    objects.bottom.Text         = tostring(round(distance)) .. o.distanceSuffix
    objects.bottom.Position     = round(position + vector2New(size.X * 0.5, size.Y + 1))

    objects.box.Visible      = show and o.boxes
    objects.box.Color        = color or o.boxesColor
    objects.box.Transparency = o.boxesTransparency
    objects.box.Size         = size
    objects.box.Position     = position

    objects.boxOutline.Visible      = show and o.boxes
    objects.boxOutline.Transparency = o.boxesTransparency
    objects.boxOutline.Size         = size
    objects.boxOutline.Position     = position

    objects.boxFill.Visible      = show and o.boxFill
    objects.boxFill.Color        = color or o.boxFillColor
    objects.boxFill.Transparency = o.boxFillTransparency
    objects.boxFill.Size         = size
    objects.boxFill.Position     = position

    objects.healthBar.Visible      = show and o.healthBars
    objects.healthBar.Color        = color or o.healthBarsColor
    objects.healthBar.Transparency = o.healthBarsTransparency
    objects.healthBar.Size         = healthBarSz
    objects.healthBar.Position     = healthBarPos

    objects.healthBarOutline.Visible      = show and o.healthBars
    objects.healthBarOutline.Transparency = o.healthBarsTransparency
    objects.healthBarOutline.Size         = round(vector2New(healthBarSz.X, -size.Y) + vector2New(2, -2))
    objects.healthBarOutline.Position     = healthBarPos - vector2New(1, -1)

    local origin = o.tracerOrigin
    objects.line.Visible      = show and o.tracers
    objects.line.Color        = color or o.tracerColor
    objects.line.Transparency = o.tracerTransparency
    objects.line.From =
        origin == "Mouse"  and (mouseLocation or userInputService:GetMouseLocation()) or
        origin == "Top"    and vector2New(viewportSize.X * 0.5, 0) or
                               vector2New(viewportSize.X * 0.5, viewportSize.Y)
    objects.line.To = torsoPos2

    local skeletonVisible = show and o.skeletonLines
    for i, joint in next, skeletonJoints do
        local line = objects.skeleton[i]
        if skeletonVisible then
            local partA = findFirstChild(character, joint[1])
            local partB = findFirstChild(character, joint[2])
            if partA and partB then
                local spA, onA = worldToViewportPoint(partA.Position)
                local spB, onB = worldToViewportPoint(partB.Position)
                line.Visible      = onA and onB
                line.Color        = color or o.skeletonColor
                line.Transparency = o.skeletonTransparency
                line.From         = spA
                line.To           = spB
            else
                line.Visible = false
            end
        else
            line.Visible = false
        end
    end
end

local function renderChams(self, player, highlight)
    local character, torso = self.getCharacter(player)
    if not (character and torso) then return end

    local o            = self.options
    local torsoPos3    = torso.Position
    local distance     = (currentCamera.CFrame.Position - torsoPos3).Magnitude
    local team, teamColor = self.getTeam(player)
    local canShow      = o.enabled and o.chams and not isDisabled(self, player, distance, team)
    local color        = resolveColor(self, player, teamColor)

    highlight.Enabled            = canShow
    highlight.DepthMode          = o.visibleOnly and Enum.HighlightDepthMode.Occluded or Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Adornee            = character
    highlight.FillColor          = color or o.chamsFillColor
    highlight.FillTransparency   = o.chamsFillTransparency
    highlight.OutlineColor       = color or o.chamsOutlineColor
    highlight.OutlineTransparency = o.chamsOutlineTransparency
end

function espLibrary:Load(renderValue)
    insert(self.conns, players.PlayerAdded:Connect(function(player)
        self.addEsp(player)
        self.addChams(player)
    end))

    insert(self.conns, players.PlayerRemoving:Connect(function(player)
        self.removeEsp(player)
        self.removeChams(player)
    end))

    for _, player in next, players:GetPlayers() do
        self.addEsp(player)
        self.addChams(player)
    end

    runService:BindToRenderStep("esp_rendering", renderValue or (Enum.RenderPriority.Camera.Value + 1), function()
        local mouseLocation = self.options.tracerOrigin == "Mouse" and userInputService:GetMouseLocation() or nil

        for player, objects in next, self.espCache do
            renderPlayer(self, player, objects, mouseLocation)
        end

        for player, highlight in next, self.chamsCache do
            renderChams(self, player, highlight)
        end

        for object, cache in next, self.objectCache do
            local partPosition = vector3New()
            if object:IsA("BasePart") then
                partPosition = object.Position
            elseif object:IsA("Model") then
                partPosition = self.getBoundingBox(object)
            end

            local distance             = (currentCamera.CFrame.Position - partPosition).Magnitude
            local screenPosition, onScreen = worldToViewportPoint(partPosition)
            local opts                 = cache.options
            local canShow              = opts.enabled and onScreen

            if opts.limitDistance and distance > opts.maxDistance then canShow = false end
            if opts.visibleOnly and not self.visibleCheck(object, partPosition) then canShow = false end

            cache.text.Visible      = canShow
            cache.text.Font         = opts.font
            cache.text.Size         = opts.fontSize
            cache.text.Transparency = opts.transparency
            cache.text.Color        = opts.color
            cache.text.Text         = opts.text
            cache.text.Position     = round(screenPosition)
        end
    end)
end

return espLibrary
