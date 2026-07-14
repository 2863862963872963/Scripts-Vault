-- Ensure old instances are destroyed safely upon re-execution
if getgenv().VasGG then
	pcall(function() getgenv().VasGG.Destroy() end)
end

local VasGG = {}
VasGG.__index = VasGG
getgenv().VasGG = VasGG

-- Service Optimization Cache
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")

-- Localization & Variable Cache
local Drawing = Drawing
local cam = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local math_min, math_max, math_huge, math_clamp, math_floor = math.min, math.max, math.huge, math.clamp, math.floor
local table_insert, table_remove = table.insert, table.remove
local Vector3_new, Vector2_new, CFrame_new, Color3_fromRGB = Vector3.new, Vector2.new, CFrame.new, Color3.fromRGB

-- Geometry & Config Configuration Data
local CUBE_EDGES = {
	{1,2},{2,3},{3,4},{4,1},
	{5,6},{6,7},{7,8},{8,5},
	{1,5},{2,6},{3,7},{4,8},
}

local VERTICES = {
	Vector3_new(-1,-1,-1), Vector3_new(-1,-1,1), Vector3_new(-1,1,-1), Vector3_new(-1,1,1),
	Vector3_new(1,-1,-1), Vector3_new(1,-1,1), Vector3_new(1,1,-1), Vector3_new(1,1,1)
}

local SIGNS = {
	Vector3_new(-1,-1,-1), Vector3_new(1,-1,-1), Vector3_new(1,1,-1), Vector3_new(-1,1,-1),
	Vector3_new(-1,-1,1), Vector3_new(1,-1,1), Vector3_new(1,1,1), Vector3_new(-1,1,1),
}

-- Default Library Options
VasGG.Options = {
	Enabled = true,
	TeamCheck = false,
	MaxDistance = 1000,
	Box = true,
	BoxColor = Color3_fromRGB(255,255,255),
	BoxThickness = 1,
	BoxType = "2D",
	CornerLength = 0.25,
	Tracer = false,
	TracerColor = Color3_fromRGB(255,255,255),
	TracerThickness = 1,
	TracerOrigin = "Bottom",
	Name = true,
	NameColor = Color3_fromRGB(255,255,255),
	Distance = true,
	HealthBar = true,
	HealthBarWidth = 4,
	Tracking = false,
	TrackingColor = Color3_fromRGB(255,0,0),
	DistanceScale = true,
	ScaleMin = 0.5,
	ScaleMaxDistance = 500,
	Highlight = false,
	HighlightFillColor = Color3_fromRGB(255,0,0),
	HighlightOutlineColor = Color3_fromRGB(255,255,255),
	HighlightFillTransparency = 0.5,
	HighlightOutlineTransparency = 0,
	HighlightDepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
	Aimbot = false,
	AimMode = "Hold",
	AimKey = Enum.UserInputType.MouseButton2,
	AimPart = "Head",
	AimFOV = 100,
	AimSmoothness = 0.15,
	AimTeamCheck = false,
	ShowFOVCircle = true,
	WallCheck = false,
}

-- internal data trackers
VasGG._objects = {}
VasGG._conns = {}

-- Utility Drawing Constructor
local function newDrawing(class, props)
	local obj = Drawing.new(class)
	for k, v in pairs(props) do
		obj[k] = v
	end
	return obj
}

-- Global FOV Circle Creation
local fovCircle = newDrawing("Circle", {Visible = false, Thickness = 1, Color = Color3_fromRGB(255,255,255), Filled = false, NumSides = 48})

-- Geometric Utility Functions
local function getWH(part)
	local size = part.Size
	local cf = part.CFrame
	local minX, minY, maxX, maxY = math_huge, math_huge, -math_huge, -math_huge
	local onScreen = false
	
	for i = 1, 8 do
		local worldPos = cf:PointToWorldSpace(VERTICES[i] * (size * 0.5))
		local screenPos, vis = cam:WorldToViewportPoint(worldPos)
		if vis then onScreen = true end
		minX = math_min(minX, screenPos.X)
		minY = math_min(minY, screenPos.Y)
		maxX = math_max(maxX, screenPos.X)
		maxY = math_max(maxY, screenPos.Y)
	end
	return minX, minY, maxX - minX, maxY - minY, onScreen
end

local function get3DCorners(part)
	local size = part.Size
	local cf = part.CFrame
	local pts = {}
	local allOnScreen = true
	
	for i = 1, 8 do
		local worldPos = cf:PointToWorldSpace(SIGNS[i] * (size * 0.5))
		local screenPos, vis = cam:WorldToViewportPoint(worldPos)
		if not vis then allOnScreen = false end
		pts[i] = Vector2_new(screenPos.X, screenPos.Y)
	end
	return pts, allOnScreen
