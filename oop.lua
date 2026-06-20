local Library = {
    GetService = function(service)
        return cloneref and cloneref(game:GetService(service)) or game:GetService(service)
    end
}

local Players = Library.GetService("Players")
local RunService = Library.GetService("RunService")
local TweenService = Library.GetService("TweenService")
local PathfindingService = Library.GetService("PathfindingService")

local function safeGet(inst, key)
    local ok, v = pcall(function() return inst[key] end)
    return ok and v or nil
end

local function safeSet(inst, key, value)
    local ok = pcall(function() inst[key] = value end)
    return ok
end

local function safeCall(inst, method, ...)
    local args = { ... }
    local ok, v = pcall(function() return inst[method](inst, table.unpack(args)) end)
    return ok, v
end

local function safeGetChildren(inst)
    local ok, v = pcall(function() return inst:GetChildren() end)
    return ok and v or {}
end

local function safeGetDescendants(inst)
    local ok, v = pcall(function() return inst:GetDescendants() end)
    return ok and v or {}
end

local function safeFindFirstChild(inst, name, recursive)
    local ok, v = pcall(function() return inst:FindFirstChild(name, recursive) end)
    return ok and v or nil
end

local function safeWaitForChild(inst, name, timeout)
    local ok, v = pcall(function() return inst:WaitForChild(name, timeout) end)
    return ok and v or nil
end

local function safeFindFirstChildOfClass(inst, class)
    local ok, v = pcall(function() return inst:FindFirstChildOfClass(class) end)
    return ok and v or nil
end

local function safeFindFirstAncestorOfClass(inst, class)
    local ok, v = pcall(function() return inst:FindFirstAncestorOfClass(class) end)
    return ok and v or nil
end

local function safeGetAttribute(inst, name)
    local ok, v = pcall(function() return inst:GetAttribute(name) end)
    return ok and v or nil
end

local function safeDestroy(inst)
    return pcall(function() inst:Destroy() end)
end

local function isA(inst, cls)
    local ok, v = pcall(function() return inst:IsA(cls) end)
    return ok and v
end

local function findFirstChildOfClass(parent, class)
    for _, c in ipairs(safeGetChildren(parent)) do
        if isA(c, class) then return c end
    end
end

local function toCFrame(target)
    if typeof(target) == "CFrame" then
        return target
    elseif typeof(target) == "Vector3" then
        return CFrame.new(target)
    elseif typeof(target) == "Instance" then
        local ok, cf = pcall(function()
            if target:IsA("BasePart") then return target.CFrame end
            if target:IsA("Model") then return target:GetPivot() end
        end)
        if ok and cf then return cf end
    end
    return CFrame.new(0, 0, 0)
end

local _sessions = {}
local _sessionId = 0

local function _newSession()
    _sessionId += 1
    local id = _sessionId
    local s = { id = id, active = true, connections = {} }
    _sessions[id] = s
    return s
end

local function _killSession(s)
    if not s or not s.active then return end
    s.active = false
    for _, c in ipairs(s.connections) do
        pcall(function() c:Disconnect() end)
    end
    s.connections = {}
    _sessions[s.id] = nil
end

local function _addConn(s, conn)
    table.insert(s.connections, conn)
end

local function _setCollision(character, state)
    for _, part in ipairs(safeGetDescendants(character)) do
        if isA(part, "BasePart") then
            safeSet(part, "CanCollide", state)
        end
    end
end

local function _getPos(part)
    return safeGet(part, "Position") or Vector3.new()
end

local function _applyAntiFall(humanoid, enabled)
    pcall(function()
        humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, not enabled)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, not enabled)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, not enabled)
    end)
end

