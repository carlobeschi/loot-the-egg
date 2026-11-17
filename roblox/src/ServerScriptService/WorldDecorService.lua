--[[ WorldDecorService  (ModuleScript, put it in ServerScriptService)
  Dresses up World 1 when the server starts: grass ground, a cobblestone town square with a fountain,
  benches and lamps, dirt paths from the town to the pens and to every dungeon door, signposts, a pond,
  flower beds, bushes, rocks, a forest around the edges and hills far away.
  Everything is only for looks. Apart from tree trunks, rocks, the fountain and the hills, nothing
  bumps into you, and nothing is placed on the paths, in the pens, in the town or next to a dungeon.
  It is built the same way every time (fixed random seed).

  Map (World 1, +Z is north):  pens around z = 100..235, town at the middle (0, 0),
  dungeons in two rows south of the town (TowerService.WORLD1_SPOTS).
]]
local Lighting = game:GetService("Lighting")

local WorldDecorService = {}

local GRASS = Color3.fromRGB(98, 160, 74)
local DIRT = Color3.fromRGB(176, 140, 96)
local STONE = Color3.fromRGB(150, 146, 140)
local DARK_STONE = Color3.fromRGB(110, 108, 104)
local WOOD = Color3.fromRGB(116, 80, 48)
local IRON = Color3.fromRGB(45, 42, 44)
local GOLD_COLOR = Color3.fromRGB(230, 190, 80)

local folder
local pathCount = 0 -- each path sits a hair higher than the last, so crossing paths don't flicker
local keepOut = {} -- { kind = "box" | "circle", ... }: where scenery must not go

-- a part that is only for looks
local function deco(name, size, cframe, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cframe
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = folder
	return p
end

-- a solid one (you bump into it)
local function solid(name, size, cframe, color, material, shape)
	local p = deco(name, size, cframe, color, material, shape)
	p.CanCollide = true
	return p
end

-- a cylinder standing up (Roblox cylinders lie along X, so turn it)
local function column(name, height, diameter, position, color, material, isSolid)
	local make = isSolid and solid or deco
	return make(name, Vector3.new(height, diameter, diameter), CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2), color, material, Enum.PartType.Cylinder)
end

local function blockBox(x1, z1, x2, z2)
	table.insert(keepOut, { kind = "box", x1 = math.min(x1, x2), z1 = math.min(z1, z2), x2 = math.max(x1, x2), z2 = math.max(z1, z2) })
end
local function blockCircle(x, z, r)
	table.insert(keepOut, { kind = "circle", x = x, z = z, r = r })
end
local function isFree(x, z, margin)
	margin = margin or 0
	for _, k in ipairs(keepOut) do
		if k.kind == "box" then
			if x > k.x1 - margin and x < k.x2 + margin and z > k.z1 - margin and z < k.z2 + margin then
				return false
			end
		elseif (Vector2.new(x - k.x, z - k.z)).Magnitude < k.r + margin then
			return false
		end
	end
	return true
end

-- a flat strip of path from (x1, z1) to (x2, z2); it also keeps scenery off the path
local function path(x1, z1, x2, z2, width)
	width = width or 8
	pathCount += 1
	local y = 0.1 + (pathCount % 10) * 0.02
	local a, b = Vector3.new(x1, y, z1), Vector3.new(x2, y, z2)
	local length = (b - a).Magnitude
	deco("Path", Vector3.new(width, 0.2, length + width), CFrame.lookAt((a + b) / 2, b), DIRT, Enum.Material.Ground)
	-- keep-out: sample along the path
	local steps = math.max(1, math.floor(length / 6))
	for i = 0, steps do
		local p = a:Lerp(b, i / steps)
		blockCircle(p.X, p.Z, width / 2 + 3)
	end
end

local function signpost(position, facing, lines)
	local base = CFrame.lookAt(position, position + facing)
	solid("SignPost", Vector3.new(0.8, 7, 0.8), base * CFrame.new(0, 3.5, 0), WOOD, Enum.Material.Wood)
	for i, text in ipairs(lines) do
		local board = deco("SignBoard", Vector3.new(7, 1.6, 0.3), base * CFrame.new(0, 6.4 - (i - 1) * 2, -0.5), Color3.fromRGB(150, 110, 70), Enum.Material.WoodPlanks)
		for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
			local gui = Instance.new("SurfaceGui")
			gui.Face = face
			gui.PixelsPerStud = 40
			gui.Parent = board
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.TextColor3 = Color3.fromRGB(40, 25, 15)
			label.TextScaled = true
			label.Font = Enum.Font.FredokaOne
			label.Text = text
			label.Parent = gui
		end
	end
