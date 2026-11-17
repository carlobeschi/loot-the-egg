--[[ WeaponModels  (ModuleScript, inside the Config ModuleScript in ReplicatedStorage)
  Builds the look of every weapon out of Parts: swords for the Knight, staffs for the Wizard, bows for the Bowman.
  Used by the server for the Tool in your hand (CombatService) and by the client for the spinning picture in
  the Blacksmith (ClientShops), so both always match.

  WeaponModels.Build(className, tier) returns a Model whose PrimaryPart is "Handle", with the handle at the
  origin. The weapon points along -Z (sword blade, bow front) or +Y (staff), like the Tool grip expects.
  Higher tiers get more gold, gems, glow and sparkles.
]]
local WeaponModels = {}

local Config = require(script.Parent)

local GOLD = Color3.fromRGB(230, 190, 80)
local DARK_GOLD = Color3.fromRGB(170, 130, 50)
local LEATHER = Color3.fromRGB(95, 58, 34)
local WOOD = Color3.fromRGB(120, 80, 46)
local DARK_WOOD = Color3.fromRGB(80, 52, 30)
local IRON = Color3.fromRGB(70, 70, 76)

local function part(model, name, size, cframe, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

local function wedge(model, name, size, cframe, color, material)
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Parent = model
	return p
end

-- a cylinder along the given local axis ("x", "y" or "z")
local function rod(model, name, length, diameter, cframe, color, material, axis)
	local turn = CFrame.new()
	if axis == "y" then
		turn = CFrame.Angles(0, 0, math.pi / 2)
	elseif axis == "z" then
		turn = CFrame.Angles(0, math.pi / 2, 0)
	end
	return part(model, name, Vector3.new(length, diameter, diameter), cframe * turn, color, material, Enum.PartType.Cylinder)
end

local function ball(model, name, diameter, cframe, color, material)
	return part(model, name, Vector3.one * diameter, cframe, color, material, Enum.PartType.Ball)
end

local function sparkles(p, color, rate)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Sparkles"
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new(0.1, 1)
	e.Lifetime = NumberRange.new(0.4, 0.8)
	e.Rate = rate or 8
	e.Speed = NumberRange.new(0.5, 1.5)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Parent = p
end

local function glow(p, color, range)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range or 8
	light.Brightness = 1.5
	light.Parent = p
end

-- ---------- Knight: swords ----------
local function sword(model, color, tier)
	local metal = tier >= 6 and Enum.Material.Neon or (tier >= 3 and Enum.Material.Foil or Enum.Material.Metal)
	local trim = tier >= 3 and GOLD or IRON
	local length = 3.4 + tier * 0.08
	local width = 0.55 + tier * 0.02
	local origin = CFrame.new()
	-- grip, wrapped in leather, with a pommel
	-- the Handle must stay an unturned block: the Tool grip is worked out from its sides
	local handle = part(model, "Handle", Vector3.new(0.3, 0.3, 1.2), origin, LEATHER, Enum.Material.Fabric)
	rod(model, "Grip", 1.2, 0.34, origin, LEATHER, Enum.Material.Fabric, "z")
	for i = -1, 1 do
		rod(model, "Wrap", 0.12, 0.36, origin * CFrame.new(0, 0, i * 0.4), DARK_WOOD, Enum.Material.Fabric, "z")
	end
	ball(model, "Pommel", 0.5, origin * CFrame.new(0, 0, 0.75), trim, Enum.Material.Metal)
	if tier >= 2 then
		ball(model, "PommelGem", 0.28, origin * CFrame.new(0, 0, 0.98), color, Enum.Material.Neon)
	end
	-- cross guard with turned-up ends and a gem in the middle
	part(model, "Guard", Vector3.new(1.7, 0.3, 0.3), origin * CFrame.new(0, 0, -0.7), trim, Enum.Material.Metal)
	for _, side in ipairs({ -1, 1 }) do
		part(model, "GuardTip", Vector3.new(0.3, 0.3, 0.45), origin * CFrame.new(side * 0.85, 0, -0.85) * CFrame.Angles(0, side * 0.5, 0), trim, Enum.Material.Metal)
	end
	if tier >= 1 then
		ball(model, "GuardGem", 0.3, origin * CFrame.new(0, 0.12, -0.7), color, Enum.Material.Neon)
	end
	-- blade: a flat bar with a darker groove (fuller) and a pointed tip made of two wedges
	local bladeCF = origin * CFrame.new(0, 0, -0.85 - length / 2)
	part(model, "Blade", Vector3.new(width, 0.14, length), bladeCF, color, metal)
	part(model, "Fuller", Vector3.new(width * 0.25, 0.16, length * 0.8), bladeCF * CFrame.new(0, 0, length * 0.05), color:Lerp(Color3.new(0, 0, 0), 0.25), Enum.Material.Metal)
	local tipLen = width * 1.4
	local tipCF = origin * CFrame.new(0, 0, -0.85 - length - tipLen / 2)
	for _, side in ipairs({ -1, 1 }) do
		-- each wedge is half of the point; the slope faces outwards
		wedge(model, "Tip", Vector3.new(0.14, width / 2, tipLen), tipCF * CFrame.new(side * width / 4, 0, 0) * CFrame.Angles(0, 0, -side * math.pi / 2), color, metal)
	end
	if tier >= 6 then
		local edge = part(model, "Edge", Vector3.new(width + 0.1, 0.06, length), bladeCF, color:Lerp(Color3.new(1, 1, 1), 0.4), Enum.Material.Neon)
		edge.Transparency = 0.5
		sparkles(edge, color, 6 + tier)
		glow(edge, color, 6)
	end
	return handle
end

-- ---------- Wizard: staffs ----------
local function staff(model, color, tier)
	local origin = CFrame.new()
	local shaftColor = tier >= 5 and Color3.fromRGB(60, 40, 70) or WOOD
	local trim = tier >= 3 and GOLD or Color3.fromRGB(150, 150, 160)
	local handle = part(model, "Handle", Vector3.new(0.28, 5, 0.28), origin, shaftColor, Enum.Material.Wood)
	rod(model, "Shaft", 5, 0.32, origin, shaftColor, Enum.Material.Wood, "y")
	-- rings along the shaft and a metal foot
	for _, y in ipairs({ -1.5, 0.4, 1.6 }) do
		rod(model, "Ring", 0.15, 0.38, origin * CFrame.new(0, y, 0), trim, Enum.Material.Metal, "y")
	end
	rod(model, "Foot", 0.35, 0.36, origin * CFrame.new(0, -2.55, 0), trim, Enum.Material.Metal, "y")
	-- the head: a cup and three curved prongs holding the orb
	local top = origin * CFrame.new(0, 2.5, 0)
	rod(model, "Cup", 0.35, 0.6, top * CFrame.new(0, 0.1, 0), trim, Enum.Material.Metal, "y")
	local orbSize = 0.9 + tier * 0.04
	for i = 0, 2 do
		local a = i / 3 * math.pi * 2
		part(model, "Prong", Vector3.new(0.14, 1.1, 0.14), top * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.7, 0.32) * CFrame.Angles(0.35, 0, 0), trim, Enum.Material.Metal)
		ball(model, "ProngTip", 0.2, top * CFrame.Angles(0, a, 0) * CFrame.new(0, 1.22, 0.18), trim, Enum.Material.Metal)
	end
	local orb = ball(model, "Orb", orbSize, top * CFrame.new(0, 0.85, 0), color, Enum.Material.Neon)
	local shell = ball(model, "OrbShell", orbSize + 0.2, top * CFrame.new(0, 0.85, 0), color:Lerp(Color3.new(1, 1, 1), 0.5), Enum.Material.Glass)
	shell.Transparency = 0.6
	glow(orb, color, 8 + tier * 0.5)
	if tier >= 4 then -- a floating ring around the orb
		local ring = rod(model, "Halo", 0.08, orbSize + 0.9, top * CFrame.new(0, 0.85, 0) * CFrame.Angles(0.5, 0, 0.3), color, Enum.Material.Neon, "y")
		ring.Transparency = 0.3
	end
	if tier >= 2 then
		sparkles(orb, color, 4 + tier)
	end
	if tier >= 7 then -- little gems on the shaft
		for _, y in ipairs({ -0.5, 1 }) do
			ball(model, "ShaftGem", 0.25, origin * CFrame.new(0, y, 0.15), color, Enum.Material.Neon)
		end
	end
	return handle