local function _doMove(s, hrp, humanoid, character, moveType, targetCF, targetPos, speed, arriveRadius, onArrive, onUpdate, config)
    if moveType == "TP" then
        safeSet(hrp, "CFrame", targetCF)
        task.defer(function()
            if not s.active then return end
            if onArrive then pcall(onArrive) end
            _killSession(s)
        end)

    elseif moveType == "Tween" then
        local dist = (_getPos(hrp) - targetPos).Magnitude
        local tweenTime = (config.Duration) or (speed <= 1 and speed or dist / speed)
        tweenTime = math.clamp(tweenTime, 0.05, config.MaxDuration or 60)

        local tween = TweenService:Create(
            hrp,
            TweenInfo.new(tweenTime, config.EasingStyle or Enum.EasingStyle.Linear, config.EasingDirection or Enum.EasingDirection.InOut),
            { CFrame = targetCF }
        )

        pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Physics) end)

        local updConn
        if onUpdate then
            updConn = RunService.Heartbeat:Connect(function()
                if not s.active then return end
                local p = _getPos(hrp)
                pcall(onUpdate, p, (p - targetPos).Magnitude)
            end)
            _addConn(s, updConn)
        end

        local doneConn
        doneConn = tween.Completed:Connect(function()
            if not s.active then return end
            pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end)
            if onArrive then pcall(onArrive) end
            _killSession(s)
        end)
        _addConn(s, doneConn)

        tween:Play()

    elseif moveType == "Walk" then
        safeSet(humanoid, "WalkSpeed", speed)
        safeCall(humanoid, "MoveTo", targetPos)
        if config.Jump then safeSet(humanoid, "Jump", true) end

        local walkConn
        walkConn = RunService.Heartbeat:Connect(function()
            if not s.active then return end
            local d = (_getPos(hrp) - targetPos).Magnitude
            if onUpdate then pcall(onUpdate, _getPos(hrp), d) end
            if d <= arriveRadius then
                if onArrive then task.defer(function() pcall(onArrive) end) end
                _killSession(s)
            end
        end)
        _addConn(s, walkConn)

        local mtConn
        mtConn = humanoid.MoveToFinished:Connect(function(reached)
            if not s.active then return end
            if reached and onArrive then
                task.defer(function() pcall(onArrive) end)
            end
            _killSession(s)
        end)
        _addConn(s, mtConn)

    elseif moveType == "Path" then
        local path = PathfindingService:CreatePath(config.AgentParams or {
            AgentRadius = 2,
            AgentHeight = 5,
            AgentCanJump = true,
            AgentCanClimb = true,
        })

        local ok = pcall(function() path:ComputeAsync(_getPos(hrp), targetPos) end)
        if not ok or safeGet(path, "Status") ~= Enum.PathStatus.Success then
            _doMove(s, hrp, humanoid, character, "Walk", targetCF, targetPos, speed, arriveRadius, onArrive, onUpdate, config)
            return
        end

        local okWp, waypoints = pcall(function() return path:GetWaypoints() end)
        if not okWp then
            _doMove(s, hrp, humanoid, character, "Walk", targetCF, targetPos, speed, arriveRadius, onArrive, onUpdate, config)
            return
        end
        safeSet(humanoid, "WalkSpeed", speed)
        local idx = 2

        local function step()
            if not s.active then return end
            if idx > #waypoints then
                if onArrive then pcall(onArrive) end
                _killSession(s)
                return
            end
            local wp = waypoints[idx]
            if wp.Action == Enum.PathWaypointAction.Jump then
                safeSet(humanoid, "Jump", true)
            end
            safeCall(humanoid, "MoveTo", wp.Position)
        end

        local mtConn
        mtConn = humanoid.MoveToFinished:Connect(function(reached)
            if not s.active then return end
            if not reached then
                _killSession(s)
                return
            end
            idx += 1
            step()
        end)
        _addConn(s, mtConn)

        if onUpdate then
            local updConn = RunService.Heartbeat:Connect(function()
                if not s.active then return end
                local p = _getPos(hrp)
                pcall(onUpdate, p, (p - targetPos).Magnitude)
            end)
            _addConn(s, updConn)
        end

        step()
    end
end

function Library:Move(config)
    config = config or {}

    local player = Players.LocalPlayer
    local character = player.Character or player.CharacterAdded:Wait()
    local okHrp, hrp = pcall(function() return character:WaitForChild("HumanoidRootPart", 10) end)
    hrp = okHrp and hrp or nil
    local humanoid = findFirstChildOfClass(character, "Humanoid")

    if not hrp or not humanoid then
        warn("[Library:Move] Missing HumanoidRootPart or Humanoid")
        return nil
    end

    local targetCF = toCFrame(config.Target)
    local targetPos = targetCF.Position
    local speed = config.Speed or 50
    local arriveRadius = config.ArriveRadius or 3
    local onArrive = config.OnArrive
    local onUpdate = config.OnUpdate

    local safeDistance = config.SafeDistance
    local safeEnabled = safeDistance and safeDistance.Enabled
    local safeRadius = safeDistance and safeDistance.Distance or 0

    local baseType = config.Type or "TP"
    local moveType = baseType

    if config.TypeIfDistance then
        local dist = (_getPos(hrp) - targetPos).Magnitude
        if dist <= (config.TypeIfDistance.Distance or 0) then
            moveType = config.TypeIfDistance.Type or baseType
        end
    end

    local s = _newSession()
    s.moveType = moveType
    s.targetPos = targetPos

    local function startReal(root, hum, char)
        _applyAntiFall(hum, config.AntiFall)

        if config.Noclip then
            local noclipConn = RunService.Stepped:Connect(function()
                if not s.active then return end
                _setCollision(char, false)
            end)
            _addConn(s, noclipConn)
        end

        local diedConn = hum.Died:Connect(function() _killSession(s) end)
        _addConn(s, diedConn)

        if config.Timeout then
            task.delay(config.Timeout, function()
                if s.active then
                    if config.OnTimeout then pcall(config.OnTimeout) end
                    _killSession(s)
                end
            end)
        end

        _doMove(s, root, hum, char, moveType, targetCF, targetPos, speed, arriveRadius, onArrive, onUpdate, config)
    end

    if safeEnabled then
        local dist = (_getPos(hrp) - targetPos).Magnitude
        if dist <= safeRadius then
            local safeConn
            safeConn = RunService.Heartbeat:Connect(function()
                if not s.active then return end
                local char = player.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if not root then return end

                local currentDist = (_getPos(root) - targetPos).Magnitude
                if currentDist > safeRadius then
                    if safeConn then safeConn:Disconnect() end
                    local hum = findFirstChildOfClass(char, "Humanoid")
                    if root and hum then
                        startReal(root, hum, char)
                    end
                end
            end)
            _addConn(s, safeConn)
            return s.id
        end
    end

    startReal(hrp, humanoid, character)
    return s.id
