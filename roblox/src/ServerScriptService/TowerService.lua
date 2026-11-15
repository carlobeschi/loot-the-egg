--[[ TowerService  (ModuleScript, put it in ServerScriptService)
  Builds a dungeon tower out of Parts when the server starts, like the JS game generates its towers:
  a square tower (300 JS units = about 33 studs wide), floors 16 studs apart, ramps that alternate east and west,
  sleeping enemies on every floor and the boss on the top floor.
  Walking in through the door fills the tower with enemies. After the boss falls, the tower resets a while later.
  If you die inside a dungeon (or while carrying its egg), that dungeon resets too, unless someone else is still
  fighting in it.
  This is the "vertical slice": one tower, one boss. Later towers can be built the same way with a higher depth.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))

local TowerService = {}
local DungeonService, DataService
local notify = function(_player, _text) end
local built = {} -- every tower: { model, base, floors }

local SIZE = 34 -- tower width and depth in studs
local WALL = 1 -- wall thickness
local RAMP_W = 7 -- ramp width
local RAMP_L = 22 -- ramp length
local DOOR_W, DOOR_H = 8, 9
local RESET_AFTER = 45 -- seconds after the boss falls before the tower fills up again

-- Colours from the JS game's dungeon themes (TH): each dungeon gets one by its number, and its floors take
-- turns through the floor colours. wall = the stone, floor = the floor, light = torches and glowing windows.
local THEMES = {
	{ wall = Color3.fromHex("#6b737c"), floor = Color3.fromHex("#3a4046"), light = Color3.fromHex("#ff8a3d"), roof = Color3.fromHex("#5a2f22") },
	{ wall = Color3.fromHex("#6d89a0"), floor = Color3.fromHex("#33485a"), light = Color3.fromHex("#7fd0ff"), roof = Color3.fromHex("#22344a") },
	{ wall = Color3.fromHex("#8a4a38"), floor = Color3.fromHex("#4a2a22"), light = Color3.fromHex("#ff5a1a"), roof = Color3.fromHex("#3a1410") },
	{ wall = Color3.fromHex("#5f548f"), floor = Color3.fromHex("#2f2a4a"), light = Color3.fromHex("#c07aff"), roof = Color3.fromHex("#2a1f48") },
}
-- World 2 (Ember Wastes): black basalt with glowing lava cracks
local EMBER = { wall = Color3.fromRGB(62, 52, 52), floor = Color3.fromRGB(46, 36, 34), light = Color3.fromRGB(255, 96, 30), roof = Color3.fromRGB(30, 22, 22) }
local IRON = Color3.fromRGB(45, 42, 44)
local BONE = Color3.fromRGB(226, 218, 196)
local WOOD = Color3.fromRGB(110, 76, 46)

local function themeOf(depth, world)
	return world == 2 and EMBER or THEMES[(depth - 1) % 4 + 1]
end

