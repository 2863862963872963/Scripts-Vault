if getgenv().VasGG then
	pcall(function() getgenv().VasGG.Destroy() end)
end

local VasGG = {}
VasGG.__index = VasGG
getgenv().VasGG = VasGG

local Drawing = Drawing
local cam = workspace.CurrentCamera
local hasLineOfSight
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")

VasGG.Options = {
	Enabled = true,
	TeamCheck = false,
	MaxDistance = 1000,
	Box = true,
	BoxColor = Color3.fromRGB(255,255,255),
	BoxThickness = 1,
	BoxType = "2D",
	CornerLength = 0.25,
	Tracer = false,
	TracerColor = Color3.fromRGB(255,255,255),
	TracerThickness = 1,
	TracerOrigin = "Bottom",
	Name = true,
	NameColor = Color3.fromRGB(255,255,255),
	Distance = true,
	HealthBar = true,
	HealthBarWidth = 4,
	Tracking = false,
	TrackingColor = Color3.fromRGB(255,0,0),
	DistanceScale = true,
	ScaleMin = 0.5,
	ScaleMaxDistance = 500,
	Highlight = false,
	HighlightFillColor = Color3.fromRGB(255,0,0),
	HighlightOutlineColor = Color3.fromRGB(255,255,255),
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

local function newDrawing(class, props)
	local obj = Drawing.new(class)
	for k, v in pairs(props) do
		obj[k] = v
	end
	return obj
end

local function getWH(part)
	local vertices = {
		Vector3.new(-1,-1,-1), Vector3.new(-1,-1,1), Vector3.new(-1,1,-1), Vector3.new(-1,1,1),
		Vector3.new(1,-1,-1), Vector3.new(1,-1,1), Vector3.new(1,1,-1), Vector3.new(1,1,1)
	}
	local size = part.Size
	local cf = part.CFrame
	local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
	local onScreen = false
	for _, v in ipairs(vertices) do
		local worldPos = cf:PointToWorldSpace(v * (size/2))
		local screenPos, vis = cam:WorldToViewportPoint(worldPos)
		if vis then onScreen = true end
		minX = math.min(minX, screenPos.X)
		minY = math.min(minY, screenPos.Y)
		maxX = math.max(maxX, screenPos.X)
		maxY = math.max(maxY, screenPos.Y)
	end
	return minX, minY, maxX - minX, maxY - minY, onScreen
end

local function get3DCorners(part)
	local size = part.Size
	local cf = part.CFrame
	local pts = {}
	local signs = {
		Vector3.new(-1,-1,-1), Vector3.new(1,-1,-1), Vector3.new(1,1,-1), Vector3.new(-1,1,-1),
		Vector3.new(-1,-1,1), Vector3.new(1,-1,1), Vector3.new(1,1,1), Vector3.new(-1,1,1),
	}
	local allOnScreen = true
	for i, s in ipairs(signs) do
		local worldPos = cf:PointToWorldSpace(s * (size/2))
		local screenPos, vis = cam:WorldToViewportPoint(worldPos)
		if not vis then allOnScreen = false end
		pts[i] = Vector2.new(screenPos.X, screenPos.Y)
	end
	return pts, allOnScreen
end

local CUBE_EDGES = {
	{1,2},{2,3},{3,4},{4,1},
	{5,6},{6,7},{7,8},{8,5},
	{1,5},{2,6},{3,7},{4,8},
}

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
		HealthBarBG = newDrawing("Square", {Visible = false, Color = Color3.new(0,0,0), Filled = true}),
		HealthBar = newDrawing("Square", {Visible = false, Color = Color3.fromRGB(0,255,0), Filled = true}),
	}
	for i = 1, 8 do
		self.Drawings.Corners[i] = newDrawing("Line", {Visible = false, Color = VasGG.Options.BoxColor, Thickness = VasGG.Options.BoxThickness})
	end
	for i = 1, 12 do
		self.Drawings.Cube[i] = newDrawing("Line", {Visible = false, Color = VasGG.Options.BoxColor, Thickness = VasGG.Options.BoxThickness})
	end
	self.HighlightObj = nil

	VasGG._objects = VasGG._objects or {}
	table.insert(VasGG._objects, self)
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
		scale = math.clamp(1 - (dist / opt.ScaleMaxDistance), opt.ScaleMin, 1)
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
			for _, l in ipairs(d.Cube) do l.Visible = false end
			local cl = math.clamp(opt.CornerLength, 0.05, 0.5)
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
				line.Color = opt.BoxColor
				line.Thickness = opt.BoxThickness * scale
				line.Visible = true
			end
		elseif opt.BoxType == "3D" then
			d.Box.Visible = false
			for _, l in ipairs(d.Corners) do l.Visible = false end
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
			for _, l in ipairs(d.Corners) do l.Visible = false end
			for _, l in ipairs(d.Cube) do l.Visible = false end
			d.Box.Position = Vector2.new(x, y)
			d.Box.Size = Vector2.new(w, h)
			d.Box.Color = opt.BoxColor
			d.Box.Thickness = opt.BoxThickness * scale
			d.Box.Visible = true
		end
	else
		d.Box.Visible = false
		for _, l in ipairs(d.Corners) do l.Visible = false end
		for _, l in ipairs(d.Cube) do l.Visible = false end
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
		d.Tracer.From = Vector2.new(originX, originY)
		d.Tracer.To = Vector2.new(x + w/2, y + h)
		d.Tracer.Color = opt.TracerColor
		d.Tracer.Thickness = opt.TracerThickness
		d.Tracer.Visible = true
	else
		d.Tracer.Visible = false
	end

	if opt.Name then
		d.Name.Text = self.Type == "Player" and self.Target.Name or charOrModel.Name
		d.Name.Position = Vector2.new(x + w/2, y - 16 * scale)
		d.Name.Color = opt.NameColor
		d.Name.Size = math.floor(14 * scale)
		d.Name.Visible = true
	else
		d.Name.Visible = false
	end

	if opt.Distance then
		d.Distance.Text = string.format("%d studs", dist)
		d.Distance.Position = Vector2.new(x + w/2, y + h + 2)
		d.Distance.Color = opt.NameColor
		d.Distance.Size = math.floor(13 * scale)
		d.Distance.Visible = true
	else
		d.Distance.Visible = false
	end

	if opt.HealthBar and maxHealth > 0 then
		local pct = math.clamp(health / maxHealth, 0, 1)
		local barWidth = opt.HealthBarWidth * scale
		d.HealthBarBG.Position = Vector2.new(x - barWidth - 2, y)
		d.HealthBarBG.Size = Vector2.new(barWidth, h)
		d.HealthBarBG.Visible = true

		d.HealthBar.Position = Vector2.new(x - barWidth - 2, y + h * (1 - pct))
		d.HealthBar.Size = Vector2.new(barWidth, h * pct)
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
			for _, line in ipairs(d) do line:Remove() end
		else
			d:Remove()
		end
	end
	if self.HighlightObj then
		self.HighlightObj:Destroy()
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
		for _, obj in ipairs(VasGG._objects) do
			if obj.Target == plr then
				obj:Remove()
				break
			end
		end
	end))