end

-- ---------- Bowman: bows ----------
local function bow(model, color, tier)
	local origin = CFrame.new()
	local limbColor = tier >= 4 and color or color:Lerp(WOOD, 0.4)
	local limbMaterial = tier >= 6 and Enum.Material.Neon or (tier >= 4 and Enum.Material.SmoothPlastic or Enum.Material.Wood)
	local trim = tier >= 3 and GOLD or DARK_GOLD
	-- grip
	local handle = part(model, "Handle", Vector3.new(0.3, 1, 0.34), origin, LEATHER, Enum.Material.Fabric)
	rod(model, "GripWrap", 0.2, 0.4, origin * CFrame.new(0, 0.35, 0), trim, Enum.Material.Metal, "y")
	rod(model, "GripWrap", 0.2, 0.4, origin * CFrame.new(0, -0.35, 0), trim, Enum.Material.Metal, "y")
	-- each limb is three segments that bend back toward the string (+Z), so it looks curved
	local tips = {}
	for _, side in ipairs({ -1, 1 }) do
		local at = origin * CFrame.new(0, side * 0.5, 0)
		local segLen = 0.85 + tier * 0.02
		for s = 1, 3 do
			local bend = side * (0.12 + 0.15 * s) -- tilts the segment toward +Z (the string side)
			local seg = at * CFrame.Angles(bend, 0, 0) * CFrame.new(0, side * segLen / 2, 0)
			part(model, "Limb", Vector3.new(0.22, segLen + 0.05, 0.28 - s * 0.04), seg, limbColor, limbMaterial)
			at = at * CFrame.Angles(bend, 0, 0) * CFrame.new(0, side * segLen, 0) * CFrame.Angles(-bend, 0, 0)
		end
		ball(model, "LimbTip", 0.28, at, trim, Enum.Material.Metal)
		tips[side] = at.Position
	end
	-- the string from tip to tip
	local a, b = tips[-1], tips[1]
	part(model, "String", Vector3.new(0.05, (b - a).Magnitude, 0.05), CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(math.pi / 2, 0, 0), Color3.fromRGB(240, 235, 220), Enum.Material.SmoothPlastic)
	-- an arrow resting on the grip, pointing forward
	local stringZ = (a + b).Z / 2
	local arrowLen = stringZ + 1.6
	rod(model, "Arrow", arrowLen, 0.1, origin * CFrame.new(0.2, 0, stringZ - arrowLen / 2), WOOD, Enum.Material.Wood, "z")
	part(model, "ArrowHead", Vector3.new(0.3, 0.06, 0.3), origin * CFrame.new(0.2, 0, stringZ - arrowLen - 0.05) * CFrame.Angles(0, math.pi / 4, 0), tier >= 5 and color or IRON, Enum.Material.Metal)
	for _, side in ipairs({ -1, 1 }) do
		part(model, "Feather", Vector3.new(0.04, 0.22, 0.45), origin * CFrame.new(0.2, side * 0.1, stringZ - 0.3), color:Lerp(Color3.new(1, 1, 1), 0.3), Enum.Material.SmoothPlastic)
	end
	if tier >= 6 then
		sparkles(handle, color, 4 + tier)
		glow(handle, color, 7)
	end
	return handle
end

function WeaponModels.Build(className, tier)
	local info = Config.weaponInfo(className, tier)
	local color = Color3.fromHex(info.color)
	local model = Instance.new("Model")
	model.Name = info.name
	local handle
	if className == "Knight" then
		handle = sword(model, color, tier)
	elseif className == "Wizard" then
		handle = staff(model, color, tier)
	else
		handle = bow(model, color, tier)
	end
	handle.Name = "Handle"
	model.PrimaryPart = handle
	return model
end

return WeaponModels