local function block(parent, name, size, cframe, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Anchored = true
	p.Color = color
	p.Material = material or Enum.Material.Slate
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- a part that is only for looks: nothing bumps into it, clicks it or touches it
local function deco(parent, name, size, cframe, color, material)
	local p = block(parent, name, size, cframe, color, material)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

local function cylinder(parent, name, height, diameter, cframe, color, material)
	-- a Cylinder Part lies along X; turn it upright
	local p = deco(parent, name, Vector3.new(height, diameter, diameter), cframe * CFrame.Angles(0, 0, math.pi / 2), color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- a torch on a wall: an iron bracket, a bowl, a flame and its light. cframe = on the wall, facing into the room.
local function torch(parent, cframe, color, noLight)
	deco(parent, "Bracket", Vector3.new(0.4, 0.4, 1.2), cframe * CFrame.new(0, 0, -0.6), IRON, Enum.Material.Metal)
	local bowl = deco(parent, "Torch", Vector3.new(0.9, 0.5, 0.9), cframe * CFrame.new(0, 0.3, -1.2), IRON, Enum.Material.Metal)
	local flame = deco(parent, "Flame", Vector3.new(0.5, 0.7, 0.5), cframe * CFrame.new(0, 0.85, -1.2), color, Enum.Material.Neon)
	local fire = Instance.new("Fire")
	fire.Size = 2.5
	fire.Heat = 6
	fire.Color = color
	fire.SecondaryColor = color:Lerp(Color3.new(1, 1, 0.6), 0.5)
	fire.Parent = flame
	if not noLight then -- lots of lights slow phones down, so not every torch gets one
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 24
		light.Brightness = 1.6
		light.Parent = flame
	end
	return bowl
end

-- side = 1 puts the ramp along the east wall (+X), -1 along the west wall (JS rxOf alternates the same way)
local function rampSide(floorIndex)
	return (floorIndex % 2 == 0) and 1 or -1
end

-- Builds one tower. origin = the middle of the tower at ground level. Returns the tower Model.
-- The tower is turned so its door faces +Z (north, toward the town). Everything inside is placed through `base`.
function TowerService.Build(origin, depth, world, parent)
	local floors = Config.dungeonFloors(depth, world)
	local H = Config.FloorHeight
	local half = SIZE / 2
	local model = Instance.new("Model")
	model.Name = "Tower" .. depth
	model:SetAttribute("Depth", depth)
	model:SetAttribute("World", world)
	model:SetAttribute("Floors", floors)
	-- for the minimap: with streaming on, a far tower's parts aren't on the client, but the Model and these are
	model:SetAttribute("Center", origin)
	model:SetAttribute("Size", SIZE)

	local base = CFrame.new(origin) * CFrame.Angles(0, math.pi, 0) -- door faces the town
	local theme = themeOf(depth, world)
	local STONE = theme.wall
	local wallMaterial = world == 2 and Enum.Material.Basalt or Enum.Material.Cobblestone
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = model
	local rampX = half - WALL - RAMP_W / 2 -- distance of a ramp's middle from the tower's middle

	for k = 0, floors - 1 do
		local top = 1 + k * H -- the walking surface of floor k
		local floorCF = base * CFrame.new(0, top - 0.5, 0)
		local FLOOR = world == 2 and EMBER.floor or THEMES[(depth - 1 + k) % 4 + 1].floor
		if k == 0 then
			block(model, "Floor0", Vector3.new(SIZE, 1, SIZE), floorCF, FLOOR)
		else
			-- leave a hole where the ramp from the floor below comes up
			local side = rampSide(k - 1)
			local holeX = side * rampX
			local restW = SIZE - RAMP_W - WALL
			block(model, "Floor" .. k, Vector3.new(restW, 1, SIZE), floorCF * CFrame.new(-side * (RAMP_W + WALL) / 2, 0, 0), FLOOR)
			-- the strip next to the wall, except over the ramp
			local stripLen = (SIZE - RAMP_L) / 2
			block(model, "Floor" .. k .. "Front", Vector3.new(RAMP_W + WALL, 1, stripLen), floorCF * CFrame.new(holeX + side * WALL / 2, 0, -half + stripLen / 2), FLOOR)
			block(model, "Floor" .. k .. "Back", Vector3.new(RAMP_W + WALL, 1, stripLen), floorCF * CFrame.new(holeX + side * WALL / 2, 0, half - stripLen / 2), FLOOR)
		end

		-- the ramp up to the next floor (a WedgePart rises toward its back, +Z)
		if k < floors - 1 then
			local side = rampSide(k)
			local ramp = Instance.new("WedgePart")
			ramp.Name = "Ramp" .. k
			ramp.Size = Vector3.new(RAMP_W, H, RAMP_L)
			ramp.CFrame = base * CFrame.new(side * rampX, top + H / 2, 0)
			ramp.Anchored = true
			ramp.Color = Color3.fromRGB(140, 110, 80)
			ramp.Material = Enum.Material.WoodPlanks
			ramp.Parent = model
		end

		-- inside: torches, pillars, a glowing circle on the floor and some junk in the corners
		TowerService.DecorateFloor(decor, base, k, top, floors, depth, world, theme)
	end

	-- walls, with a door in the front (-Z) wall on the ground floor
	local wallH = floors * H + 4
	local wy = wallH / 2
	block(model, "WallBack", Vector3.new(SIZE, wallH, WALL), base * CFrame.new(0, wy, half - WALL / 2), STONE, wallMaterial)
	block(model, "WallEast", Vector3.new(WALL, wallH, SIZE), base * CFrame.new(half - WALL / 2, wy, 0), STONE, wallMaterial)
	block(model, "WallWest", Vector3.new(WALL, wallH, SIZE), base * CFrame.new(-half + WALL / 2, wy, 0), STONE, wallMaterial)
	local sideW = (SIZE - DOOR_W) / 2
	block(model, "WallFrontL", Vector3.new(sideW, wallH, WALL), base * CFrame.new(-half + sideW / 2, wy, -half + WALL / 2), STONE, wallMaterial)
	block(model, "WallFrontR", Vector3.new(sideW, wallH, WALL), base * CFrame.new(half - sideW / 2, wy, -half + WALL / 2), STONE, wallMaterial)
	block(model, "WallFrontTop", Vector3.new(DOOR_W, wallH - DOOR_H, WALL), base * CFrame.new(0, DOOR_H + (wallH - DOOR_H) / 2, -half + WALL / 2), STONE, wallMaterial)

	TowerService.DecorateOutside(decor, base, floors, wallH, depth, world, theme)

	-- an invisible pad just inside the door: stepping on it fills the tower with enemies
	local entry = block(model, "Entry", Vector3.new(DOOR_W, 6, 4), base * CFrame.new(0, 4, -half + WALL + 2), Color3.new(1, 0, 0))
	entry.Transparency = 1
	entry.CanCollide = false
	entry.CanQuery = false

	-- the gate in the doorway. Locked or open is different for every player (it depends on which dungeons
	-- they have beaten), so ClientTowers colors it and makes it solid on each player's own screen.
	-- The server also checks at the Entry pad, so nobody can sneak past it.
	local gate = block(model, "Gate", Vector3.new(DOOR_W, DOOR_H, 0.6), base * CFrame.new(0, DOOR_H / 2, -half - 0.4), Color3.fromRGB(255, 80, 80), Enum.Material.ForceField)
	gate.CanCollide = false
	gate.Transparency = 0.3

	-- a sign over the door
	local sign = block(model, "Sign", Vector3.new(DOOR_W + 4, 3, 0.4), base * CFrame.new(0, DOOR_H + 2.5, -half - 0.3), Color3.fromRGB(60, 40, 25), Enum.Material.Wood)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = sign
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextScaled = true
	text.Font = Enum.Font.FredokaOne
	text.Text = "Dungeon " .. depth
	text.Parent = gui

	local enemies = Instance.new("Folder")
	enemies.Name = "Enemies"
	enemies.Parent = model
	model.Parent = parent or workspace

	table.insert(built, { model = model, base = base, floors = floors })
	TowerService.Watch(model, base, depth, world, floors)
	return model
end

-- The outside of a tower: a stone base, bands between the floors, battlements, round corner turrets with
-- pointed roofs, glowing window slits, a door frame with two torches and two banners.
function TowerService.DecorateOutside(decor, base, floors, wallH, depth, world, theme)
	local H = Config.FloorHeight
	local half = SIZE / 2
	local trim = theme.wall:Lerp(Color3.new(0, 0, 0), 0.25)
	local trimMaterial = world == 2 and Enum.Material.CrackedLava or Enum.Material.Slate
	local sides = { -- each wall: a CFrame at its middle on the outside, facing out, and its length
		base * CFrame.new(0, 0, half) * CFrame.Angles(0, math.pi, 0), -- back
		base * CFrame.new(half, 0, 0) * CFrame.Angles(0, -math.pi / 2, 0), -- east
		base * CFrame.new(-half, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), -- west
		base * CFrame.new(0, 0, -half), -- front (the door side)
	}

	block(decor, "Base", Vector3.new(SIZE + 4, 1.6, SIZE + 4), base * CFrame.new(0, 0.2, 0), trim, trimMaterial)
	for i, side in ipairs(sides) do
		-- a band of stone where each floor is
		for k = 1, floors - 1 do
			deco(decor, "Band", Vector3.new(SIZE + 1.2, 0.8, 1.2), side * CFrame.new(0, 1 + k * H - 0.4, -0.1), trim, trimMaterial)
		end
		-- battlements along the top
		for m = -3, 3 do
			deco(decor, "Merlon", Vector3.new(2.2, 2.4, WALL + 0.6), side * CFrame.new(m * 4.2, wallH + 1.2, 0.5), theme.wall, Enum.Material.Cobblestone)
		end
		deco(decor, "Ledge", Vector3.new(SIZE + 1.6, 0.8, 1.6), side * CFrame.new(0, wallH - 0.4, -0.2), trim, trimMaterial)
		-- window slits that glow with torchlight, two per floor (not on the door wall's ground floor)
		for k = 0, floors - 1 do
			if not (i == 4 and k == 0) then
				for _, x in ipairs({ -8, 8 }) do
					local slit = deco(decor, "Window", Vector3.new(0.9, 3.2, WALL + 0.3), side * CFrame.new(x, 1 + k * H + 8, 0.5), theme.light, Enum.Material.Neon)
					slit.Transparency = 0.15
					deco(decor, "WindowArch", Vector3.new(1.7, 0.5, 0.6), side * CFrame.new(x, 1 + k * H + 9.8, -0.2), trim, trimMaterial)
				end
			end
		end
	end

	-- round turrets on the corners with cone-like roofs and a little flag
	local turretH = wallH + 5
	for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		local at = base * CFrame.new(c[1] * half, 0, c[2] * half)
		cylinder(decor, "Turret", turretH, 6, at * CFrame.new(0, turretH / 2, 0), theme.wall, Enum.Material.Cobblestone)
		cylinder(decor, "TurretTop", 1.4, 7.2, at * CFrame.new(0, turretH + 0.2, 0), trim, trimMaterial)
		for r = 0, 4 do -- the roof: rings that get smaller as they go up
			cylinder(decor, "Roof", 1.6, 7 - r * 1.45, at * CFrame.new(0, turretH + 1.6 + r * 1.4, 0), theme.roof, Enum.Material.Slate)
		end
		deco(decor, "FlagPole", Vector3.new(0.25, 4, 0.25), at * CFrame.new(0, turretH + 9.5, 0), IRON, Enum.Material.Metal)
		deco(decor, "Flag", Vector3.new(0.1, 1.4, 2.2), at * CFrame.new(0, turretH + 10.6, 1.1), theme.light, Enum.Material.Fabric)
		-- a glowing slit on each turret, facing out
		local outward = CFrame.lookAt(at.Position, at.Position + (at.Position - base.Position) * Vector3.new(1, 0, 1))
		for k = 0, floors - 1 do
			deco(decor, "Window", Vector3.new(0.8, 2.6, 0.4), outward * CFrame.new(0, 1 + k * H + 10, -2.95), theme.light, Enum.Material.Neon)
		end
	end

	-- the door: a stone frame, a torch on each side and banners further out
	local front = sides[4]
	for _, sx in ipairs({ -1, 1 }) do
		block(decor, "DoorPillar", Vector3.new(1.6, DOOR_H, 1.6), front * CFrame.new(sx * (DOOR_W / 2 + 0.8), DOOR_H / 2 + 1, -0.5), trim, trimMaterial)
		torch(decor, front * CFrame.new(sx * (DOOR_W / 2 + 3), 6.5, 0), theme.light, sx == 1)
		-- a banner hanging from a rod
		local bannerY = 11.5 -- under the stone band of floor 1
		deco(decor, "BannerRod", Vector3.new(3.8, 0.3, 0.3), front * CFrame.new(sx * 11, bannerY + 4, -0.4), IRON, Enum.Material.Metal)
		deco(decor, "Banner", Vector3.new(3.2, 7.5, 0.15), front * CFrame.new(sx * 11, bannerY, -0.35), theme.roof:Lerp(theme.light, 0.25), Enum.Material.Fabric)
		deco(decor, "BannerTip", Vector3.new(2.26, 2.26, 0.16), front * CFrame.new(sx * 11, bannerY - 3.7, -0.35) * CFrame.Angles(0, 0, math.pi / 4), theme.roof:Lerp(theme.light, 0.25), Enum.Material.Fabric)
		deco(decor, "Emblem", Vector3.new(1.1, 1.1, 0.2), front * CFrame.new(sx * 11, bannerY + 1, -0.45) * CFrame.Angles(0, 0, math.pi / 4), theme.light, Enum.Material.Neon)
	end
	block(decor, "DoorTop", Vector3.new(DOOR_W + 3.2, 1, 1.6), front * CFrame.new(0, DOOR_H + 0.5, -0.5), trim, trimMaterial)
	-- skulls on the door top of World 2 dungeons
	if world == 2 then
		for _, sx in ipairs({ -1, 1 }) do
			local skull = deco(decor, "Skull", Vector3.new(1, 1, 1), front * CFrame.new(sx * 2.8, DOOR_H + 1.6, -1), BONE, Enum.Material.SmoothPlastic)
			skull.Shape = Enum.PartType.Ball
		end
	end
end

-- The inside of floor k: two torches on the back wall (two more by the door upstairs), a pillar in each
-- corner, a glowing circle in the middle of the floor and rubble, bones and crates in the corners.
-- The boss floor gets a big red circle under the boss and two fire bowls.
function TowerService.DecorateFloor(decor, base, k, top, floors, depth, world, theme)
	local H = Config.FloorHeight
	local half = SIZE / 2
	local inner = half - WALL
	local rng = Random.new(depth * 100 + k) -- the same look on every server
	local floorColor = world == 2 and EMBER.floor or THEMES[(depth - 1 + k) % 4 + 1].floor
	local boss = (k == floors - 1)

	-- torches on the back wall (and the front wall upstairs), facing into the room
	for _, x in ipairs({ -6, 6 }) do
		torch(decor, base * CFrame.new(x, top + 6, inner), theme.light)
		if k > 0 then
			torch(decor, base * CFrame.new(x, top + 6, -inner) * CFrame.Angles(0, math.pi, 0), theme.light, true)
		end
	end

	-- corner pillars (clear of the ramps, which run along the side walls from z = -11 to 11)
	for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		local at = base * CFrame.new(c[1] * (inner - 1.3), top + (H - 1) / 2, c[2] * (inner - 1.3))
		block(decor, "Pillar", Vector3.new(2.6, H - 1, 2.6), at, theme.wall:Lerp(Color3.new(0, 0, 0), 0.15), Enum.Material.Cobblestone)
		deco(decor, "PillarFoot", Vector3.new(3.4, 0.8, 3.4), at * CFrame.new(0, -(H - 1) / 2 + 0.4, 0), theme.wall, Enum.Material.Slate)
		deco(decor, "PillarHead", Vector3.new(3.4, 0.8, 3.4), at * CFrame.new(0, (H - 1) / 2 - 0.4, 0), theme.wall, Enum.Material.Slate)
	end

	-- a glowing magic circle on the floor
	local circleZ = boss and 6 or 0
	local circleColor = boss and Color3.fromRGB(255, 50, 40) or theme.light
	local size = boss and 13 or 9
	local ring = cylinder(decor, "Circle", 0.1, size, base * CFrame.new(0, top + 0.05, circleZ), circleColor, Enum.Material.Neon)
	ring.Transparency = 0.35
	cylinder(decor, "CircleInside", 0.12, size - 0.8, base * CFrame.new(0, top + 0.06, circleZ), floorColor, Enum.Material.Slate)
	local rune = deco(decor, "Rune", Vector3.new(size * 0.55, 0.13, size * 0.55), base * CFrame.new(0, top + 0.07, circleZ) * CFrame.Angles(0, math.pi / 4, 0), circleColor, Enum.Material.Neon)
	rune.Transparency = 0.55
	deco(decor, "RuneInside", Vector3.new(size * 0.55 - 0.6, 0.14, size * 0.55 - 0.6), base * CFrame.new(0, top + 0.075, circleZ) * CFrame.Angles(0, math.pi / 4, 0), floorColor, Enum.Material.Slate)

	if boss then
		-- fire bowls on each side of the boss
		for _, x in ipairs({ -7, 7 }) do
			local at = base * CFrame.new(x, top, 9)
			cylinder(decor, "BrazierLeg", 2.4, 0.7, at * CFrame.new(0, 1.2, 0), IRON, Enum.Material.Metal)
			local bowl = cylinder(decor, "Brazier", 0.9, 2.4, at * CFrame.new(0, 2.6, 0), IRON, Enum.Material.Metal)
			local fire = Instance.new("Fire")
			fire.Size = 5
			fire.Heat = 9
			fire.Color = Color3.fromRGB(255, 90, 30)
			fire.SecondaryColor = Color3.fromRGB(255, 200, 60)
			fire.Parent = bowl
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 110, 50)
			light.Range = 20
			light.Brightness = 1.2
			light.Parent = bowl
		end
	end

	-- junk in the back corners and, upstairs, crates in the front corners
	for _, cx in ipairs({ -1, 1 }) do
		local corner = base * CFrame.new(cx * (inner - 4.5), top, inner - 2)
		-- rubble: a few broken stones
		for _ = 1, 4 do
			local s = rng:NextNumber(0.6, 1.4)
			deco(decor, "Rubble", Vector3.new(s, s * 0.7, s), corner * CFrame.new(rng:NextNumber(-1.5, 1.5), s * 0.3, rng:NextNumber(-1, 1)) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 3), rng:NextNumber(0, 1)), theme.wall, Enum.Material.Slate)
		end
		-- bones and a skull
		local bones = base * CFrame.new(cx * (inner - 7), top, inner - 3) * CFrame.Angles(0, rng:NextNumber(0, 3), 0)
		for b = -1, 1, 2 do
			local bone = deco(decor, "Bone", Vector3.new(1.8, 0.25, 0.25), bones * CFrame.new(0, 0.15, 0) * CFrame.Angles(0, b * 0.5, 0), BONE, Enum.Material.SmoothPlastic)
			bone.Shape = Enum.PartType.Cylinder
		end
		local skull = deco(decor, "Skull", Vector3.new(0.7, 0.7, 0.7), bones * CFrame.new(0.9, 0.35, 0.3), BONE, Enum.Material.SmoothPlastic)
		skull.Shape = Enum.PartType.Ball
		if k > 0 then
			local crates = base * CFrame.new(cx * (inner - 4), top, -inner + 2.5)
			block(decor, "Crate", Vector3.new(2.4, 2.4, 2.4), crates * CFrame.new(0, 1.2, 0) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0), WOOD, Enum.Material.WoodPlanks)
			deco(decor, "Crate", Vector3.new(1.8, 1.8, 1.8), crates * CFrame.new(rng:NextNumber(-0.3, 0.3), 3.3, 0) * CFrame.Angles(0, rng:NextNumber(0, 1), 0), WOOD, Enum.Material.WoodPlanks)
			local barrel = cylinder(decor, "Barrel", 2.2, 1.8, crates * CFrame.new(-cx * 2.6, 1.1, 0.3), WOOD:Lerp(Color3.new(0, 0, 0), 0.2), Enum.Material.Wood)
			barrel.CanCollide = true
		end
	end
	-- chains hanging from the ceiling (not on the boss floor, so the boss has room)
	if not boss then
		for _, x in ipairs({ -5, 5 }) do
			local length = rng:NextNumber(3, 6)
			deco(decor, "Chain", Vector3.new(0.18, length, 0.18), base * CFrame.new(x, top + H - 1 - length / 2, rng:NextNumber(-4, 4)), IRON, Enum.Material.DiamondPlate)
		end
	end