end

function VasGG.AddNPCsByTag(tag)
	local CollectionService = game:GetService("CollectionService")
	VasGG._objects = VasGG._objects or {}
	VasGG._conns = VasGG._conns or {}
	for _, model in ipairs(CollectionService:GetTagged(tag)) do
		VasGG.new(model, "NPC")
	end
	table.insert(VasGG._conns, CollectionService:GetInstanceAddedSignal(tag):Connect(function(model)
		VasGG.new(model, "NPC")
	end))
	table.insert(VasGG._conns, CollectionService:GetInstanceRemovedSignal(tag):Connect(function(model)
		for _, obj in ipairs(VasGG._objects) do
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

function VasGG.Destroy()
	if VasGG._conn then VasGG._conn:Disconnect() end
	for _, c in ipairs(VasGG._conns or {}) do c:Disconnect() end
	VasGG._conns = {}
	for _, obj in ipairs(VasGG._objects or {}) do
		obj:Remove()
	end
	VasGG._objects = {}
	if Drawing.clear then
		pcall(Drawing.clear)
	elseif cleardrawcache then
		pcall(cleardrawcache)
	end
end


local fovCircle = newDrawing("Circle", {Visible = false, Thickness = 1, Color = Color3.fromRGB(255,255,255), Filled = false, NumSides = 48})

local function isHolding()
	if VasGG.Options.AimMode == "Always" then
		return true
	end
	if typeof(VasGG.Options.AimKey) == "EnumItem" then
		if VasGG.Options.AimKey.EnumType == Enum.UserInputType then
			return UserInputService:IsMouseButtonPressed(VasGG.Options.AimKey)
		elseif VasGG.Options.AimKey.EnumType == Enum.KeyCode then
			return UserInputService:IsKeyDown(VasGG.Options.AimKey)
		end
	end
	return false
end

function hasLineOfSight(targetPos, targetModel)
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
		if obj.Type == "Player" and opt.AimTeamCheck and obj.Target.Team == LocalPlayer.Team then
			continue
		end
		local part, model = getAimPart(obj)
		if part then
			local screenPos, vis = cam:WorldToViewportPoint(part.Position)
			if vis and (not opt.WallCheck or hasLineOfSight(part.Position, model)) then
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

	local targetPos = targetPart.Position
	local camCF = cam.CFrame
	local goalCF = CFrame.new(camCF.Position, targetPos)
	cam.CFrame = camCF:Lerp(goalCF, opt.AimSmoothness)
end

function VasGG.InitAimbot()
	VasGG._aimConn = RunService.RenderStepped:Connect(VasGG.AimbotStep)
end

local _baseDestroy = VasGG.Destroy
function VasGG.Destroy()
	if VasGG._aimConn then VasGG._aimConn:Disconnect() end
	fovCircle.Visible = false
	_baseDestroy()
end

return VasGG