end

local function lamp(position)
	column("LampFoot", 0.6, 1.4, position + Vector3.new(0, 0.3, 0), IRON, Enum.Material.Metal, true)
	column("LampPost", 9, 0.5, position + Vector3.new(0, 4.5, 0), IRON, Enum.Material.Metal, true)
	deco("LampCap", Vector3.new(1.6, 0.4, 1.6), CFrame.new(position + Vector3.new(0, 10.6, 0)), IRON, Enum.Material.Metal)
	local glass = deco("Lamp", Vector3.new(1.1, 1.3, 1.1), CFrame.new(position + Vector3.new(0, 9.75, 0)), Color3.fromRGB(255, 220, 140), Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 210, 140)
	light.Range = 18
	light.Brightness = 1.2
	light.Parent = glass
end

local function bench(position, angle)
	local base = CFrame.new(position) * CFrame.Angles(0, angle, 0)
	solid("BenchSeat", Vector3.new(6, 0.4, 1.8), base * CFrame.new(0, 1.6, 0), WOOD, Enum.Material.WoodPlanks)
	deco("BenchBack", Vector3.new(6, 1.4, 0.3), base * CFrame.new(0, 2.6, 0.85), WOOD, Enum.Material.WoodPlanks)
	for _, x in ipairs({ -2.5, 2.5 }) do
		deco("BenchLeg", Vector3.new(0.4, 1.4, 1.6), base * CFrame.new(x, 0.7, 0), IRON, Enum.Material.Metal)
	end
end

local LEAF_COLORS = {
	Color3.fromRGB(60, 130, 55), Color3.fromRGB(74, 148, 62), Color3.fromRGB(50, 112, 60), Color3.fromRGB(96, 156, 64),
}