end

-- picks normal / runner / tank like spawn() in the JS game
local function pickKind(depth, floorIndex)
	local d = depth + floorIndex * 0.7
	if d >= 2 and math.random() < 0.25 then
		return "tank"
	elseif math.random() < 0.22 then
		return "runner"
	end
	return "normal"
end

-- a random spot on floor k that is not on a ramp, a hole or right by the door
local function randomSpot(base, k)
	local half = SIZE / 2 - WALL - 2
	local rampX = SIZE / 2 - WALL - RAMP_W / 2
	for _ = 1, 40 do
		local x = math.random() * 2 * half - half
		local z = math.random() * 2 * half - half
		local onRamp = (k > 0 and math.abs(x - rampSide(k - 1) * rampX) < RAMP_W / 2 + 1.5)
			or math.abs(x - rampSide(k) * rampX) < RAMP_W / 2 + 1.5
		local byDoor = (k == 0 and z < -half + 8)
		if not onRamp and not byDoor then
			return base * Vector3.new(x, 1 + k * Config.FloorHeight + 5, z)
		end
	end
	return base * Vector3.new(0, 1 + k * Config.FloorHeight + 5, 0)
end

-- base = the tower's CFrame from Build (its middle at ground level, door on its -Z side)
function TowerService.Fill(model, base, depth, world, floors)
	local folder = model:FindFirstChild("Enemies")
	folder:ClearAllChildren()
	local run = (model:GetAttribute("Run") or 0) + 1
	model:SetAttribute("Run", run)
	local perFloor = (world == 2) and 7 or math.min(10, 4 + math.ceil(depth / 2))
	for k = 0, floors - 1 do
		for _ = 1, perFloor do
			DungeonService.SpawnEnemy(CFrame.new(randomSpot(base, k)), depth, k, pickKind(depth, k), world, folder)
		end
		if k == floors - 1 then
			-- the boss stands at the back of the top floor, facing the way up
			DungeonService.SpawnEnemy(base * CFrame.new(0, 1 + k * Config.FloorHeight + 8, 6), depth, k, "boss", world, folder, function(killer, position)
				model:SetAttribute("Cleared", true)
				if killer then
					DungeonService.OnBossDefeated(killer, depth, world, position, folder)
				else
					DungeonService.SpawnEgg(position, Config.rollEgg(depth), folder)
				end
				-- reset the tower a while later
				task.delay(RESET_AFTER, function()
					if model:GetAttribute("Run") == run then -- not already reset and filled again since
						TowerService.Reset(model)
					end
				end)
			end)
		end
	end
