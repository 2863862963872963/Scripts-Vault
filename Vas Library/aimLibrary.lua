local aimLibrary = {
    options = {
        enabled = true,
        aimMode = nil,
        aimPart = "Head",
        aimPartDistribution = {
            Head = 70,
            Torso = 30,
        },
        aimPartDistributionEnabled = false,
        aimPartRandomizePerShot = false,
        fov = 90,
        fovVisible = false,
        smoothness = 10,
        maxSmoothDistance = 200,
        teamCheck = true,
        visibleOnly = true,
        lockTarget = false,
        keyToAim = nil,
        keyToggle = nil,
        prediction = false,
        predictionMultiplier = 1,
        maxDistance = 1000,
        ignoreBlacklist = true,
        ignoreWhitelist = false,
        aimAtDowned = false,
        boneNames = {
            "Head", "UpperTorso", "LowerTorso", "HumanoidRootPart"
        },
    },
    target = nil,
    targetPart = nil,
    lastTarget = nil,
    connections = {},
    debugDrawings = {},
}

aimLibrary.__index = aimLibrary

local getService = game.GetService
local workspace = getService(game, "Workspace")
local players = getService(game, "Players")
local runService = getService(game, "RunService")
local userInputService = getService(game, "UserInputService")
local currentCamera = workspace.CurrentCamera
local localPlayer = players.LocalPlayer

local abs, atan2, sqrt = math.abs, math.atan2, math.sqrt
local rad, deg = math.rad, math.deg
local floor, clamp = math.floor, math.clamp
local vector2New, vector3New = Vector2.new, Vector3.new
local find, insert = table.find, table.insert

local espLibrary = nil

function aimLibrary:IsMobile()
    return userInputService.TouchEnabled and not userInputService.MouseEnabled
end

local function getCharacter(player)
    local character = player.Character
    if not character then return nil, nil end
    local torso = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")
    return character, torso
end

local function getTeam(player)
    if espLibrary and espLibrary.getTeam then
        return espLibrary.getTeam(player)
    else
        local team = player.Team
        return team, team and team.TeamColor and team.TeamColor.Color or Color3.new(1,1,1)
    end
end

local function visibleCheck(character, position)
    if espLibrary and espLibrary.visibleCheck then
        return espLibrary.visibleCheck(character, position)
    else
        local origin = currentCamera.CFrame.Position
        local params = RaycastParams.new()
        params.FilterDescendantsInstances = { localPlayer.Character, currentCamera, character }
        params.FilterType = Enum.RaycastFilterType.Blacklist
        params.IgnoreWater = true
        return not workspace:Raycast(origin, (position - origin).Unit * 1000, params)
    end
end

local function getAimPart(character, partName)
    if partName == "Head" then
        local head = character:FindFirstChild("Head")
        if head then return head end
    end
    local part = character:FindFirstChild(partName)
    if part then return part end
    for _, name in ipairs(aimLibrary.options.boneNames) do
        part = character:FindFirstChild(name)
        if part then return part end
    end
    return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")
end

local function getVelocity(character)
    local root = character:FindFirstChild("HumanoidRootPart")
    if root then return root.AssemblyLinearVelocity end
    return vector3New(0,0,0)
end