local function roundTree(rng, x, z, scale)
	local trunkH = 7 * scale
	column("Trunk", trunkH, 1.6 * scale, Vector3.new(x, trunkH / 2, z), WOOD, Enum.Material.Wood, true)
	local color = LEAF_COLORS[rng:NextInteger(1, #LEAF_COLORS)]
	local top = Vector3.new(x, trunkH + 2.5 * scale, z)
	deco("Leaves", Vector3.one * 9 * scale, CFrame.new(top), color, Enum.Material.Grass, Enum.PartType.Ball)
	for _ = 1, 2 do
		local offset = Vector3.new(rng:NextNumber(-2.5, 2.5), rng:NextNumber(-1, 2), rng:NextNumber(-2.5, 2.5)) * scale
		deco("Leaves", Vector3.one * rng:NextNumber(5, 7) * scale, CFrame.new(top + offset), color:Lerp(Color3.new(1, 1, 0.6), 0.08), Enum.Material.Grass, Enum.PartType.Ball)
	end
end

local function pineTree(rng, x, z, scale)
	local trunkH = 4 * scale
	column("Trunk", trunkH, 1.3 * scale, Vector3.new(x, trunkH / 2, z), Color3.fromRGB(96, 64, 40), Enum.Material.Wood, true)
	local color = Color3.fromRGB(40, 96, 58):Lerp(Color3.fromRGB(60, 120, 70), rng:NextNumber())
	local turn = CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
	for i = 0, 3 do -- stacked "cones": square layers that get smaller going up, turned 45 degrees each
		local w = (8 - i * 1.7) * scale
		deco("Needles", Vector3.new(w, 2.6 * scale, w), CFrame.new(x, trunkH + (i * 2.2 + 1) * scale, z) * turn * CFrame.Angles(0, i * math.pi / 4, 0), color, Enum.Material.Grass)
	end
end

local function bush(rng, x, z)
	local color = LEAF_COLORS[rng:NextInteger(1, #LEAF_COLORS)]
	local s = rng:NextNumber(3, 5)
	deco("Bush", Vector3.one * s, CFrame.new(x, s * 0.2, z), color, Enum.Material.Grass, Enum.PartType.Ball)
	if rng:NextNumber() < 0.4 then -- some bushes have berries
		for _ = 1, 3 do
			deco("Berry", Vector3.one * 0.5, CFrame.new(x + rng:NextNumber(-s / 2, s / 2), s * 0.55, z + rng:NextNumber(-s / 2, s / 2)), Color3.fromRGB(220, 50, 60), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		end
	end
end

local FLOWER_COLORS = {
	Color3.fromRGB(255, 90, 110), Color3.fromRGB(255, 210, 70), Color3.fromRGB(170, 120, 255), Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 150, 60),
}

local function flowerPatch(rng, x, z)
	local color = FLOWER_COLORS[rng:NextInteger(1, #FLOWER_COLORS)]
	for _ = 1, rng:NextInteger(4, 7) do
		local fx, fz = x + rng:NextNumber(-2.5, 2.5), z + rng:NextNumber(-2.5, 2.5)
		deco("Stem", Vector3.new(0.15, 1, 0.15), CFrame.new(fx, 0.5, fz), Color3.fromRGB(70, 140, 50), Enum.Material.Grass)
		deco("Flower", Vector3.one * 0.6, CFrame.new(fx, 1.05, fz), color, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	end
end

local function rock(rng, x, z, size)
	local s = size or rng:NextNumber(2, 5)
	solid("Rock", Vector3.new(s * 1.3, s, s), CFrame.new(x, s * 0.3, z) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3)), DARK_STONE:Lerp(STONE, rng:NextNumber()), Enum.Material.Slate)
end

-- the town square: cobblestones, a fountain in the middle, benches, lamps and flower beds
local function buildTown()
	column("Square", 0.3, 96, Vector3.new(0, 0.16, 0), STONE, Enum.Material.Cobblestone)
	column("SquareEdge", 0.26, 100, Vector3.new(0, 0.14, 0), DARK_STONE, Enum.Material.Slate)
	-- fountain
	column("FountainRim", 2, 13, Vector3.new(0, 1, 2), DARK_STONE, Enum.Material.Slate, true)
	local water = column("FountainWater", 0.3, 11.4, Vector3.new(0, 1.9, 2), Color3.fromRGB(90, 170, 230), Enum.Material.Glass)
	water.Transparency = 0.25
	column("FountainPillar", 5, 1.6, Vector3.new(0, 3.5, 2), STONE, Enum.Material.Slate, true)
	column("FountainBowl", 0.8, 5, Vector3.new(0, 5.6, 2), STONE, Enum.Material.Slate)
	local spout = deco("FountainSpout", Vector3.new(1.2, 2, 1.2), CFrame.new(0, 6.8, 2), Color3.fromRGB(150, 210, 255), Enum.Material.Neon)
	spout.Transparency = 0.4
	local splash = Instance.new("ParticleEmitter")
	splash.Color = ColorSequence.new(Color3.fromRGB(200, 235, 255))
	splash.Size = NumberSequence.new(0.35, 0.1)
	splash.Transparency = NumberSequence.new(0.2, 1)
	splash.Lifetime = NumberRange.new(0.8, 1.2)
	splash.Rate = 30
	splash.Speed = NumberRange.new(6, 9)
	splash.SpreadAngle = Vector2.new(25, 25)
	splash.Acceleration = Vector3.new(0, -25, 0)
	splash.Parent = spout

	-- a new Baseplate place has a SpawnLocation right where the fountain is: move it onto the open square
	for _, child in ipairs(workspace:GetChildren()) do
		if child:IsA("SpawnLocation") and Vector2.new(child.Position.X, child.Position.Z - 2).Magnitude < 14 then
			child.CFrame = CFrame.new(0, child.Position.Y, -30)
		end
	end

	bench(Vector3.new(-12, 0, 2), math.pi / 2)
	bench(Vector3.new(12, 0, 2), -math.pi / 2)
	for _, p in ipairs({ Vector3.new(-16, 0, -22), Vector3.new(16, 0, -22), Vector3.new(-16, 0, 22), Vector3.new(16, 0, 22), Vector3.new(-42, 0, 14), Vector3.new(42, 0, 14) }) do
		lamp(p)
	end
	-- flower beds around the edge of the square, leaving gaps for the paths
	local rng = Random.new(11)
	for i = 0, 23 do
		local a = i / 24 * math.pi * 2
		local x, z = math.sin(a) * 45, math.cos(a) * 45
		if math.abs(x) > 9 and math.abs(z) > 9 then -- not where the north and south paths come in
			deco("FlowerBed", Vector3.new(5, 0.6, 2.4), CFrame.new(x, 0.3, z) * CFrame.Angles(0, a, 0), Color3.fromRGB(110, 80, 55), Enum.Material.Ground)
			flowerPatch(rng, x, z)
		end
	end
	blockCircle(0, 0, 54)
end

local function buildPond(x, z)
	column("PondEdge", 0.3, 34, Vector3.new(x, 0.15, z), Color3.fromRGB(200, 185, 140), Enum.Material.Sand)
	local water = column("Pond", 0.35, 30, Vector3.new(x, 0.2, z), Color3.fromRGB(70, 150, 210), Enum.Material.Glass)
	water.Transparency = 0.2
	local rng = Random.new(5)
	for i = 1, 4 do -- lily pads
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(3, 11)
		column("LilyPad", 0.1, 2.4, Vector3.new(x + math.sin(a) * r, 0.42, z + math.cos(a) * r), Color3.fromRGB(70, 150, 70), Enum.Material.Grass)
		if i % 2 == 0 then
			deco("Lily", Vector3.one * 0.7, CFrame.new(x + math.sin(a) * r, 0.7, z + math.cos(a) * r), Color3.fromRGB(255, 170, 200), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		end
	end
	for i = 0, 9 do -- stones around it
		local a = i / 10 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		rock(rng, x + math.sin(a) * 18, z + math.cos(a) * 18, rng:NextNumber(1.5, 3))
	end
	blockCircle(x, z, 22)
end

-- hills far away around the whole map, so the world doesn't just stop
local function buildHills()
	local rng = Random.new(21)
	for i = 0, 39 do
		local a = i / 40 * math.pi * 2
		local r = rng:NextNumber(470, 520)
		local s = rng:NextNumber(110, 170)
		local x, z = math.sin(a) * r, math.cos(a) * r + 20
		local color = Color3.fromRGB(78, 132, 64):Lerp(Color3.fromRGB(110, 150, 80), rng:NextNumber())
		solid("Hill", Vector3.one * s, CFrame.new(x, -s * 0.3, z), color, Enum.Material.Grass, Enum.PartType.Ball) -- a ball, mostly underground
	end
end

-- ground colour: turn the default grey Baseplate into grass
local function grassGround()
	local plate = workspace:FindFirstChild("Baseplate")
	if plate and plate:IsA("BasePart") then
		plate.Color = GRASS
		plate.Material = Enum.Material.Grass
		for _, child in ipairs(plate:GetChildren()) do
			if child:IsA("Texture") or child:IsA("Decal") then
				child.Transparency = 1 -- the grid texture of a new Baseplate place
			end
		end
	end
end

-- a bit of warmth and colour in the sky (World 2 changes the fog on the client, see ClientWorld)
local function lighting()
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.2
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 150)
	if not Lighting:FindFirstChild("DecorColor") then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "DecorColor"
		cc.Saturation = 0.12
		cc.Contrast = 0.05
		cc.Parent = Lighting
	end
	if not Lighting:FindFirstChild("DecorBloom") then
		local bloom = Instance.new("BloomEffect")
		bloom.Name = "DecorBloom"
		bloom.Intensity = 0.4
		bloom.Size = 20
		bloom.Threshold = 1.6
		bloom.Parent = Lighting
	end
end

-- ---------- more things to look at (2026-11-17: "make the map look even better") ----------

local function barrel(x, z, angle)
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, angle or 0, 0)
	column("Barrel", 3, 2.4, (base * CFrame.new(0, 1.5, 0)).Position, WOOD, Enum.Material.WoodPlanks, true)
	for _, y in ipairs({ 0.5, 2.5 }) do
		column("Hoop", 0.25, 2.5, (base * CFrame.new(0, y, 0)).Position, IRON, Enum.Material.Metal)
	end
end

local function crate(x, z, size, angle)
	solid("Crate", Vector3.one * size, CFrame.new(x, size / 2, z) * CFrame.Angles(0, angle or 0, 0), Color3.fromRGB(150, 110, 65), Enum.Material.WoodPlanks)
end

-- a market stall with a striped awning, facing -Z (toward the fountain when it stands north of it)
local function stall(x, z, color, goods)
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, math.pi, 0)
	solid("StallCounter", Vector3.new(9, 3, 3), base * CFrame.new(0, 1.5, 0), Color3.fromRGB(140, 95, 55), Enum.Material.WoodPlanks)
	for _, sx in ipairs({ -4.3, 4.3 }) do
		for _, sz in ipairs({ -1.3, 3 }) do
			deco("StallPost", Vector3.new(0.5, 8, 0.5), base * CFrame.new(sx, 4, sz), WOOD, Enum.Material.Wood)
		end
	end
	for i = 0, 5 do -- the awning: stripes, sloping down toward the front
		local stripe = (i % 2 == 0) and color or Color3.fromRGB(250, 245, 235)
		deco("Awning", Vector3.new(1.6, 0.25, 5.4), base * CFrame.new(-4 + i * 1.6, 8, 0.85) * CFrame.Angles(-0.25, 0, 0), stripe, Enum.Material.Fabric)
	end
	local rng = Random.new(math.floor(x * 7 + z))
	for i = 0, 5 do -- goods on the counter
		local gx = -3.5 + i * 1.4
		deco("Goods", Vector3.one * rng:NextNumber(0.7, 1.1), base * CFrame.new(gx, 3.45, 0), goods[i % #goods + 1], Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	end
end

-- little coloured flags on a string between two points
local function bunting(a, b)
	local colors = { Color3.fromRGB(255, 90, 90), Color3.fromRGB(255, 210, 70), Color3.fromRGB(90, 170, 255), Color3.fromRGB(120, 210, 110) }
	local n = math.floor((b - a).Magnitude / 2.2)
	for i = 0, n do
		local t = i / n
		local p = a:Lerp(b, t) - Vector3.new(0, math.sin(t * math.pi) * 2.2, 0) -- it sags in the middle
		local look = CFrame.lookAt(p, p + (b - a))
		deco("Flag", Vector3.new(0.05, 1, 1), look * CFrame.Angles(0, math.pi / 2, 0) * CFrame.new(0, -0.5, 0) * CFrame.Angles(math.pi / 4, 0, 0), colors[i % #colors + 1], Enum.Material.Fabric)
	end
	local mid = (a + b) / 2 - Vector3.new(0, 1.1, 0)
	deco("FlagString", Vector3.new(0.08, 0.08, (b - a).Magnitude), CFrame.lookAt(mid, mid + (b - a)), Color3.fromRGB(240, 240, 240), Enum.Material.SmoothPlastic)
end

local function townExtras()
	stall(-28, 24, Color3.fromRGB(230, 70, 70), { Color3.fromRGB(230, 50, 50), Color3.fromRGB(255, 200, 40), Color3.fromRGB(120, 200, 60) })
	stall(28, 24, Color3.fromRGB(70, 130, 230), { Color3.fromRGB(255, 140, 40), Color3.fromRGB(160, 90, 220), Color3.fromRGB(250, 240, 200) })
	-- barrels and crates behind the Blacksmith and the Trainer (their backs face the fountain)
	barrel(-34, -1.5, 0.3)
	barrel(-30.5, -1.5, 1)
	crate(-26.5, -1.8, 2.6, 0.2)
	crate(34, -1.8, 2.6, -0.3)
	barrel(30.5, -1.5, 0.6)
	crate(27, -1.6, 1.8, 0.5)
	-- bunting between the lamp posts across the square
	bunting(Vector3.new(-16, 10, -22), Vector3.new(16, 10, -22))
	bunting(Vector3.new(-16, 10, 22), Vector3.new(16, 10, 22))
	bunting(Vector3.new(-16, 10, -22), Vector3.new(-16, 10, 22))
	bunting(Vector3.new(16, 10, -22), Vector3.new(16, 10, 22))
end

-- a little cottage with a roof, door, glowing windows and a chimney; it faces `angle`
local function cottage(x, z, angle, wallColor, roofColor)
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, angle, 0)
	solid("CottageWalls", Vector3.new(16, 9, 12), base * CFrame.new(0, 4.5, 0), wallColor, Enum.Material.Plaster)
	for _, sx in ipairs({ -8, 8 }) do
		for _, sz in ipairs({ -6, 6 }) do
			deco("Beam", Vector3.new(0.8, 9, 0.8), base * CFrame.new(sx, 4.5, sz), DARK_STONE:Lerp(WOOD, 0.8), Enum.Material.Wood)
		end
	end
	for _, side in ipairs({ -1, 1 }) do -- two roof slopes
		deco("Roof", Vector3.new(18, 0.8, 8.6), base * CFrame.new(0, 11.4, side * 3.4) * CFrame.Angles(side * 0.62, 0, 0), roofColor, Enum.Material.Slate)
	end
	-- the triangle under the roof at both ends: a long box turned 45 degrees, its top corner just under the ridge
	deco("Gable", Vector3.new(15.6, 5.4, 5.4), base * CFrame.new(0, 10, 0) * CFrame.Angles(math.pi / 4, 0, 0), wallColor, Enum.Material.Plaster)
	deco("Door", Vector3.new(3, 5.5, 0.3), base * CFrame.new(0, 2.75, -6.1), WOOD, Enum.Material.WoodPlanks)
	deco("DoorKnob", Vector3.one * 0.4, base * CFrame.new(1, 2.8, -6.3), GOLD_COLOR, Enum.Material.Metal, Enum.PartType.Ball)
	for _, wx in ipairs({ -5, 5 }) do
		local win = deco("Window", Vector3.new(2.6, 2.4, 0.3), base * CFrame.new(wx, 5, -6.1), Color3.fromRGB(255, 215, 130), Enum.Material.Neon)
		win.Transparency = 0.15
		deco("WindowFrame", Vector3.new(3.2, 0.4, 0.4), base * CFrame.new(wx, 3.7, -6.2), WOOD, Enum.Material.Wood)
		deco("FlowerBox", Vector3.new(3, 0.7, 0.8), base * CFrame.new(wx, 3.2, -6.5), Color3.fromRGB(120, 80, 50), Enum.Material.WoodPlanks)
		for f = -1, 1 do
			deco("Flower", Vector3.one * 0.6, base * CFrame.new(wx + f * 0.9, 3.8, -6.5), FLOWER_COLORS[(f + 2 + math.floor(wx)) % #FLOWER_COLORS + 1], Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		end
	end
	solid("Chimney", Vector3.new(2, 6, 2), base * CFrame.new(5, 13, 3), DARK_STONE, Enum.Material.Brick)
	local smokePart = deco("ChimneyTop", Vector3.new(2.2, 0.4, 2.2), base * CFrame.new(5, 16.2, 3), DARK_STONE, Enum.Material.Brick)
	local smoke = Instance.new("ParticleEmitter")
	smoke.Color = ColorSequence.new(Color3.fromRGB(220, 220, 220))
	smoke.Size = NumberSequence.new(1, 3)
	smoke.Transparency = NumberSequence.new(0.5, 1)
	smoke.Lifetime = NumberRange.new(3, 4)
	smoke.Rate = 3
	smoke.Speed = NumberRange.new(2, 3)
	smoke.SpreadAngle = Vector2.new(10, 10)
	smoke.Parent = smokePart
	-- a little path stone and a fence in front
	deco("DoorStep", Vector3.new(4, 0.3, 3), base * CFrame.new(0, 0.15, -8), STONE, Enum.Material.Slate)
	blockCircle(x, z, 16)
end

-- a windmill (it doesn't turn: moving parts cost a lot of network on a server)
local function windmill(x, z)
	column("MillBase", 18, 9, Vector3.new(x, 9, z), Color3.fromRGB(225, 215, 195), Enum.Material.Plaster, true)
	for r = 0, 4 do
		column("MillRoof", 1.6, 10 - r * 2, Vector3.new(x, 18.8 + r * 1.5, z), Color3.fromRGB(160, 60, 50), Enum.Material.Slate)
	end
	local hub = CFrame.new(x, 15, z - 5)
	deco("Hub", Vector3.one * 1.6, hub, WOOD, Enum.Material.Wood, Enum.PartType.Ball)
	for i = 0, 3 do
		local arm = hub * CFrame.Angles(0, 0, i * math.pi / 2 + 0.3)
		deco("Sail", Vector3.new(1, 11, 0.3), arm * CFrame.new(0, 6, 0), WOOD, Enum.Material.Wood)
		deco("SailCloth", Vector3.new(3, 9, 0.15), arm * CFrame.new(1.8, 6.5, 0.1), Color3.fromRGB(245, 240, 225), Enum.Material.Fabric)
	end
	deco("MillDoor", Vector3.new(3, 5, 0.4), CFrame.new(x, 2.5, z - 4.4), WOOD, Enum.Material.WoodPlanks)
	blockCircle(x, z, 12)
end

local function mushroom(rng, x, z)
	local s = rng:NextNumber(0.7, 1.4)
	column("MushroomStem", 1.2 * s, 0.5 * s, Vector3.new(x, 0.6 * s, z), Color3.fromRGB(240, 230, 210), Enum.Material.SmoothPlastic)
	local cap = rng:NextNumber() < 0.6 and Color3.fromRGB(220, 50, 50) or Color3.fromRGB(190, 130, 70)
	deco("MushroomCap", Vector3.new(0.6 * s, 1.5 * s, 1.5 * s), CFrame.new(x, 1.3 * s, z) * CFrame.Angles(0, 0, math.pi / 2), cap, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	if cap.R > 0.8 then
		for _ = 1, 3 do
			deco("Dot", Vector3.one * 0.2 * s, CFrame.new(x + rng:NextNumber(-0.5, 0.5) * s, 1.6 * s, z + rng:NextNumber(-0.5, 0.5) * s), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		end
	end
end

local function grassTuft(rng, x, z)
	local color = GRASS:Lerp(Color3.fromRGB(150, 200, 90), rng:NextNumber())
	for i = 0, 2 do
		deco("Grass", Vector3.new(0.12, rng:NextNumber(0.8, 1.6), 0.5), CFrame.new(x, 0.5, z) * CFrame.Angles(0, i * 1.05 + rng:NextNumber(), rng:NextNumber(-0.3, 0.3)), color, Enum.Material.Grass)
	end
end

-- slightly lighter and darker patches of grass, so the ground isn't one flat colour
local function groundPatch(rng, x, z)
	local d = rng:NextNumber(14, 34)
	local color = GRASS:Lerp(rng:NextNumber() < 0.5 and Color3.fromRGB(70, 130, 55) or Color3.fromRGB(140, 185, 85), rng:NextNumber(0.3, 0.7))
	column("GrassPatch", 0.06, d, Vector3.new(x, 0.03, z), color, Enum.Material.Grass)
end

-- butterflies: little coloured specks drifting over the field (a ParticleEmitter, no moving parts)
local function butterflies(x, z)
	local spot = deco("Butterflies", Vector3.new(30, 1, 30), CFrame.new(x, 3, z), Color3.new(1, 1, 1))
	spot.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 220, 80)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 120, 200)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 200, 255)),
	})
	e.Size = NumberSequence.new(0.35)
	e.Lifetime = NumberRange.new(5, 8)
	e.Rate = 1.5
	e.Speed = NumberRange.new(1, 2.5)
	e.SpreadAngle = Vector2.new(180, 40)
	e.RotSpeed = NumberRange.new(-200, 200)
	e.Shape = Enum.ParticleEmitterShape.Box
	e.Parent = spot
end

-- big soft clouds high up
local function clouds()
	local rng = Random.new(31)
	for _ = 1, 16 do
		local x, z = rng:NextNumber(-600, 600), rng:NextNumber(-600, 600)
		local y = rng:NextNumber(170, 230)
		for _ = 1, rng:NextInteger(3, 5) do
			local s = rng:NextNumber(18, 34)
			local c = deco("Cloud", Vector3.one * s, CFrame.new(x + rng:NextNumber(-25, 25), y + rng:NextNumber(-4, 4), z + rng:NextNumber(-12, 12)), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
			c.Transparency = 0.15
			c.CastShadow = false
		end
	end
end

-- a stone lantern on each side where a dungeon path leaves the cross path
local function dungeonLanterns(x, z)
	for _, side in ipairs({ -1, 1 }) do
		local at = Vector3.new(x + side * 5.5, 0, z)
		solid("LanternBase", Vector3.new(1.6, 3.6, 1.6), CFrame.new(at + Vector3.new(0, 1.8, 0)), DARK_STONE, Enum.Material.Slate)
		local flame = deco("LanternFlame", Vector3.new(0.8, 1.1, 0.8), CFrame.new(at + Vector3.new(0, 4.2, 0)), Color3.fromRGB(255, 160, 60), Enum.Material.Neon)
		deco("LanternCap", Vector3.new(2, 0.5, 2), CFrame.new(at + Vector3.new(0, 5, 0)), DARK_STONE, Enum.Material.Slate)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 160, 80)
		light.Range = 12
		light.Parent = flame
	end
end

-- towerSpots: the World 1 dungeon middles (TowerService.WORLD1_SPOTS)
function WorldDecorService.Build(towerSpots)
	local old = workspace:FindFirstChild("Scenery")
	if old then
		old:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "Scenery"
	keepOut = {}

	grassGround()
	lighting()

	-- keep scenery out of the pens, every dungeon (and the space in front of its door) and the shops
	local plotFolder = workspace:FindFirstChild("Plots")
	local north = 235 -- where the pens end
	if plotFolder then
		for _, plot in ipairs(plotFolder:GetChildren()) do
			if plot:IsA("Model") then
				local cf, size = plot:GetBoundingBox()
				blockBox(cf.X - size.X / 2 - 4, cf.Z - size.Z / 2 - 4, cf.X + size.X / 2 + 4, cf.Z + size.Z / 2 + 4)
				north = math.max(north, cf.Z + size.Z / 2)
			end
		end
	else
		blockBox(-145, 95, 145, 240)
	end
	for _, spot in ipairs(towerSpots) do
		blockCircle(spot.X, spot.Z, 30)
		blockBox(spot.X - 8, spot.Z, spot.X + 8, spot.Z + 34) -- the doorstep
	end

	buildTown()
	townExtras()

	-- paths: town -> pens (and between the two rows of pens), town -> the dungeon doors
	path(0, 45, 0, north + 6, 9)
	path(-150, 92, 150, 92, 7)
	for _, x in ipairs({ -70, 70 }) do
		path(x, 92, x, north + 6, 6)
	end
	local rowZ = {}
	for _, spot in ipairs(towerSpots) do
		rowZ[spot.Z] = true
	end
	local frontZ = -math.huge -- the row nearest the town
	for z in pairs(rowZ) do
		frontZ = math.max(frontZ, z)
	end
	local crossZ = frontZ + 30 -- a path across, just in front of the first row of doors
	path(0, -45, 0, crossZ, 9)
	local minX, maxX = 0, 0
	for _, spot in ipairs(towerSpots) do
		minX, maxX = math.min(minX, spot.X), math.max(maxX, spot.X)
		local door = spot.Z + 21
		path(spot.X, crossZ, spot.X, door, 6) -- to the door; for the back row it goes between the front towers
	end
	path(minX, crossZ, maxX, crossZ, 7)
	for _, spot in ipairs(towerSpots) do
		if spot.Z == frontZ then
			dungeonLanterns(spot.X, crossZ - 6)
		end
	end

	-- signposts where the paths split
	signpost(Vector3.new(7, 0, crossZ + 7), Vector3.new(0, 0, 1), { "Dungeons", "<  1 - 9  >" })
	signpost(Vector3.new(7, 0, 86), Vector3.new(0, 0, -1), { "Pens", "Town" })

	-- a few lamps along the paths
	for _, z in ipairs({ 60, 80 }) do -- between the town and the pens (further north the path runs between pens)
		lamp(Vector3.new(-7, 0, z))
	end
	for x = minX + 40, maxX - 40, 80 do
		lamp(Vector3.new(x, 0, crossZ + 6))
	end

	-- a pond on each side between the town and the pens
	buildPond(-110, 40)
	buildPond(125, -10)

	-- a windmill and three cottages at the edge of the woods (before the trees, so the trees keep away)
	windmill(-175, 150)
	cottage(178, 140, math.pi / 2, Color3.fromRGB(240, 228, 200), Color3.fromRGB(150, 70, 55))
	cottage(-185, -40, -math.pi / 2, Color3.fromRGB(230, 215, 190), Color3.fromRGB(70, 90, 140))
	cottage(185, -150, math.pi / 2, Color3.fromRGB(245, 235, 215), Color3.fromRGB(90, 120, 70))

	-- the ground: lighter and darker grass patches, under everything else
	local patchRng = Random.new(3)
	for _ = 1, 70 do
		local x, z = patchRng:NextNumber(-260, 260), patchRng:NextNumber(-280, 300)
		if isFree(x, z, 4) then
			groundPatch(patchRng, x, z)
		end
	end

	-- the playing field: bushes, flowers and a few rocks and trees, not too many so nothing gets in the way
	local rng = Random.new(7)
	local fieldX = math.max(200, maxX + 40)
	for _ = 1, 400 do
		local x, z = rng:NextNumber(-fieldX, fieldX), rng:NextNumber(-260, north + 40)
		if isFree(x, z, 2) then
			local roll = rng:NextNumber()
			if roll < 0.45 then
				flowerPatch(rng, x, z)
			elseif roll < 0.8 then
				bush(rng, x, z)
			elseif roll < 0.9 then
				rock(rng, x, z)
			elseif isFree(x, z, 10) then
				roundTree(rng, x, z, rng:NextNumber(0.9, 1.3))
			end
		end
	end

	-- the forest: thick woods around the edges of the playing field
	for _ = 1, 650 do
		local x, z = rng:NextNumber(-430, 430), rng:NextNumber(-430, 470)
		local inField = math.abs(x) < fieldX and z > -270 and z < north + 50
		if not inField and isFree(x, z, 6) then
			local d = math.max(math.abs(x) - fieldX, -270 - z, z - north - 50) -- how far into the woods
			if rng:NextNumber() < 0.35 + d / 120 then
				if rng:NextNumber() < 0.55 then
					pineTree(rng, x, z, rng:NextNumber(1, 1.7))
				else
					roundTree(rng, x, z, rng:NextNumber(1, 1.6))
				end
			elseif rng:NextNumber() < 0.3 then
				bush(rng, x, z)
			end
		end
	end

	-- small things: grass tufts and mushrooms (near the woods), butterflies over the field
	for _ = 1, 260 do
		local x, z = rng:NextNumber(-fieldX - 30, fieldX + 30), rng:NextNumber(-290, north + 60)
		if isFree(x, z, 1) then
			local nearWoods = math.abs(x) > fieldX - 40 or z < -230 or z > north + 20
			if nearWoods and rng:NextNumber() < 0.35 then
				mushroom(rng, x, z)
			else
				grassTuft(rng, x, z)
			end
		end
	end
	for _, spot in ipairs({ Vector3.new(-110, 0, 40), Vector3.new(125, 0, -10), Vector3.new(-160, 0, 130), Vector3.new(170, 0, 60), Vector3.new(0, 0, -240), Vector3.new(-200, 0, -120) }) do
		butterflies(spot.X, spot.Z)
	end

	clouds()
	buildHills()
	folder.Parent = workspace
end

return WorldDecorService
