if getgenv().VasGG then
	pcall(function() getgenv().VasGG.Destroy() end)
end

local VasGG = {}
VasGG.__index = VasGG
getgenv().VasGG = VasGG

local Drawing = Drawing
local cam = workspace.CurrentCamera
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")


VasGG.Options = {
	Enabled = true,
	
	EspTeamCheck = false,        -- Hide teammates in ESP
	EspTeamColor = false,        -- Use team color for ESP boxes
	EspShowTeam = false,         -- Show [Team] next to name
	EspBlacklist = {},           -- Player names to ignore in ESP
	EspMaxDistance = 1000,       -- Max distance to show ESP
	EspWallCheck = false,        -- Hide ESP behind walls
	
	EspBox = true,
	EspBoxColor = Color3.fromRGB(255,255,255),
	EspBoxThickness = 1,
	EspBoxType = "2D",           -- "2D" or "Corner"
	EspCornerLength = 0.25,
	
	EspTracer = false,
	EspTracerColor = Color3.fromRGB(255,255,255),
	EspTracerThickness = 1,
	
	EspName = true,
	EspNameColor = Color3.fromRGB(255,255,255),
	
	EspDistance = true,
	
	EspHealthBar = true,
	EspHealthBarWidth = 4,
	
	EspScale = true,             -- Auto-scale ESP based on distance
	EspScaleMin = 0.3,           -- Minimum scale for far targets
	
	AimEnabled = false,
	AimMode = "Always",            -- "Hold" or "Always"
	AimKey = Enum.UserInputType.MouseButton2,
	AimPart = "Head",            -- "Head", "HumanoidRootPart", etc.
	AimFOV = 100,                -- Field of view (in pixels)
	AimSmoothness = 0.15,        -- 0 = instant, 1 = slow
	AimTeamCheck = false,        -- Don't aim at teammates
	AimWallCheck = false,        -- Don't aim through walls
	AimBlacklist = {},           -- Player names to ignore
	AimShowFOV = true,           -- Show FOV circle
	AimFOVColor = Color3.fromRGB(255,255,255),
}


local function newDrawing(class, props)
	local obj = Drawing.new(class)
	for k, v in pairs(props) do
		obj[k] = v
	end
	return obj
end

local function getBoundingBox(part)
	local size = part.Size
	local cf = part.CFrame
	local halfSize = size / 2
	
	local right = cf.RightVector * halfSize.X
	local up = cf.UpVector * halfSize.Y
	local back = cf.LookVector * halfSize.Z
	
	local center = cf.Position
	local corners = {
		center - right - up - back,
		center + right - up - back,
		center + right + up - back,
		center - right + up - back,
		center - right - up + back,
		center + right - up + back,
		center + right + up + back,
		center - right + up + back,
	}
	
	local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
	local onScreen = false
	
	for _, pos in ipairs(corners) do
		local screenPos, vis = cam:WorldToViewportPoint(pos)
		if vis then onScreen = true end
		minX = math.min(minX, screenPos.X)
		minY = math.min(minY, screenPos.Y)
		maxX = math.max(maxX, screenPos.X)
		maxY = math.max(maxY, screenPos.Y)
	end
	
	return minX, minY, maxX - minX, maxY - minY, onScreen
end

local function hasLineOfSight(targetPos, targetModel)
	local origin = cam.CFrame.Position
	local direction = targetPos - origin
	local distance = direction.Magnitude
	if distance == 0 then return true end
	
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {LocalPlayer.Character}
	rayParams.IgnoreWater = true
	
	local result = workspace:Raycast(origin, direction, rayParams)
	if not result then return true end
	if targetModel and result.Instance:IsDescendantOf(targetModel) then return true end
	return false
end