function aimLibrary:GetRandomAimPart(character)
    local dist = self.options.aimPartDistribution
    if not dist or next(dist) == nil then
        return getAimPart(character, self.options.aimPart)
    end

    local parts, weights = {}, {}
    for name, weight in pairs(dist) do
        if weight > 0 then
            local part = getAimPart(character, name)
            if part then
                table.insert(parts, part)
                table.insert(weights, weight)
            end
        end
    end

    if #parts == 0 then
        return getAimPart(character, self.options.aimPart)
    end

    local total = 0
    for _, w in ipairs(weights) do total = total + w end
    local r = math.random() * total
    local cumulative = 0
    for i, w in ipairs(weights) do
        cumulative = cumulative + w
        if r <= cumulative then
            return parts[i]
        end
    end
    return parts[#parts]
end

function aimLibrary:GetTarget()
    local o = self.options
    if not o.enabled then return nil, nil end

    if o.lockTarget and self.target then
        local char, torso = getCharacter(self.target)
        if char and torso and char.Parent then
            local dist = (currentCamera.CFrame.Position - torso.Position).Magnitude
            if dist <= o.maxDistance then
                local part = self.targetPart
                if not part or not part.Parent then
                    part = self:GetRandomAimPart(char)
                    self.targetPart = part
                end
                if part then
                    if o.visibleOnly and not visibleCheck(char, part.Position) then
                        if o.visibleOnly then
                            self.target = nil
                            self.targetPart = nil
                            return nil, nil
                        end
                    end
                    return self.target, part
                end
            end
        end
        self.target = nil
        self.targetPart = nil
    end

    local bestTarget = nil
    local bestScore = o.fov > 0 and o.fov or 9999
    local myTeam = localPlayer.Team

    local primaryPartName = o.aimPart
    if o.aimPartDistributionEnabled and next(o.aimPartDistribution) then
        local maxWeight = -1
        for name, weight in pairs(o.aimPartDistribution) do
            if weight > maxWeight then
                maxWeight = weight
                primaryPartName = name
            end
        end
    end

    for _, player in ipairs(players:GetPlayers()) do
        if player ~= localPlayer and player.Character and player.Character.Parent then
            if o.teamCheck then
                local team = player.Team
                if team and team == myTeam then goto continue end
            end

            if espLibrary then
                if o.ignoreBlacklist and espLibrary.blacklist and find(espLibrary.blacklist, player.Name) then
                    goto continue
                end
                if o.ignoreWhitelist and espLibrary.whitelist and not find(espLibrary.whitelist, player.Name) then
                    goto continue
                end
            end

            local char, torso = getCharacter(player)
            if not char or not torso then goto continue end

            local dist = (currentCamera.CFrame.Position - torso.Position).Magnitude
            if dist > o.maxDistance then goto continue end

            local primaryPart = getAimPart(char, primaryPartName)
            if not primaryPart then goto continue end
            local aimPos = primaryPart.Position

            if o.prediction then
                local vel = getVelocity(char)
                local time = dist / 1000
                aimPos = aimPos + vel * time * o.predictionMultiplier
            end

            if o.visibleOnly and not visibleCheck(char, aimPos) then goto continue end

            local screenPos, onScreen = currentCamera:WorldToViewportPoint(aimPos)
            local score
            if not onScreen then
                local dir = (aimPos - currentCamera.CFrame.Position).Unit
                local angle = deg(acos(dir:Dot(currentCamera.CFrame.LookVector)))
                if angle > o.fov * 0.5 then goto continue end
                score = angle
            else
                local center = currentCamera.ViewportSize / 2
                local screenDist = (vector2New(screenPos.X, screenPos.Y) - center).Magnitude
                local fovAngle = o.fov * 0.5
                local maxScreenDist = center.X * tan(rad(fovAngle)) / tan(rad(currentCamera.FieldOfView * 0.5))
                if screenDist > maxScreenDist then goto continue end
                score = screenDist
            end

            if score < bestScore then
                bestScore = score
                bestTarget = player
            end
        end
        ::continue::
    end

    if bestTarget then
        self.target = bestTarget
        if o.aimPartDistributionEnabled then
            local char, _ = getCharacter(bestTarget)
            if char then
                self.targetPart = self:GetRandomAimPart(char)
            else
                self.targetPart = nil
            end
        else
            local char, _ = getCharacter(bestTarget)
            if char then
                self.targetPart = getAimPart(char, o.aimPart)
            else
                self.targetPart = nil
            end
        end
        return self.target, self.targetPart
    else
        self.target = nil
        self.targetPart = nil
        return nil, nil
    end
end

function aimLibrary:Update()
    local o = self.options
    if not o.enabled then return end

    if o.keyToggle and userInputService:IsKeyDown(o.keyToggle) then
        o.enabled = not o.enabled
        task.wait(0.2)
    end

    if o.keyToAim and not userInputService:IsKeyDown(o.keyToAim) then
        return
    end

    local target, part = self:GetTarget()
    if not target or not part then
        self.lastTarget = nil
        return
    end

    if o.aimPartDistributionEnabled and o.aimPartRandomizePerShot then
        local char, _ = getCharacter(target)
        if char then
            part = self:GetRandomAimPart(char)
            self.targetPart = part
        else
            return
        end
    end

    local aimPos = part.Position
    if o.prediction then
        local char, _ = getCharacter(target)
        if char then
            local vel = getVelocity(char)
            local dist = (currentCamera.CFrame.Position - aimPos).Magnitude
            local time = dist / 1000
            aimPos = aimPos + vel * time * o.predictionMultiplier
        end
    end

    local cameraCF = currentCamera.CFrame
    local targetCF = CFrame.lookAt(cameraCF.Position, aimPos)

    if o.aimMode == "Camera" then
        if o.smoothness > 1 then
            local steps = o.smoothness
            local dist = (cameraCF.Position - aimPos).Magnitude
            if dist > o.maxSmoothDistance then
                currentCamera.CFrame = targetCF
            else
                local currentLook = cameraCF.LookVector
                local targetLook = targetCF.LookVector
                for i = 1, steps do
                    local t = i / steps
                    local newLook = currentLook:Lerp(targetLook, t)
                    currentCamera.CFrame = CFrame.lookAt(cameraCF.Position, cameraCF.Position + newLook)
                    runService.Heartbeat:Wait()
                end
                currentCamera.CFrame = targetCF
            end
        else
            currentCamera.CFrame = targetCF
        end
    else
        if userInputService.MouseEnabled then
            local screenPos, onScreen = currentCamera:WorldToViewportPoint(aimPos)
            if onScreen then
                local mouse = userInputService:GetMouseLocation()
                local targetScreen = vector2New(screenPos.X, screenPos.Y)
                if o.smoothness > 1 then
                    local steps = o.smoothness
                    local dist = (targetScreen - mouse).Magnitude
                    if dist > o.maxSmoothDistance then
                        userInputService:SetMouseLocation(targetScreen.X, targetScreen.Y)
                    else
                        for i = 1, steps do
                            local t = i / steps
                            local newPos = mouse + (targetScreen - mouse) * t
                            userInputService:SetMouseLocation(newPos.X, newPos.Y)
                            runService.Heartbeat:Wait()
                        end
                    end
                else
                    userInputService:SetMouseLocation(targetScreen.X, targetScreen.Y)
                end
            end
        else
            if o.aimMode == "Mouse" then
                currentCamera.CFrame = targetCF
            end
        end
    end

    self.lastTarget = target
end

function aimLibrary:SetOption(key, value)
    assert(self.options[key] ~= nil, "unknown option: " .. tostring(key))
    self.options[key] = value
end

function aimLibrary:Toggle()
    self.options.enabled = not self.options.enabled
end

function aimLibrary:Load(renderPriority, espLib)
    espLibrary = espLib or espLibrary

    if self:IsMobile() then
        self.options.aimMode = "Camera"
    else
        self.options.aimMode = self.options.aimMode or "Mouse"
    end

    local priority = renderPriority or Enum.RenderPriority.Camera.Value + 2
    runService:BindToRenderStep("aim_rendering", priority, function()
        self:Update()
    end)

    insert(self.connections, players.PlayerRemoving:Connect(function(player)
        if self.target == player then
            self.target = nil
            self.targetPart = nil
            self.lastTarget = nil
        end
    end))
end

function aimLibrary:Unload()
    runService:UnbindFromRenderStep("aim_rendering")
    for _, conn in ipairs(self.connections) do
        conn:Disconnect()
    end
    self.connections = {}
    self.target = nil
    self.targetPart = nil
    self.lastTarget = nil
end

return aimLibrary
