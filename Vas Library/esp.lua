local ESPLib = {}
ESPLib.__index = ESPLib

local Drawing = Drawing
local cam = workspace.CurrentCamera
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

ESPLib.Options = {
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

function ESPLib.new(target, espType)
	local self = setmetatable({}, ESPLib)
	self.Target = target
	self.Type = espType or "Player"
	self.Visible = true

	self.Drawings = {
		Box = newDrawing("Square", {Visible = false, Color = ESPLib.Options.BoxColor, Thickness = ESPLib.Options.BoxThickness, Filled = false}),
		Corners = {},
		Cube = {},
		Tracer = newDrawing("Line", {Visible = false, Color = ESPLib.Options.TracerColor, Thickness = ESPLib.Options.TracerThickness}),
		Name = newDrawing("Text", {Visible = false, Color = ESPLib.Options.NameColor, Size = 14, Center = true, Outline = true}),
		Distance = newDrawing("Text", {Visible = false, Color = ESPLib.Options.NameColor, Size = 13, Center = true, Outline = true}),
		HealthBarBG = newDrawing("Square", {Visible = false, Color = Color3.new(0,0,0), Filled = true}),
		HealthBar = newDrawing("Square", {Visible = false, Color = Color3.fromRGB(0,255,0), Filled = true}),
	}
	for i = 1, 8 do
		self.Drawings.Corners[i] = newDrawing("Line", {Visible = false, Color = ESPLib.Options.BoxColor, Thickness = ESPLib.Options.BoxThickness})
	end
	for i = 1, 12 do
		self.Drawings.Cube[i] = newDrawing("Line", {Visible = false, Color = ESPLib.Options.BoxColor, Thickness = ESPLib.Options.BoxThickness})
	end

	ESPLib._objects = ESPLib._objects or {}
	table.insert(ESPLib._objects, self)
	return self
end

function ESPLib:GetRootAndHealth()
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

function ESPLib:HideAll()
	for k, d in pairs(self.Drawings) do
		if k == "Corners" or k == "Cube" then
			for _, line in ipairs(d) do line.Visible = false end
		else
			d.Visible = false
		end
	end
end

function ESPLib:Update()
	local opt = ESPLib.Options
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

	local part = charOrModel:FindFirstChild("HumanoidRootPart") or root
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
				line.Thickness = opt.BoxThickness
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
				line.Thickness = opt.BoxThickness
				line.Visible = onScreen3D
			end
		else
			for _, l in ipairs(d.Corners) do l.Visible = false end
			for _, l in ipairs(d.Cube) do l.Visible = false end
			d.Box.Position = Vector2.new(x, y)
			d.Box.Size = Vector2.new(w, h)
			d.Box.Color = opt.BoxColor
			d.Box.Thickness = opt.BoxThickness
			d.Box.Visible = true
		end
	else
		d.Box.Visible = false
		for _, l in ipairs(d.Corners) do l.Visible = false end
		for _, l in ipairs(d.Cube) do l.Visible = false end
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
		d.Name.Position = Vector2.new(x + w/2, y - 16)
		d.Name.Color = opt.NameColor
		d.Name.Visible = true
	else
		d.Name.Visible = false
	end

	if opt.Distance then
		d.Distance.Text = string.format("%d studs", dist)
		d.Distance.Position = Vector2.new(x + w/2, y + h + 2)
		d.Distance.Color = opt.NameColor
		d.Distance.Visible = true
	else
		d.Distance.Visible = false
	end

	if opt.HealthBar and maxHealth > 0 then
		local pct = math.clamp(health / maxHealth, 0, 1)
		d.HealthBarBG.Position = Vector2.new(x - opt.HealthBarWidth - 2, y)
		d.HealthBarBG.Size = Vector2.new(opt.HealthBarWidth, h)
		d.HealthBarBG.Visible = true

		d.HealthBar.Position = Vector2.new(x - opt.HealthBarWidth - 2, y + h * (1 - pct))
		d.HealthBar.Size = Vector2.new(opt.HealthBarWidth, h * pct)
		d.HealthBar.Color = Color3.fromHSV(pct * 0.33, 1, 1)
		d.HealthBar.Visible = true
	else
		d.HealthBarBG.Visible = false
		d.HealthBar.Visible = false
	end
end

function ESPLib:Remove()
	for k, d in pairs(self.Drawings) do
		if k == "Corners" or k == "Cube" then
			for _, line in ipairs(d) do line:Remove() end
		else
			d:Remove()
		end
	end
	for i, obj in ipairs(ESPLib._objects) do
		if obj == self then
			table.remove(ESPLib._objects, i)
			break
		end
	end
end

function ESPLib.AddPlayer(player)
	if player == LocalPlayer then return end
	return ESPLib.new(player, "Player")
end

function ESPLib.AddPlayers()
	ESPLib._objects = ESPLib._objects or {}
	for _, plr in ipairs(Players:GetPlayers()) do
		ESPLib.AddPlayer(plr)
	end
	Players.PlayerAdded:Connect(ESPLib.AddPlayer)
	Players.PlayerRemoving:Connect(function(plr)
		for _, obj in ipairs(ESPLib._objects) do
			if obj.Target == plr then
				obj:Remove()
				break
			end
		end
	end)
end

function ESPLib.AddNPCsByTag(tag)
	local CollectionService = game:GetService("CollectionService")
	ESPLib._objects = ESPLib._objects or {}
	for _, model in ipairs(CollectionService:GetTagged(tag)) do
		ESPLib.new(model, "NPC")
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(model)
		ESPLib.new(model, "NPC")
	end)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(model)
		for _, obj in ipairs(ESPLib._objects) do
			if obj.Target == model then
				obj:Remove()
				break
			end
		end
	end)
end

function ESPLib.Init()
	ESPLib._objects = ESPLib._objects or {}
	ESPLib._conn = RunService.RenderStepped:Connect(function()
		cam = workspace.CurrentCamera
		for _, obj in ipairs(ESPLib._objects) do
			obj:Update()
		end
	end)
end

function ESPLib.Destroy()
	if ESPLib._conn then ESPLib._conn:Disconnect() end
	for _, obj in ipairs(ESPLib._objects or {}) do
		obj:Remove()
	end
	ESPLib._objects = {}
end

return ESPLib