function VasGG.new(target, espType)
	local self = setmetatable({}, VasGG)
	self.Target = target
	self.Type = espType or "Player"
	
	self.Drawings = {
		Box = newDrawing("Square", {Visible = false, Color = VasGG.Options.EspBoxColor, Thickness = VasGG.Options.EspBoxThickness, Filled = false}),
		Corners = {},
		Tracer = newDrawing("Line", {Visible = false, Color = VasGG.Options.EspTracerColor, Thickness = VasGG.Options.EspTracerThickness}),
		Name = newDrawing("Text", {Visible = false, Color = VasGG.Options.EspNameColor, Size = 14, Center = true, Outline = true}),
		Distance = newDrawing("Text", {Visible = false, Color = VasGG.Options.EspNameColor, Size = 13, Center = true, Outline = true}),
		HealthBar = newDrawing("Square", {Visible = false, Color = Color3.fromRGB(0,255,0), Filled = true}),
		HealthBarBorder = newDrawing("Square", {Visible = false, Color = Color3.new(0,0,0), Filled = false, Thickness = 1}),
	}
	for i = 1, 8 do
		self.Drawings.Corners[i] = newDrawing("Line", {Visible = false, Color = VasGG.Options.EspBoxColor, Thickness = VasGG.Options.EspBoxThickness})
	end
	
	VasGG._objects = VasGG._objects or {}
	table.insert(VasGG._objects, self)
	return self
end

function VasGG:GetRootAndHealth()
	local charOrModel
	
	if self.Type == "Player" then
		charOrModel = self.Target.Character
		if not charOrModel then return nil end
	else
		charOrModel = self.Target
		if not charOrModel or not charOrModel.Parent then return nil end
	end
	
	local root = charOrModel:FindFirstChild("HumanoidRootPart") or charOrModel.PrimaryPart
	local hum = charOrModel:FindFirstChildOfClass("Humanoid")
	
	if not root then return nil end
	
	local health = hum and hum.Health or 100
	local maxHealth = hum and hum.MaxHealth or 100
	
	return root, health, maxHealth, charOrModel
end

function VasGG:HideAll()
	for k, d in pairs(self.Drawings) do
		if k == "Corners" then
			for _, line in ipairs(d) do line.Visible = false end
		else
			d.Visible = false
		end
	end
end