end

local function hasLineOfSight(targetPos, targetModel)
	local origin = cam.CFrame.Position
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {LocalPlayer.Character}
	rayParams.IgnoreWater = true
	
	local result = workspace:Raycast(origin, (targetPos - origin), rayParams)
	if not result then return true end
	if targetModel and result.Instance:IsDescendantOf(targetModel) then return true end
	return false
end

-- Core OOP Methods
function VasGG.new(target, espType)
	local self = setmetatable({}, VasGG)
	self.Target = target
	self.Type = espType or "Player"
	self.Visible = true

	self.Drawings = {
		Box = newDrawing("Square", {Visible = false, Color = VasGG.Options.BoxColor, Thickness = VasGG.Options.BoxThickness, Filled = false}),
		Corners = {},
		Cube = {},
		Tracer = newDrawing("Line", {Visible = false, Color = VasGG.Options.TracerColor, Thickness = VasGG.Options.TracerThickness}),
		Name = newDrawing("Text", {Visible = false, Color = VasGG.Options.NameColor, Size = 14, Center = true, Outline = true}),
		Distance = newDrawing("Text", {Visible = false, Color = VasGG.Options.NameColor, Size = 13, Center = true, Outline = true}),
		HealthBarBG = newDrawing("Square", {Visible = false, Color = Color3_fromRGB(0,0,0), Filled = true}),
		HealthBar = newDrawing("Square", {Visible = false, Color = Color3_fromRGB(0,255,0), Filled = true}),
	}
	
	for i = 1, 8 do
		self.Drawings.Corners[i] = newDrawing("Line", {Visible = false, Color = VasGG.Options.BoxColor, Thickness = VasGG.Options.BoxThickness})
	end
	for i = 1, 12 do
		self.Drawings.Cube[i] = newDrawing("Line", {Visible = false, Color = VasGG.Options.BoxColor, Thickness = VasGG.Options.BoxThickness})
	end
	self.HighlightObj = nil

	table_insert(VasGG._objects, self)
	return self
end

function VasGG:GetRootAndHealth()
	if self.Type == "Player" then
		local char = self.Target.Character
		if not char then return nil end
		local root = char:FindFirstChild("HumanoidRootPart")
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not root or not hum then return nil end
		return root, hum.Health, hum.MaxHealth, char
	else
		local model = self.Target
		if not model or not model.Parent then return nil end
		local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
		local hum = model:FindFirstChildOfClass("Humanoid")
		if not root then return nil end
		return root, hum and hum.Health or 1, hum and hum.MaxHealth or 1, model
	end
end

function VasGG:HideAll()
	for k, d in pairs(self.Drawings) do
		if k == "Corners" or k == "Cube" then
			for _, line in ipairs(d) do line.Visible = false end
		else
			d.Visible = false
		end
	end
	if self.HighlightObj then
		self.HighlightObj.Enabled = false
	end
end

