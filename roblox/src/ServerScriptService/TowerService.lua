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
local DungeonService

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
function TowerService.Build(origin, depth, world, parent)
	local floors = Config.dungeonFloors(depth, world)
	local H = Config.FloorHeight
	local half = SIZE / 2
	local model = Instance.new("Model")
	model.Name = "Tower" .. depth
	model:SetAttribute("Depth", depth)
	model:SetAttribute("World", world)
	model:SetAttribute("Floors", floors)

	local base = CFrame.new(origin)
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

	TowerService.Watch(model, origin, depth, world, floors)
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
local function randomSpot(origin, k)
	local half = SIZE / 2 - WALL - 2
	local rampX = SIZE / 2 - WALL - RAMP_W / 2
	for _ = 1, 40 do
		local x = math.random() * 2 * half - half
		local z = math.random() * 2 * half - half
		local onRamp = (k > 0 and math.abs(x - rampSide(k - 1) * rampX) < RAMP_W / 2 + 1.5)
			or math.abs(x - rampSide(k) * rampX) < RAMP_W / 2 + 1.5
		local byDoor = (k == 0 and z < -half + 8)
		if not onRamp and not byDoor then
			return origin + Vector3.new(x, 1 + k * Config.FloorHeight + 5, z)
		end
	end
	return origin + Vector3.new(0, 1 + k * Config.FloorHeight + 5, 0)
end

function TowerService.Fill(model, origin, depth, world, floors)
	local folder = model:FindFirstChild("Enemies")
	folder:ClearAllChildren()
	local perFloor = (world == 2) and 7 or math.min(10, 4 + math.ceil(depth / 2))
	for k = 0, floors - 1 do
		for _ = 1, perFloor do
			DungeonService.SpawnEnemy(CFrame.new(randomSpot(origin, k)), depth, k, pickKind(depth, k), world, folder)
		end
		if k == floors - 1 then
			local spot = origin + Vector3.new(0, 1 + k * Config.FloorHeight + 8, 6)
			DungeonService.SpawnEnemy(CFrame.new(spot) * CFrame.Angles(0, math.pi, 0), depth, k, "boss", world, folder, function(killer, position)
				model:SetAttribute("Cleared", true)
				if killer then
					DungeonService.OnBossDefeated(killer, depth, world, position)
				else
					DungeonService.SpawnEgg(position, Config.rollEgg(depth))
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

function TowerService.Watch(model, origin, depth, world, floors)
	model:SetAttribute("Active", false)
	local entry = model:FindFirstChild("Entry")
	entry.Touched:Connect(function(hit)
		if model:GetAttribute("Active") then
			return
		end
		if Players:GetPlayerFromCharacter(hit.Parent) then
			model:SetAttribute("Active", true)
			TowerService.Fill(model, origin, depth, world, floors)
		end
	end)
end

function TowerService.Init(dungeonService)
	DungeonService = dungeonService
	-- the test tower: Dungeon 1, south of the town. Move or add towers here.
	local folder = workspace:FindFirstChild("Towers")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Towers"
		folder.Parent = workspace
	end
	TowerService.Build(Vector3.new(0, 0, -150), 1, 1, folder)
end

return TowerService