function VasGG:Update()
	local opt = VasGG.Options
	if not opt.Enabled then
		self:HideAll()
		return
	end
	
	local root, health, maxHealth, charOrModel = self:GetRootAndHealth()
	if not root then
		self:HideAll()
		return
	end
	
	if self.Type == "Player" then
		for _, name in ipairs(opt.EspBlacklist) do
			if self.Target.Name == name then
				self:HideAll()
				return
			end
		end
	end
	
	if self.Type == "Player" and opt.EspTeamCheck and self.Target.Team == LocalPlayer.Team then
		self:HideAll()
		return
	end
	
	local dist = (cam.CFrame.Position - root.Position).Magnitude
	if dist > opt.EspMaxDistance then
		self:HideAll()
		return
	end
	
	if opt.EspWallCheck and not hasLineOfSight(root.Position, charOrModel) then
		self:HideAll()
		return
	end
	
	local part = charOrModel:FindFirstChild("HumanoidRootPart") or root
	local x, y, w, h, onScreen = getBoundingBox(part)
	if not onScreen then
		self:HideAll()
		return
	end
	
	local scale = 1
	if opt.EspScale then
		scale = math.clamp(1 - ((dist - 50) / 500), opt.EspScaleMin, 1)
	end
	
	local d = self.Drawings
	local boxColor = opt.EspBoxColor
	
	if self.Type == "Player" and opt.EspTeamColor and self.Target.Team then
		boxColor = self.Target.Team.TeamColor.Color
	end
	
	if opt.EspBox then
		if opt.EspBoxType == "Corner" then
			d.Box.Visible = false
			local cl = opt.EspCornerLength
			local lw, lh = w * cl, h * cl
			local corners = {
				{Vector2.new(x,y), Vector2.new(x+lw,y)}, {Vector2.new(x,y), Vector2.new(x,y+lh)},
				{Vector2.new(x+w,y), Vector2.new(x+w-lw,y)}, {Vector2.new(x+w,y), Vector2.new(x+w,y+lh)},
				{Vector2.new(x,y+h), Vector2.new(x+lw,y+h)}, {Vector2.new(x,y+h), Vector2.new(x,y+h-lh)},
				{Vector2.new(x+w,y+h), Vector2.new(x+w-lw,y+h)}, {Vector2.new(x+w,y+h), Vector2.new(x+w,y+h-lh)},
			}
			for i, line in ipairs(d.Corners) do
				line.From = corners[i][1]
				line.To = corners[i][2]
				line.Color = boxColor
				line.Thickness = opt.EspBoxThickness * scale
				line.Visible = true
			end
		else
			for _, l in ipairs(d.Corners) do l.Visible = false end
			d.Box.Position = Vector2.new(x, y)
			d.Box.Size = Vector2.new(w, h)
			d.Box.Color = boxColor
			d.Box.Thickness = opt.EspBoxThickness * scale
			d.Box.Visible = true
		end
	else
		d.Box.Visible = false
		for _, l in ipairs(d.Corners) do l.Visible = false end
	end
	
	if opt.EspTracer then
		local originX = cam.ViewportSize.X / 2
		local originY = cam.ViewportSize.Y
		d.Tracer.From = Vector2.new(originX, originY)
		d.Tracer.To = Vector2.new(x + w/2, y + h)
		d.Tracer.Color = opt.EspTracerColor
		d.Tracer.Thickness = opt.EspTracerThickness * scale
		d.Tracer.Visible = true
	else
		d.Tracer.Visible = false
	end
	
	if opt.EspName then
		local nameText = self.Type == "Player" and self.Target.Name or charOrModel.Name
		if self.Type == "Player" and opt.EspShowTeam and self.Target.Team then
			nameText = nameText .. " [" .. self.Target.Team.Name .. "]"
		end
		d.Name.Text = nameText
		d.Name.Position = Vector2.new(x + w/2, y - 18 * scale)
		d.Name.Color = opt.EspNameColor
		d.Name.Size = math.floor(14 * scale)
		d.Name.Visible = true
	else
		d.Name.Visible = false
	end
	
	if opt.EspDistance then
		d.Distance.Text = string.format("%d studs", math.floor(dist))
		d.Distance.Position = Vector2.new(x + w/2, y + h + 4 * scale)
		d.Distance.Color = opt.EspNameColor
		d.Distance.Size = math.floor(13 * scale)
		d.Distance.Visible = true
	else
		d.Distance.Visible = false
	end
	
	if opt.EspHealthBar and maxHealth > 0 then
		local pct = math.clamp(health / maxHealth, 0, 1)
		local barWidth = opt.EspHealthBarWidth * scale
		local barX = x - barWidth - 2 * scale
		
		d.HealthBarBorder.Position = Vector2.new(barX - 1 * scale, y - 1 * scale)
		d.HealthBarBorder.Size = Vector2.new(barWidth + 2 * scale, h + 2 * scale)
		d.HealthBarBorder.Color = Color3.new(0, 0, 0)
		d.HealthBarBorder.Thickness = 1 * scale
		d.HealthBarBorder.Visible = true
		
		d.HealthBar.Position = Vector2.new(barX, y + h * (1 - pct))
		d.HealthBar.Size = Vector2.new(barWidth, h * pct)
		d.HealthBar.Color = Color3.fromHSV(pct * 0.33, 1, 1)
		d.HealthBar.Visible = true
	else
		d.HealthBarBorder.Visible = false
		d.HealthBar.Visible = false
	end
end

function VasGG:Remove()
	for k, d in pairs(self.Drawings) do
		if k == "Corners" then
			for _, line in ipairs(d) do line:Remove() end
		else
			d:Remove()
		end
	end
	
	for i, obj in ipairs(VasGG._objects) do
		if obj == self then
			table.remove(VasGG._objects, i)
			break
		end
	end
end


function VasGG.AddPlayer(player)
	if player == LocalPlayer then return end
	for _, obj in ipairs(VasGG._objects or {}) do
		if obj.Target == player then return end
	end
	return VasGG.new(player, "Player")
end

function VasGG.AddPlayers()
	VasGG._objects = VasGG._objects or {}
	VasGG._conns = VasGG._conns or {}
	
	for _, plr in ipairs(Players:GetPlayers()) do
		VasGG.AddPlayer(plr)
	end
	
	table.insert(VasGG._conns, Players.PlayerAdded:Connect(VasGG.AddPlayer))
	table.insert(VasGG._conns, Players.PlayerRemoving:Connect(function(plr)
		for i, obj in ipairs(VasGG._objects) do
			if obj.Target == plr then
				obj:Remove()
				break
			end
		end
	end))
end