end

-- Empties a tower: its enemies go, and the next player through the door fills it again from the start.
function TowerService.Reset(model)
	model:FindFirstChild("Enemies"):ClearAllChildren()
	model:SetAttribute("Run", (model:GetAttribute("Run") or 0) + 1)
	model:SetAttribute("Active", false)
	model:SetAttribute("Cleared", false)
end

local function inside(tower, position)
	local p = tower.base:PointToObjectSpace(position)
	return math.abs(p.X) < SIZE / 2 and math.abs(p.Z) < SIZE / 2 and p.Y > -3 and p.Y < tower.floors * Config.FloorHeight + 6
end

-- someone other than `player` is alive inside this tower
local function othersInside(tower, player)
	for _, other in ipairs(Players:GetPlayers()) do
		local character = other ~= player and other.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and humanoid.Health > 0 and root and inside(tower, root.Position) then
			return true
		end
	end
	return false
end

-- Called by DungeonService when a player dies. eggGroup = the Enemies folder whose egg they were carrying, if any.
function TowerService.PlayerDied(player, character, eggGroup)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local position = root and root.Position
	for _, tower in ipairs(built) do
		local here = position and inside(tower, position)
		local theirEgg = eggGroup ~= nil and tower.model:FindFirstChild("Enemies") == eggGroup
		if (here or theirEgg) and tower.model:GetAttribute("Active") and not othersInside(tower, player) then
			TowerService.Reset(tower.model)
			DungeonService.ClearEggs(tower.model:FindFirstChild("Enemies")) -- no keeping the old egg and winning a new one
			notify(player, "Dungeon " .. tower.model:GetAttribute("Depth") .. " has reset. Try again!")
		end
	end
