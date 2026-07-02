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
	DistanceScale = true,
	ScaleMin = 0.5,
	ScaleMaxDistance = 500,
	
	-- VISUALS
	Highlight = false,
	HighlightFillColor = Color3.fromRGB(255,0,0),
	HighlightOutlineColor = Color3.fromRGB(255,255,255),
	HighlightFillTransparency = 0.5,
	HighlightOutlineTransparency = 0,
	HighlightDepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
	Skeleton = false,
	SkeletonColor = Color3.fromRGB(255,255,255),
	SkeletonThickness = 1,
	LookVector = false,
	LookVectorColor = Color3.fromRGB(0,255,0),
	LookVectorLength = 5,
	OffScreenIndicators = false,
	OffScreenColor = Color3.fromRGB(255,0,0),
	OffScreenRadius = 150,
	OffScreenSize = 10,
	Crosshair = false,
	CrosshairColor = Color3.fromRGB(0,255,0),
	CrosshairSize = 10,
	CrosshairThickness = 1,
	
	-- NEW RADAR VISUAL
	Radar = false, -- Toggles rendering of the mini standalone map overlay screen
	RadarPosition = Vector2.new(200, 200), -- Origin center location coordinates for layout panel boundary positioning
	RadarRadius = 75, -- Circular radius boundary mapping scale limits
	RadarColor = Color3.fromRGB(0, 0, 0), -- Panel viewport canvas background coloring value
	RadarTransparency = 0.4, -- Alpha transparency level opacity matrix for standard drawing backgrounds
	RadarBlipColor = Color3.fromRGB(255, 0, 0), -- Target plot dot coloring indicator
	RadarScale = 2, -- Relative translation multi-factor translating world space coordinates onto mini grid structures
	
	-- COMBAT
	Aimbot = false,
	AimMode = "Hold", 
	AimKey = Enum.UserInputType.MouseButton2,
	AimFOV = 100,
	FOVPosition = "Mouse", -- Added configuration option: "Mouse" or "Center"
	AimSmoothness = 0.15,
	AimTeamCheck = false,
	ShowFOVCircle = true,
	WallCheck = false,      
	AimWallCheck = false,   
	AimTargetMode = "Mouse", 
	AimDistanceOffsetsToggle = false, 
	AimDistanceOffsets = {  
		{Distance = 100, Offset = 5},
	},
	AimPriority = "Mouse", 
	AimBreakKey = Enum.KeyCode.E, 
	AimBreakTime = 1.5, 
	
	-- NEW COMBAT FEATURES
	AimPrediction = false, -- Scales target calculation models using physics delta vectors to predict velocity shifts
	AimPredictionFactor = 0.165, -- Linear interpolation adjustment variable simulating projection curves over space
	AimPartRate = { -- Rate system for multi-part distribution profiles based on calculated chance properties
		{Part = "Head", Rate = 70}, -- 70% targeting chance weight assigned onto tracking structures
		{Part = "UpperTorso", Rate = 30} -- 30% targeting chance weight assigned onto tracking structures
	},
	Triggerbot = false, 
	TriggerbotDelay = 0,
	TriggerbotHitchance = 100, -- Accuracy threshold percentile checked prior to shooting triggers firing
	TriggerbotHitboxes = {"Head", "UpperTorso", "LowerTorso", "Torso"} -- Whitelisted anatomical target targets allowed to bridge verification steps
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

