local Players = cloneref(game:GetService("Players"))
local RunService = cloneref(game:GetService("RunService"))
local TweenService = cloneref(game:GetService("TweenService"))

local function safeGet(inst, key)
    local ok, v = pcall(function() return inst[key] end)
    return ok and v or nil
end

local function isA(inst, cls)
    local ok, v = pcall(function() return inst:IsA(cls) end)
    return ok and v
end

local function findFirstChildOfClass(parent, class)
    local ok, children = pcall(function() return parent:GetChildren() end)
    if not ok then return nil end
    for _, c in ipairs(children) do
        if isA(c, class) then return c end
    end
end

local function toCFrame(target)
    if typeof(target) == "CFrame" then
        return target
    elseif typeof(target) == "Vector3" then
        return CFrame.new(target)
    end
    return CFrame.new(0, 0, 0)
end

local Library = {}

local _moveState = {
    active = false,
    connections = {},
}

local function _cleanupMove()
    _moveState.active = false
    for _, c in ipairs(_moveState.connections) do
        pcall(function() c:Disconnect() end)
    end
    _moveState.connections = {}
end

local function _addConn(conn)
    table.insert(_moveState.connections, conn)
end

local function _doMove(hrp, humanoid, moveType, targetCF, targetPos, speed, arriveRadius, onArrive, config)
    if moveType == "TP" then
        hrp.CFrame = targetCF
        task.defer(function()
            if onArrive then pcall(onArrive) end
            _cleanupMove()
        end)

    elseif moveType == "Tween" then
        local tweenTime = (speed <= 1 and speed or 1 / speed * (hrp.Position - targetPos).Magnitude)
        tweenTime = math.clamp(tweenTime, 0.05, 60)

        local tween = TweenService:Create(
            hrp,
            TweenInfo.new(tweenTime, Enum.EasingStyle.Linear),
            { CFrame = targetCF }
        )

        pcall(function()
            humanoid:ChangeState(Enum.HumanoidStateType.Physics)
        end)

        tween.Completed:Connect(function()
            if not _moveState.active then return end
            pcall(function()
                humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            end)
            if onArrive then pcall(onArrive) end
            _cleanupMove()
        end)

        tween:Play()

    elseif moveType == "Walk" then
        humanoid.WalkSpeed = speed
        humanoid:MoveTo(targetPos)

        local walkConn
        walkConn = RunService.Heartbeat:Connect(function()
            if not _moveState.active then return end
            local dist = (hrp.Position - targetPos).Magnitude
            if dist <= arriveRadius then
                if onArrive then task.defer(pcall, onArrive) end
                _cleanupMove()
            end
        end)
        _addConn(walkConn)

        local mtConn
        mtConn = humanoid.MoveToFinished:Connect(function(reached)
            if not _moveState.active then return end
            if reached then
                if onArrive then task.defer(pcall, onArrive) end
            end
            _cleanupMove()
        end)
        _addConn(mtConn)
    end
end

function Library:Move(config)
    config = config or {}

    local player = Players.LocalPlayer
    local character = player.Character or player.CharacterAdded:Wait()
    local hrp = character:WaitForChild("HumanoidRootPart", 10)
    local humanoid = findFirstChildOfClass(character, "Humanoid")

    if not hrp or not humanoid then
        warn("[Library:Move] Missing HumanoidRootPart or Humanoid")
        return
    end

    local targetCF = toCFrame(config.Target or Vector3.new(0, 0, 0))
    local targetPos = targetCF.Position
    local speed = config.Speed or 50
    local arriveRadius = config.ArriveRadius or 3
    local onArrive = config.OnArrive

    local safeDistance = config.SafeDistance
    local safeEnabled = safeDistance and safeDistance.Enabled
    local safeRadius = safeDistance and safeDistance.Distance or 0

    local baseType = config.Type or "TP"
    local moveType = baseType

    if config.TypeIfDistance then
        local dist = (hrp.Position - targetPos).Magnitude
        if dist <= (config.TypeIfDistance.Distance or 0) then
            moveType = config.TypeIfDistance.Type or baseType
        end
    end

    if safeEnabled then
        local dist = (hrp.Position - targetPos).Magnitude
        if dist <= safeRadius then
            local safeConn
            safeConn = RunService.Heartbeat:Connect(function()
                local char = player.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if not root then return end

                local currentDist = (root.Position - targetPos).Magnitude
                if currentDist > safeRadius then
                    safeConn:Disconnect()

                    _cleanupMove()
                    _moveState.active = true

                    if config.AntiFall then
                        pcall(function()
                            local hum = findFirstChildOfClass(char, "Humanoid")
                            if hum then
                                hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
                                hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
                            end
                        end)
                    end

                    if config.Noclip then
                        local noclipConn = RunService.Stepped:Connect(function()
                            if not _moveState.active then return end
                            for _, part in ipairs(char:GetDescendants()) do
                                if part:IsA("BasePart") then
                                    part.CanCollide = false
                                end
                            end
                        end)
                        _addConn(noclipConn)
                    end

                    local hum = findFirstChildOfClass(char, "Humanoid")
                    if root and hum then
                        local diedConn = hum.Died:Connect(function()
                            _cleanupMove()
                        end)
                        _addConn(diedConn)
                        _doMove(root, hum, moveType, targetCF, targetPos, speed, arriveRadius, onArrive, config)
                    end
                end
            end)
            return
        end
    end

    _cleanupMove()
    _moveState.active = true

    if config.AntiFall then
        pcall(function()
            humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        end)
    end

    if config.Noclip then
        local noclipConn = RunService.Stepped:Connect(function()
            if not _moveState.active then return end
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end)
        _addConn(noclipConn)
    end

    local diedConn = humanoid.Died:Connect(function()
        _cleanupMove()
    end)
    _addConn(diedConn)

    _doMove(hrp, humanoid, moveType, targetCF, targetPos, speed, arriveRadius, onArrive, config)
end

function Library:StopMove()
    _cleanupMove()
end

local _antiAfkConn

function Library:AntiAFK(config)
    config = config or {}
    local method = config.Method or "VirtualUser"

    if _antiAfkConn then
        pcall(function() _antiAfkConn:Disconnect() end)
        _antiAfkConn = nil
    end

    local player = Players.LocalPlayer

    if method == "VirtualUser" then
        local vu = cloneref(game:GetService("VirtualUser"))

        _antiAfkConn = player.Idled:Connect(function()
            if config.KeyPress then
                local ok, kc = pcall(function()
                    return Enum.KeyCode[config.KeyPress]
                end)
                if ok and kc then
                    vu:Button2Down(Vector2.new(0, 0), CFrame.new())
                    task.wait(0.1)
                    vu:Button2Up(Vector2.new(0, 0), CFrame.new())
                    return
                end
            end
            vu:Button2Down(Vector2.new(0, 0), CFrame.new())
            task.wait(0.1)
            vu:Button2Up(Vector2.new(0, 0), CFrame.new())
        end)

    elseif method == "DisableIdled" then
        local ok, conns = pcall(getconnections, player.Idled)
        if ok and conns then
            for _, c in ipairs(conns) do
                pcall(function() c:Disable() end)
            end
        end
    end
end

function Library:StopAntiAFK()
    if _antiAfkConn then
        pcall(function() _antiAfkConn:Disconnect() end)
        _antiAfkConn = nil
    end
end

return Library