function VasGG.AddNPCsByTag(tag)
	VasGG._objects = VasGG._objects or {}
	VasGG._conns = VasGG._conns or {}
	
	local function addNPC(model)
		if not model or not model.Parent then return end
		for _, obj in ipairs(VasGG._objects) do
			if obj.Target == model then return end
		end
		if model:FindFirstChild("Humanoid") or model:FindFirstChild("HumanoidRootPart") then
			VasGG.new(model, "NPC")
		end
	end
	
	for _, model in ipairs(CollectionService:GetTagged(tag)) do
		addNPC(model)
	end
	
	table.insert(VasGG._conns, CollectionService:GetInstanceAddedSignal(tag):Connect(addNPC))
	table.insert(VasGG._conns, CollectionService:GetInstanceRemovedSignal(tag):Connect(function(model)
		for i, obj in ipairs(VasGG._objects) do
			if obj.Target == model then
				obj:Remove()
				break
			end
		end
	end))
end


function VasGG.Init()
	VasGG._objects = VasGG._objects or {}
	VasGG._conn = RunService.RenderStepped:Connect(function()
		cam = workspace.CurrentCamera
		for _, obj in ipairs(VasGG._objects) do
			obj:Update()
		end
	end)
end



local fovCircle = newDrawing("Circle", {Visible = false, Thickness = 1, Color = Color3.fromRGB(255,255,255), Filled = false, NumSides = 48})

local function isHolding()
	if VasGG.Options.AimMode == "Always" then return true end
	if typeof(VasGG.Options.AimKey) == "EnumItem" then
		if VasGG.Options.AimKey.EnumType == Enum.UserInputType then
			return UserInputService:IsMouseButtonPressed(VasGG.Options.AimKey)
		elseif VasGG.Options.AimKey.EnumType == Enum.KeyCode then
			return UserInputService:IsKeyDown(VasGG.Options.AimKey)
		end
	end
	return false
end

local function getAimPart(obj)
	local root, _, _, charOrModel = obj:GetRootAndHealth()
	if not root then return nil end
	local part = charOrModel:FindFirstChild(VasGG.Options.AimPart) or root
	return part, charOrModel
end

local function getBestTarget()
	local opt = VasGG.Options
	local mouseLoc = UserInputService:GetMouseLocation()
	local best, bestDist = nil, opt.AimFOV
	
	for _, obj in ipairs(VasGG._objects or {}) do
		if obj.Type ~= "Player" then continue end
		
		if opt.AimTeamCheck and obj.Target.Team == LocalPlayer.Team then continue end
		
		local blacklisted = false
		for _, name in ipairs(opt.AimBlacklist) do
			if obj.Target.Name == name then blacklisted = true break end
		end
		if blacklisted then continue end
		
		local part, model = getAimPart(obj)
		if part then
			local screenPos, vis = cam:WorldToViewportPoint(part.Position)
			if vis and (not opt.AimWallCheck or hasLineOfSight(part.Position, model)) then
				local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - mouseLoc).Magnitude
				if screenDist < bestDist then
					bestDist = screenDist
					best = part
				end
			end
		end
	end
	return best
end

function VasGG.AimbotStep()
	local opt = VasGG.Options
	
	if opt.AimShowFOV and opt.AimEnabled then
		local mouseLoc = UserInputService:GetMouseLocation()
		fovCircle.Position = mouseLoc
		fovCircle.Radius = opt.AimFOV
		fovCircle.Color = opt.AimFOVColor
		fovCircle.Visible = true
	else
		fovCircle.Visible = false
	end
	
	if not opt.AimEnabled or not isHolding() then return end
	
	local targetPart = getBestTarget()
	if not targetPart then return end
	
	local targetPos = targetPart.Position
	local camCF = cam.CFrame
	local goalCF = CFrame.new(camCF.Position, targetPos)
	cam.CFrame = camCF:Lerp(goalCF, opt.AimSmoothness)
end

function VasGG.InitAimbot()
	VasGG._aimConn = RunService.RenderStepped:Connect(VasGG.AimbotStep)
end


function VasGG.Destroy()
	if VasGG._conn then VasGG._conn:Disconnect() end
	if VasGG._aimConn then VasGG._aimConn:Disconnect() end
	for _, c in ipairs(VasGG._conns or {}) do c:Disconnect() end
	
	for _, obj in ipairs(VasGG._objects or {}) do
		obj:Remove()
	end
	
	VasGG._objects = {}
	VasGG._conns = {}
	
	fovCircle.Visible = false
	
	if Drawing.clear then
		pcall(Drawing.clear)
	elseif cleardrawcache then
		pcall(cleardrawcache)
	end
end

return VasGG