function VasGG:Update()
	local opt = VasGG.Options
	if not opt.Enabled or not self.Visible then
		self:HideAll()
		return
	end

	local root, health, maxHealth, charOrModel = self:GetRootAndHealth()
	if not root then
		self:HideAll()
		return
	end

	if self.Type == "Player" and opt.TeamCheck and self.Target.Team == LocalPlayer.Team then
		self:HideAll()
		return
	end

	local dist = (cam.CFrame.Position - root.Position).Magnitude
	if dist > opt.MaxDistance then
		self:HideAll()
		return
	end

	local scale = 1
	if opt.DistanceScale then
		scale = math_clamp(1 - (dist / opt.ScaleMaxDistance), opt.ScaleMin, 1)
	end

	local part = charOrModel:FindFirstChild("HumanoidRootPart") or root
	if opt.WallCheck and not hasLineOfSight(part.Position, charOrModel) then
		self:HideAll()
		return
	end
	
	local x, y, w, h, onScreen = getWH(part)
	if not onScreen then
		self:HideAll()
		return
	end

	local d = self.Drawings

	if opt.Box then
		if opt.BoxType == "Corner" then
			d.Box.Visible = false
			for i = 1, 12 do d.Cube[i].Visible = false end
			local cl = math_clamp(opt.CornerLength, 0.05, 0.5)
			local lw, lh = w * cl, h * cl
			local corners = {
				{Vector2_new(x,y), Vector2_new(x+lw,y)}, {Vector2_new(x,y), Vector2_new(x,y+lh)},
				{Vector2_new(x+w,y), Vector2_new(x+w-lw,y)}, {Vector2_new(x+w,y), Vector2_new(x+w,y+lh)},
				{Vector2_new(x,y+h), Vector2_new(x+lw,y+h)}, {Vector2_new(x,y+h), Vector2_new(x,y+h-lh)},
				{Vector2_new(x+w,y+h), Vector2_new(x+w-lw,y+h)}, {Vector2_new(x+w,y+h), Vector2_new(x+w,y+h-lh)},
			}
			for i, line in ipairs(d.Corners) do
				line.From = corners[i][1]
				line.To = corners[i][2]
				line.Color = opt.BoxColor
				line.Thickness = opt.BoxThickness * scale
				line.Visible = true
			end
		elseif opt.BoxType == "3D" then
			d.Box.Visible = false
			for i = 1, 8 do d.Corners[i].Visible = false end
			local pts, onScreen3D = get3DCorners(part)
			for i, edge in ipairs(CUBE_EDGES) do
				local line = d.Cube[i]
				line.From = pts[edge[1]]
				line.To = pts[edge[2]]
				line.Color = opt.BoxColor
				line.Thickness = opt.BoxThickness * scale
				line.Visible = onScreen3D
			end
		else
			for i = 1, 8 do d.Corners[i].Visible = false end
			for i = 1, 12 do d.Cube[i].Visible = false end
			d.Box.Position = Vector2_new(x, y)
			d.Box.Size = Vector2_new(w, h)
			d.Box.Color = opt.BoxColor
			d.Box.Thickness = opt.BoxThickness * scale
			d.Box.Visible = true
		end
	else
		d.Box.Visible = false
		for i = 1, 8 do d.Corners[i].Visible = false end
		for i = 1, 12 do d.Cube[i].Visible = false end
	end

	if opt.Highlight then
		if not self.HighlightObj or not self.HighlightObj.Parent then
			self.HighlightObj = Instance.new("Highlight")
			self.HighlightObj.Parent = charOrModel
		end
		self.HighlightObj.FillColor = opt.HighlightFillColor
		self.HighlightObj.OutlineColor = opt.HighlightOutlineColor
		self.HighlightObj.FillTransparency = opt.HighlightFillTransparency
		self.HighlightObj.OutlineTransparency = opt.HighlightOutlineTransparency
		self.HighlightObj.DepthMode = opt.HighlightDepthMode
		self.HighlightObj.Enabled = true
	elseif self.HighlightObj then
		self.HighlightObj.Enabled = false
	end

	if opt.Tracer then
		local originX = cam.ViewportSize.X / 2
		local originY = opt.TracerOrigin == "Top" and 0 or cam.ViewportSize.Y
		d.Tracer.From = Vector2_new(originX, originY)
		d.Tracer.To = Vector2_new(x + w * 0.5, y + h)
		d.Tracer.Color = opt.TracerColor
		d.Tracer.Thickness = opt.TracerThickness
		d.Tracer.Visible = true
	else
		d.Tracer.Visible = false
	end

	if opt.Name then
		d.Name.Text = self.Type == "Player" and self.Target.Name or charOrModel.Name
		d.Name.Position = Vector2_new(x + w * 0.5, y - 16 * scale)
		d.Name.Color = opt.NameColor
		d.Name.Size = math_floor(14 * scale)
		d.Name.Visible = true
	else
		d.Name.Visible = false
	end

	if opt.Distance then
		d.Distance.Text = string.format("%d studs", dist)
		d.Distance.Position = Vector2_new(x + w * 0.5, y + h + 2)
		d.Distance.Color = opt.NameColor
		d.Distance.Size = math_floor(13 * scale)
		d.Distance.Visible = true
	else
		d.Distance.Visible = false
	end

	if opt.HealthBar and maxHealth > 0 then
		local pct = math_clamp(health / maxHealth, 0, 1)
		local barWidth = opt.HealthBarWidth * scale
		d.HealthBarBG.Position = Vector2_new(x - barWidth - 2, y)
		d.HealthBarBG.Size = Vector2_new(barWidth, h)
		d.HealthBarBG.Visible = true

		d.HealthBar.Position = Vector2.new(x - barWidth - 2, y + h * (1 - pct))
		d.HealthBar.Size = Vector2_new(barWidth, h * pct)
		d.HealthBar.Color = Color3.fromHSV(pct * 0.33, 1, 1)
		d.HealthBar.Visible = true
	else
		d.HealthBarBG.Visible = false
		d.HealthBar.Visible = false
	end
end