local SKELETON_PAIRS = {
	{"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
	{"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
	{"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
	{"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
	{"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"}
}

local R6_SKELETON_PAIRS = {
	{"Head", "Torso"}, {"Torso", "Left Arm"}, {"Torso", "Right Arm"},
	{"Torso", "Left Leg"}, {"Torso", "Right Leg"}
}

function VasGG.new(target, espType)
	local self = setmetatable({}, VasGG)
	self.Target = target
	self.Type = espType or "Player"
	self.Visible = true
	self.CurrentChosenAimPart = nil

	self.Drawings = {
		Box = newDrawing("Square", {Visible = false, Color = VasGG.Options.BoxColor, Thickness = VasGG.Options.BoxThickness, Filled = false}),
		Corners = {},
		Cube = {},
		Tracer = newDrawing("Line", {Visible = false, Color = VasGG.Options.TracerColor, Thickness = VasGG.Options.TracerThickness}),
		Name = newDrawing("Text", {Visible = false, Color = VasGG.Options.NameColor, Size = 14, Center = true, Outline = true}),
		Distance = newDrawing("Text", {Visible = false, Color = VasGG.Options.NameColor, Size = 13, Center = true, Outline = true}),
		HealthBarBG = newDrawing("Square", {Visible = false, Color = Color3.new(0,0,0), Filled = true}),
		HealthBar = newDrawing("Square", {Visible = false, Color = Color3.fromRGB(0,255,0), Filled = true}),
		Skeleton = {},
		LookVector = newDrawing("Line", {Visible = false, Color = VasGG.Options.LookVectorColor, Thickness = 1}),
		Indicator = newDrawing("Triangle", {Visible = false, Color = VasGG.Options.OffScreenColor, Filled = true}),
		RadarBlip = newDrawing("Circle", {Visible = false, Radius = 3, Filled = true, NumSides = 16})
	}
	for i = 1, 8 do
		self.Drawings.Corners[i] = newDrawing("Line", {Visible = false, Color = VasGG.Options.BoxColor, Thickness = VasGG.Options.BoxThickness})
	end
	for i = 1, 12 do
		self.Drawings.Cube[i] = newDrawing("Line", {Visible = false, Color = VasGG.Options.BoxColor, Thickness = VasGG.Options.BoxThickness})
	end
	for i = 1, 14 do
		self.Drawings.Skeleton[i] = newDrawing("Line", {Visible = false, Color = VasGG.Options.SkeletonColor, Thickness = VasGG.Options.SkeletonThickness})
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
		if k == "Corners" or k == "Cube" or k == "Skeleton" then
			for _, line in ipairs(d) do line.Visible = false end
		else
			d.Visible = false
		end
	end
	if self.HighlightObj then
		self.HighlightObj.Enabled = false
	end
end

function VasGG:RollAimPart(charOrModel)
	local opt = VasGG.Options
	if not opt.AimPartRate or #opt.AimPartRate == 0 then
		self.CurrentChosenAimPart = charOrModel:FindFirstChild("Head") or charOrModel.PrimaryPart
		return
	end
	
	local totalWeight = 0
	for _, data in ipairs(opt.AimPartRate) do
		totalWeight = totalWeight + data.Rate
	end
	
	local roll = math.random(1, math.max(1, totalWeight))
	local currentCounter = 0
	
	for _, data in ipairs(opt.AimPartRate) do
		currentCounter = currentCounter + data.Rate
		if roll <= currentCounter then
			local match = charOrModel:FindFirstChild(data.Part)
			if match then
				self.CurrentChosenAimPart = match
				return
			end
		end
	end
	
	self.CurrentChosenAimPart = charOrModel:FindFirstChild("Head") or charOrModel.PrimaryPart
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

	-- Radar Rendering Logic
	if opt.Radar then
		local localRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		if localRoot then
			local forwardVec = localRoot.CFrame.LookVector
			local rightVec = localRoot.CFrame.RightVector
			local localPos = localRoot.Position
			local targetPos = root.Position
			
			local worldDelta = targetPos - localPos
			local relX = worldDelta:Dot(rightVec)
			local relZ = worldDelta:Dot(forwardVec)
			
			local radarDelta = Vector2.new(relX, -relZ) * opt.RadarScale
			if radarDelta.Magnitude <= opt.RadarRadius then
				self.Drawings.RadarBlip.Position = opt.RadarPosition + radarDelta
				self.Drawings.RadarBlip.Color = opt.RadarBlipColor
				self.Drawings.RadarBlip.Visible = true
			else
				self.Drawings.RadarBlip.Visible = false
			end
		else
			self.Drawings.RadarBlip.Visible = false
		end
	else
		self.Drawings.RadarBlip.Visible = false
	end

	local scale = 1
	if opt.DistanceScale then
		scale = math.clamp(1 - (dist / opt.ScaleMaxDistance), opt.ScaleMin, 1)
	end

	local part = charOrModel:FindFirstChild("HumanoidRootPart") or root
	local isEspVisible = true
	if opt.WallCheck and not hasLineOfSight(part.Position, charOrModel) then
		isEspVisible = false
	end

	local x, y, w, h, onScreen = getWH(part)
	
	if opt.OffScreenIndicators and not onScreen then
		local screenCenter = cam.ViewportSize / 2
		local objectPos, _ = cam:WorldToViewportPoint(part.Position)
		local direction = (Vector2.new(objectPos.X, objectPos.Y) - screenCenter).Unit
		local pos = screenCenter + (direction * opt.OffScreenRadius)
		
		local p1 = pos
		local p2 = pos - (direction * opt.OffScreenSize) + (Vector2.new(-direction.Y, direction.X) * (opt.OffScreenSize / 2))
		local p3 = pos - (direction * opt.OffScreenSize) - (Vector2.new(-direction.Y, direction.X) * (opt.OffScreenSize / 2))
		
		self.Drawings.Indicator.PointA = p1
		self.Drawings.Indicator.PointB = p2
		self.Drawings.Indicator.PointC = p3
		self.Drawings.Indicator.Color = opt.OffScreenColor
		self.Drawings.Indicator.Visible = true
	else
		self.Drawings.Indicator.Visible = false
	end

	if not onScreen or not isEspVisible then
		for k, d in pairs(self.Drawings) do
			if k ~= "Indicator" and k ~= "RadarBlip" then
				if k == "Corners" or k == "Cube" or k == "Skeleton" then
					for _, l in ipairs(d) do l.Visible = false end
				else
					d.Visible = false
				end
			end
		end
		if self.HighlightObj then self.HighlightObj.Enabled = opt.Highlight end
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

	if opt.Skeleton then
		local hum = charOrModel:FindFirstChildOfClass("Humanoid")
		local pairsToUse = (hum and hum.RigType == Enum.HumanoidRigType.R15) and SKELETON_PAIRS or R6_SKELETON_PAIRS
		for i, pair in ipairs(pairsToUse) do
			local p1 = charOrModel:FindFirstChild(pair[1])
			local p2 = charOrModel:FindFirstChild(pair[2])
			local line = d.Skeleton[i]
			if line then
				if p1 and p2 then
					local sPos1, vis1 = cam:WorldToViewportPoint(p1.Position)
					local sPos2, vis2 = cam:WorldToViewportPoint(p2.Position)
					if vis1 and vis2 then
						line.From = Vector2.new(sPos1.X, sPos1.Y)
						line.To = Vector2.new(sPos2.X, sPos2.Y)
						line.Color = opt.SkeletonColor
						line.Thickness = opt.SkeletonThickness
						line.Visible = true
					else
						line.Visible = false
					end
				else
					line.Visible = false
				end
			end
		end
		for i = #pairsToUse + 1, #d.Skeleton do d.Skeleton[i].Visible = false end
	else
		for _, l in ipairs(d.Skeleton) do l.Visible = false end
	end

	local head = charOrModel:FindFirstChild("Head")
	if opt.LookVector and head then
		local startPos, vis1 = cam:WorldToViewportPoint(head.Position)
		local endPos, vis2 = cam:WorldToViewportPoint(head.Position + (head.CFrame.LookVector * opt.LookVectorLength))
		if vis1 and vis2 then
			d.LookVector.From = Vector2.new(startPos.X, startPos.Y)
			d.LookVector.To = Vector2.new(endPos.X, endPos.Y)
			d.LookVector.Color = opt.LookVectorColor
			d.LookVector.Visible = true
		else
			d.LookVector.Visible = false
		end
	else
		d.LookVector.Visible = false
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
		if k == "Corners" or k == "Cube" or k == "Skeleton" then
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
local crosshairHorizontal = newDrawing("Line", {Visible = false, Thickness = 1, Color = Color3.fromRGB(0,255,0)})
local crosshairVertical = newDrawing("Line", {Visible = false, Thickness = 1, Color = Color3.fromRGB(0,255,0)})
local radarBackground = newDrawing("Circle", {Visible = false, Filled = true, NumSides = 32})
local localPlayerRadarBlip = newDrawing("Circle", {Visible = false, Radius = 3, Filled = true, NumSides = 16, Color = Color3.fromRGB(0, 255, 0)})

local shooting = false
local blacklist = {}
local currentTarget = nil

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

local function checkBreakKey()
	local opt = VasGG.Options
	if currentTarget and opt.AimBreakKey then
		local pressed = false
		if opt.AimBreakKey.EnumType == Enum.KeyCode then
			pressed = UserInputService:IsKeyDown(opt.AimBreakKey)
		elseif opt.AimBreakKey.EnumType == Enum.UserInputType then
			pressed = UserInputService:IsMouseButtonPressed(opt.AimBreakKey)
		end
		
		if pressed and not blacklist[currentTarget] then
			blacklist[currentTarget] = tick() + opt.AimBreakTime
			currentTarget = nil
		end
	end
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
	
	obj:RollAimPart(charOrModel)
	local chosen = obj.CurrentChosenAimPart or charOrModel:FindFirstChild("Head") or root
	return chosen, charOrModel
end

local function getAimOrigin()
	if VasGG.Options.FOVPosition == "Center" then
		return cam.ViewportSize / 2
	else
		return UserInputService:GetMouseLocation()
	end
end

local function getBestTarget()
	local opt = VasGG.Options
	local originLoc = getAimOrigin()
	local best, bestVal, chosenPos = nil, math.huge, nil
	
	if opt.AimPriority == "Mouse" then
		bestVal = opt.AimFOV
	end
	
	for _, obj in ipairs(VasGG._objects or {}) do
		if obj.Type == "Player" and opt.AimTeamCheck and obj.Target.Team == LocalPlayer.Team then
			continue
		end
		
		local part, model = getAimPart(obj)
		if part then
			if blacklist[part] and tick() < blacklist[part] then
				continue
			elseif blacklist[part] then
				blacklist[part] = nil
			end
			
			local currentPos = part.Position
			
			-- Target Prediction Logic
			if opt.AimPrediction and part:IsA("BasePart") then
				currentPos = currentPos + (part.Velocity * opt.AimPredictionFactor)
			end
			
			local dist = (cam.CFrame.Position - currentPos).Magnitude
			local calculatedOffset = 0
			
			if opt.AimDistanceOffsetsToggle then
				local sortedOffsets = {}
				for _, data in ipairs(opt.AimDistanceOffsets or {}) do
					table.insert(sortedOffsets, data)
				end
				table.sort(sortedOffsets, function(a, b) return a.Distance < b.Distance end)
				
				for _, data in ipairs(sortedOffsets) do
					if dist >= data.Distance then
						calculatedOffset = data.Offset
					end
				end
			end
			
			local dynamicTargetPos = currentPos + Vector3.new(0, calculatedOffset, 0)
			local screenPos, vis = cam:WorldToViewportPoint(dynamicTargetPos)
			
			if vis and (not opt.AimWallCheck or hasLineOfSight(dynamicTargetPos, model)) then
				local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - originLoc).Magnitude
				
				if screenDist <= opt.AimFOV then
					if opt.AimPriority == "Mouse" then
						if screenDist < bestVal then
							bestVal = screenDist
							best = part
							chosenPos = dynamicTargetPos
						end
					elseif opt.AimPriority == "Distance" then
						if dist < bestVal then
							bestVal = dist
							best = part
							chosenPos = dynamicTargetPos
						end
					elseif opt.AimPriority == "Health" then
						local _, health = obj:GetRootAndHealth()
						if health < bestVal then
							bestVal = health
							best = part
							chosenPos = dynamicTargetPos
						end
					end
				end
			end
		end
	end
	return best, chosenPos
end

function VasGG.AimbotStep()
	local opt = VasGG.Options
	local originLoc = getAimOrigin()
	local centerScreen = cam.ViewportSize / 2

	-- Radar Framework Setup
	if opt.Radar then
		radarBackground.Position = opt.RadarPosition
		radarBackground.Radius = opt.RadarRadius
		radarBackground.Color = opt.RadarColor
		radarBackground.Transparency = opt.RadarTransparency
		radarBackground.Visible = true

		localPlayerRadarBlip.Position = opt.RadarPosition
		localPlayerRadarBlip.Visible = true
	else
		radarBackground.Visible = false
		localPlayerRadarBlip.Visible = false
	end

	if opt.Crosshair then
		crosshairHorizontal.From = Vector2.new(centerScreen.X - opt.CrosshairSize, centerScreen.Y)
		crosshairHorizontal.To = Vector2.new(centerScreen.X + opt.CrosshairSize, centerScreen.Y)
		crosshairHorizontal.Color = opt.CrosshairColor
		crosshairHorizontal.Thickness = opt.CrosshairThickness
		crosshairHorizontal.Visible = true

		crosshairVertical.From = Vector2.new(centerScreen.X, centerScreen.Y - opt.CrosshairSize)
		crosshairVertical.To = Vector2.new(centerScreen.X, centerScreen.Y + opt.CrosshairSize)
		crosshairVertical.Color = opt.CrosshairColor
		crosshairVertical.Thickness = opt.CrosshairThickness
		crosshairVertical.Visible = true
	else
		crosshairHorizontal.Visible = false
		crosshairVertical.Visible = false
	end

	if opt.ShowFOVCircle and opt.Aimbot then
		fovCircle.Position = originLoc
		fovCircle.Radius = opt.AimFOV
		fovCircle.Color = opt.HighlightOutlineColor
		fovCircle.Visible = true
	else
		fovCircle.Visible = false
	end

	if not opt.Aimbot or not isHolding() then 
		currentTarget = nil
		if shooting then
			shooting = false
			pcall(mouse1release)
		end
		return 
	end

	checkBreakKey()

	local targetPart, targetPos = getBestTarget()
	if not targetPart or not targetPos then 
		currentTarget = nil
		if shooting then
			shooting = false
			pcall(mouse1release)
		end
		return 
	end

	currentTarget = targetPart
	local camCF = cam.CFrame
	local goalCF = CFrame.new(camCF.Position, targetPos)
	
	if opt.AimSmoothness <= 0 then
		cam.CFrame = goalCF
	else
		cam.CFrame = camCF:Lerp(goalCF, opt.AimSmoothness)
	end

	-- Triggerbot with Hitbox Filters and Hitchance Pass
	if opt.Triggerbot then
		local rayOrigin = cam.CFrame.Position
		local rayDirection = cam.CFrame.LookVector * opt.MaxDistance
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = {LocalPlayer.Character}
		
		local result = workspace:Raycast(rayOrigin, rayDirection, rayParams)
		local hitVerified = false
		
		if result and result.Instance then
			local hitPartName = result.Instance.Name
			local validHitbox = false
			
			if not opt.TriggerbotHitboxes or #opt.TriggerbotHitboxes == 0 then
				validHitbox = true
			else
				for _, name in ipairs(opt.TriggerbotHitboxes) do
					if hitPartName == name then
						validHitbox = true
						break
					end
				end
			end
			
			if validHitbox then
				for _, obj in ipairs(VasGG._objects or {}) do
					local _, _, _, model = obj:GetRootAndHealth()
					if model and result.Instance:IsDescendantOf(model) then
						if not (obj.Type == "Player" and opt.AimTeamCheck and obj.Target.Team == LocalPlayer.Team) then
							local chanceRoll = math.random(1, 100)
							if chanceRoll <= opt.TriggerbotHitchance then
								hitVerified = true
							end
							break
						end
					end
				end
			end
		end
		
		if hitVerified then
			if not shooting then
				shooting = true
				task.spawn(function()
					if opt.TriggerbotDelay > 0 then task.wait(opt.TriggerbotDelay) end
					if shooting then pcall(mouse1press) end
				end)
			end
		else
			if shooting then
				shooting = false
				pcall(mouse1release)
			end
		end
	else
		if shooting then
			shooting = false
			pcall(mouse1release)
		end
	end
end

function VasGG.InitAimbot()
	VasGG._aimConn = RunService.RenderStepped:Connect(VasGG.AimbotStep)
end

local _baseDestroy = VasGG.Destroy
function VasGG.Destroy()
	if VasGG._aimConn then VasGG._aimConn:Disconnect() end
	if shooting then
		shooting = false
		pcall(mouse1release)
	end
	fovCircle.Visible = false
	crosshairHorizontal.Visible = false
	crosshairVertical.Visible = false
	radarBackground.Visible = false
	localPlayerRadarBlip.Visible = false
	_baseDestroy()
end

return VasGG