end

-- Dungeon N opens after you beat Dungeon N-1 (Dungeon 1 is always open). World 2 counts from depth 10.
function TowerService.IsUnlocked(player, depth, world)
	local profile = DataService.Get(player)
	if not profile then
		return false
	end
	if world == 2 then
		return profile.world2Unlocked and profile.bestDepth2 >= depth - 10
	end
	return profile.bestDepth >= depth - 1
end

function TowerService.Watch(model, base, depth, world, floors)
	model:SetAttribute("Active", false)
	local entry = model:FindFirstChild("Entry")
	local lastWarned = {}
	entry.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then
			return
		end
		if not TowerService.IsUnlocked(player, depth, world) then
			-- put them back outside the door
			local root = hit.Parent:FindFirstChild("HumanoidRootPart")
			if root then
				root.CFrame = base * CFrame.new(0, 4, -SIZE / 2 - 6) -- outside the door, facing away
			end
			if os.clock() - (lastWarned[player] or 0) > 2 then
				lastWarned[player] = os.clock()
				notify(player, "Dungeon " .. depth .. " is locked. Beat Dungeon " .. (depth - 1) .. " first!")
			end
			return
		end
		if not model:GetAttribute("Active") then
			model:SetAttribute("Active", true)
			TowerService.Fill(model, base, depth, world, floors)
		end
	end)
