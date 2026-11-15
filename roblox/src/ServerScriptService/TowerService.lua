--[[ TowerService  (ModuleScript, put it in ServerScriptService)
  Builds a dungeon tower out of Parts when the server starts, like the JS game generates its towers:
  a square tower (300 JS units = about 33 studs wide), floors 16 studs apart, ramps that alternate east and west,
  sleeping enemies on every floor and the boss on the top floor.
  Walking in through the door fills the tower with enemies. After the boss falls, the tower resets a while later.
  This is the "vertical slice": one tower, one boss. Later towers can be built the same way with a higher depth.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))

local TowerService = {}
local DungeonService, DataService
local notify = function(_player, _text) end

local SIZE = 34 -- tower width and depth in studs
local WALL = 1 -- wall thickness
local RAMP_W = 7 -- ramp width
local RAMP_L = 22 -- ramp length
local DOOR_W, DOOR_H = 8, 9
local RESET_AFTER = 45 -- seconds after the boss falls before the tower fills up again

local STONE = Color3.fromRGB(120, 116, 128)
local FLOOR = Color3.fromRGB(92, 84, 96)

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

	local base = CFrame.new(origin) * CFrame.Angles(0, math.pi, 0) -- door faces the town
	local rampX = half - WALL - RAMP_W / 2 -- distance of a ramp's middle from the tower's middle

	for k = 0, floors - 1 do
		local top = 1 + k * H -- the walking surface of floor k
		local floorCF = base * CFrame.new(0, top - 0.5, 0)
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

		-- a torch on each floor so it isn't pitch dark
		local torch = block(model, "Torch" .. k, Vector3.new(0.6, 0.6, 0.6), base * CFrame.new(0, top + H - 3, half - WALL - 0.4), Color3.fromRGB(255, 170, 60), Enum.Material.Neon)
		torch.CanCollide = false
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 180, 90)
		light.Range = 30
		light.Brightness = 1.5
		light.Parent = torch
	end

	-- walls, with a door in the front (-Z) wall on the ground floor
	local wallH = floors * H + 4
	local wy = wallH / 2
	block(model, "WallBack", Vector3.new(SIZE, wallH, WALL), base * CFrame.new(0, wy, half - WALL / 2), STONE)
	block(model, "WallEast", Vector3.new(WALL, wallH, SIZE), base * CFrame.new(half - WALL / 2, wy, 0), STONE)
	block(model, "WallWest", Vector3.new(WALL, wallH, SIZE), base * CFrame.new(-half + WALL / 2, wy, 0), STONE)
	local sideW = (SIZE - DOOR_W) / 2
	block(model, "WallFrontL", Vector3.new(sideW, wallH, WALL), base * CFrame.new(-half + sideW / 2, wy, -half + WALL / 2), STONE)
	block(model, "WallFrontR", Vector3.new(sideW, wallH, WALL), base * CFrame.new(half - sideW / 2, wy, -half + WALL / 2), STONE)
	block(model, "WallFrontTop", Vector3.new(DOOR_W, wallH - DOOR_H, WALL), base * CFrame.new(0, DOOR_H + (wallH - DOOR_H) / 2, -half + WALL / 2), STONE)

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

	TowerService.Watch(model, base, depth, world, floors)
	return model
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
					folder:ClearAllChildren()
					model:SetAttribute("Active", false)
					model:SetAttribute("Cleared", false)
				end)
			end)
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