end

function Library:SafeGet(inst, key)
    return safeGet(inst, key)
end

function Library:SafeSet(inst, key, value)
    return safeSet(inst, key, value)
end

function Library:SafeCall(inst, method, ...)
    return safeCall(inst, method, ...)
end

function Library:IsA(inst, cls)
    return isA(inst, cls)
end

function Library:GetChildren(inst)
    return safeGetChildren(inst)
end

function Library:GetDescendants(inst)
    return safeGetDescendants(inst)
end

function Library:FindFirstChild(inst, name, recursive)
    return safeFindFirstChild(inst, name, recursive)
end

function Library:WaitForChild(inst, name, timeout)
    return safeWaitForChild(inst, name, timeout)
end

function Library:FindFirstChildOfClass(inst, class)
    return safeFindFirstChildOfClass(inst, class)
end

function Library:FindFirstAncestorOfClass(inst, class)
    return safeFindFirstAncestorOfClass(inst, class)
end

function Library:GetAttribute(inst, name)
    return safeGetAttribute(inst, name)
end

function Library:Destroy(inst)
    return safeDestroy(inst)
end

function Library:StopMove(id)
    if id then
        _killSession(_sessions[id])
    else
        for _, s in pairs(_sessions) do
            _killSession(s)
        end
    end
end

function Library:GetSession(id)
    local s = _sessions[id]
    if not s then return nil end
    return {
        id = s.id,
        active = s.active,
        type = s.moveType,
        target = s.targetPos,
    }
end

function Library:GetActiveSessions()
    local out = {}
    for id, s in pairs(_sessions) do
        if s.active then table.insert(out, id) end
    end
    return out
end
function Library:IsMoving(id)
    if id then
        local s = _sessions[id]
        return s ~= nil and s.active
    end
    for _, s in pairs(_sessions) do
        if s.active then return true end
    end
    return false
end

local _antiAfkConn
local _antiAfkHeartbeat

function Library:AntiAFK(config)
    config = config or {}
    local method = config.Method or "VirtualUser"

    self:StopAntiAFK()

    local player = Players.LocalPlayer

    if method == "VirtualUser" then
        local vu = Library.GetService("VirtualUser")

        _antiAfkConn = player.Idled:Connect(function()
            local camera = workspace.CurrentCamera
            local viewport = safeGet(camera, "ViewportSize") or Vector2.new(800, 600)
            local camCF = safeGet(camera, "CFrame") or CFrame.new()
            local pos = Vector2.new(
                math.random(0, math.max(1, math.floor(viewport.X))),
                math.random(0, math.max(1, math.floor(viewport.Y)))
            )
            pcall(function()
                vu:Button2Down(pos, camCF)
                task.wait(0.1)
                vu:Button2Up(pos, camCF)
            end)
        end)

    elseif method == "DisableIdled" then
        local ok, conns = pcall(getconnections, player.Idled)
        if ok and conns then
            for _, c in ipairs(conns) do
                pcall(function() c:Disable() end)
            end
        end

    elseif method == "Heartbeat" then
        local interval = config.Interval or 60
        local last = os.clock()
        _antiAfkHeartbeat = RunService.Heartbeat:Connect(function()
            if os.clock() - last < interval then return end
            last = os.clock()
            local char = player.Character
            local hum = char and findFirstChildOfClass(char, "Humanoid")
            if hum then
                safeSet(hum, "Jump", true)
            end
        end)
    end
end

function Library:StopAntiAFK()
    if _antiAfkConn then
        pcall(function() _antiAfkConn:Disconnect() end)
        _antiAfkConn = nil
    end
    if _antiAfkHeartbeat then
        pcall(function() _antiAfkHeartbeat:Disconnect() end)
        _antiAfkHeartbeat = nil
    end
end

return Library