end

-- Where the World 1 dungeons stand: two rows south of the town, the deeper ones further away.
local WORLD1_SPOTS = {
	Vector3.new(0, 0, -150), -- Dungeon 1
	Vector3.new(120, 0, -150),
	Vector3.new(-120, 0, -150),
	Vector3.new(240, 0, -150),
	Vector3.new(-240, 0, -150),
	Vector3.new(60, 0, -290),
	Vector3.new(-60, 0, -290),
	Vector3.new(180, 0, -290),
	Vector3.new(-180, 0, -290), -- Dungeon 9
}

-- World 2 (Ember Wastes): Dungeons 10 to 14 in the first row south of the World 2 town, 15 to 18 further south.
-- Offsets from Config.World2Origin.
local WORLD2_SPOTS = {
	Vector3.new(0, 0, 50), -- Dungeon 10
	Vector3.new(110, 0, 50),
	Vector3.new(-110, 0, 50),
	Vector3.new(220, 0, 50),
	Vector3.new(-220, 0, 50),
	Vector3.new(55, 0, -140),
	Vector3.new(-55, 0, -140),
	Vector3.new(165, 0, -140),
	Vector3.new(-165, 0, -140), -- Dungeon 18
}

function TowerService.Init(dungeonService, dataService, notifyFunction)
	DungeonService = dungeonService
	DataService = dataService
	notify = notifyFunction or notify
	DungeonService.OnPlayerDied = TowerService.PlayerDied
	local folder = workspace:FindFirstChild("Towers")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Towers"
		folder.Parent = workspace
	end
	for depth, spot in ipairs(WORLD1_SPOTS) do
		TowerService.Build(spot, depth, 1, folder)
	end
	for i, offset in ipairs(WORLD2_SPOTS) do
		TowerService.Build(Config.World2Origin + offset, 9 + i, 2, folder)
	end
end

return TowerService