function VasGG:Remove()
	for k, d in pairs(self.Drawings) do
		if k == "Corners" or k == "Cube" then
			for _, line in ipairs(d) do pcall(function() line:Remove() end) end
		else
			pcall(function() d:Remove() end)
		end
	end
	if self.HighlightObj then
		pcall(function() self.HighlightObj:Destroy() end)
	end
	for i, obj in ipairs(VasGG._objects) do
		if obj == self then
			table_remove(VasGG._objects, i)
			break
		end
	end
end

-- Input checking utilities for Aimbot functionality
local function isHolding()
	local opt = VasGG.Options
	if opt.AimMode == "Always" then
		return true
	end
	if typeof(opt.AimKey) == "EnumItem" then
		if opt.AimKey.EnumType == Enum.UserInputType then
			return UserInputService:IsMouseButtonPressed(opt.AimKey)
		elseif opt.AimKey.EnumType == Enum.KeyCode then
			return UserInputService:IsKeyDown(opt.AimKey)
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
	
	for _, obj in ipairs(VasGG._objects) do
		if obj.Type == "Player" and opt.AimTeamCheck and obj.Target.Team == LocalPlayer.Team then
			continue
		end
		local part, model = getAimPart(obj)
		if part then
			local screenPos, vis = cam:WorldToViewportPoint(part.Position)
			if vis and (not opt.WallCheck or hasLineOfSight(part.Position, model)) then
				local screenDist = (Vector2_new(screenPos.X, screenPos.Y) - mouseLoc).Magnitude
				if screenDist < bestDist then
					bestDist = screenDist
					best = part
				end
			end
		end
	end
	return best
end

-- Optimization: Handled step function internally in single Main loop
function VasGG.AimbotStep()
	local opt = VasGG.Options
	if opt.ShowFOVCircle and opt.Aimbot then
		local mouseLoc = UserInputService:GetMouseLocation()
		fovCircle.Position = mouseLoc
		fovCircle.Radius = opt.AimFOV
		fovCircle.Color = opt.HighlightOutlineColor
		fovCircle.Visible = true
	else
		fovCircle.Visible = false
	end

	if not opt.Aimbot or not isHolding() then return end

	local targetPart = getBestTarget()
	if not targetPart then return end

	local camCF = cam.CFrame
	local goalCF = CFrame_new(camCF.Position, targetPart.Position)
	cam.CFrame = camCF:Lerp(goalCF, opt.AimSmoothness)
end

-- Connections Management Setup
function VasGG.AddPlayer(player)
	if player == LocalPlayer then return end
	return VasGG.new(player, "Player")
end

function VasGG.AddPlayers()
	for _, plr in ipairs(Players:GetPlayers()) do
		VasGG.AddPlayer(plr)
	end
	table_insert(VasGG._conns, Players.PlayerAdded:Connect(VasGG.AddPlayer))
	table_insert(VasGG._conns, Players.PlayerRemoving:Connect(function(plr)
		for _, obj in ipairs(VasGG._objects) do
			if obj.Target == plr then
				obj:Remove()
				break
			end
		end
	end))
end

function VasGG.AddNPCsByTag(tag)
	for _, model in ipairs(CollectionService:GetTagged(tag)) do
		VasGG.new(model, "NPC")
	end
	table_insert(VasGG._conns, CollectionService:GetInstanceAddedSignal(tag):Connect(function(model)
		VasGG.new(model, "NPC")
	end))
	table_insert(VasGG._conns, CollectionService:GetInstanceRemovedSignal(tag):Connect(function(model)
		for _, obj in ipairs(VasGG._objects) do
			if obj.Target == model then
				obj:Remove()
				break
			end
		end
	end))
end

-- Main Processing Engine Initializer
function VasGG.Init()
	VasGG._conn = RunService.RenderStepped:Connect(function()
		cam = workspace.CurrentCamera
		
		-- Batch ESP Processing
		for _, obj in ipairs(VasGG._objects) do
			obj:Update()
		end
		
		-- Batch Aimbot Logic step calculation
		VasGG.AimbotStep()
	end)
end

function VasGG.Destroy()
	if VasGG._conn then VasGG._conn:Disconnect() VasGG._conn = nil end
	for _, c in ipairs(VasGG._conns) do c:Disconnect() end
	VasGG._conns = {}
	
	for _, obj in ipairs(VasGG._objects) do
		obj:Remove()
	end
	VasGG._objects = {}
	
	pcall(function() fovCircle.Visible = false fovCircle:Remove() end)
	
	if Drawing.clear then
		pcall(Drawing.clear)
	elseif cleardrawcache then
		pcall(cleardrawcache)
	end
end

return VasGG
