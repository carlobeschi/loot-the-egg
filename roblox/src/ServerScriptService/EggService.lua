--[[ EggService  (ModuleScript, put it in ServerScriptService)
  Eggs you own are real items:
    1. Bring an egg home from a dungeon and it goes into your backpack (the bar at the bottom of the screen).
       There is one item per rarity, for example "Rare Egg x2".
    2. Equip it (click it or press its number key) and click inside your pen to place it there.
    3. A placed egg counts down. When it says "Ready!", walk up and press E to hatch it into a pet.
  Placed eggs are saved, and they keep counting down while you're away.
  The saved egg counts (profile.eggs) are the truth. The backpack items only show them.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Data = Config.Data
local Sounds = require(ReplicatedStorage.Config:WaitForChild("Sounds"))

local EggService = {}
local DataService, PlotService, PetService
local notify = function(_player, _text) end

local EGG_SIZE = Vector3.new(2.4, 3.2, 2.4)
local MIN_GAP = 3.5 -- eggs can't be placed closer together than this
local MAX_REACH = 40 -- you must be this close to the spot you click

local function eggName(rarity)
	return Data.rarities[rarity] .. " Egg"
end

-- an egg-shaped Part (a Ball part is always round, so a sphere mesh stretches it)
local function eggPart(rarity, size)
	local p = Instance.new("Part")
	p.Size = size
	p.Color = Color3.fromHex(Data.rarityColors[rarity])
	p.Material = (rarity >= 5) and Enum.Material.Neon or Enum.Material.SmoothPlastic
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- ---------- backpack items ----------
local function findEggTool(player, rarity)
	for _, container in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
		if container then
			for _, item in ipairs(container:GetChildren()) do
				if item:IsA("Tool") and item:GetAttribute("EggRarity") == rarity then
					return item
				end
			end
		end
	end
	return nil
end

local function makeEggTool(rarity)
	local tool = Instance.new("Tool")
	tool:SetAttribute("EggRarity", rarity)
	tool.CanBeDropped = false
	tool.ToolTip = "Click inside your pen to place it"
	local handle = eggPart(rarity, Vector3.new(1.2, 1.6, 1.2))
	handle.Name = "Handle"
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	return tool
end

-- Makes the backpack match profile.eggs: one item per rarity you own, named with the count.
function EggService.SyncTools(player)
	local profile = DataService.Get(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not profile or not backpack then
		return
	end
	for rarity = 1, 8 do
		local count = profile.eggs[rarity] or 0
		local tool = findEggTool(player, rarity)
		if count > 0 then
			if not tool then
				tool = makeEggTool(rarity)
				tool.Parent = backpack
			end
			tool.Name = eggName(rarity) .. ((count > 1) and (" x" .. count) or "")
		elseif tool then
			tool:Destroy()
		end
	end
end

-- ---------- eggs placed in the pen ----------
local function placedFolder(plot)
	local folder = plot:FindFirstChild("PlacedEggs")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "PlacedEggs"
		folder.Parent = plot
	end
	return folder
end

local function countdownText(entry)
	local left = entry.hatchAt - os.time()
	if left <= 0 then
		return eggName(entry.rarity) .. "\nReady! Press E"
	end
	return eggName(entry.rarity) .. "\nHatching in " .. left .. "s"
end

local hatchPlaced -- defined below

-- Builds the egg model for one saved entry of profile.placedEggs.
local function spawnPlaced(player, entry)
	local plot = PlotService.GetPlot(player)
	local area = plot and plot:FindFirstChild("PenArea")
	if not area then
		return
	end
	local top = area.Size.Y / 2
	local egg = eggPart(entry.rarity, EGG_SIZE)
	egg.Name = "PlacedEgg"
	egg.Anchored = true
	egg.CanCollide = false
	egg.CFrame = area.CFrame * CFrame.new(entry.x, top + EGG_SIZE.Y / 2, entry.z)
	egg.Parent = placedFolder(plot)

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(150, 46)
	gui.StudsOffset = Vector3.new(0, EGG_SIZE.Y / 2 + 1.5, 0)
	gui.MaxDistance = 80
	gui.Parent = egg
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.Text = countdownText(entry)
	label.Parent = gui

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Hatch"
	prompt.ObjectText = eggName(entry.rarity)
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = egg
	prompt.Triggered:Connect(function(who)
		if who ~= player then
			notify(who, "That's not your egg!")
			return
		end
		hatchPlaced(player, entry, egg)
	end)

	-- countdown, then a wobble and sparkles when it is ready
	task.spawn(function()
		while egg.Parent and os.time() < entry.hatchAt do
			label.Text = countdownText(entry)
			task.wait(1)
		end
		if not egg.Parent then
			return
		end
		label.Text = countdownText(entry)
		prompt.Enabled = true
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = egg.Color
		sparkles.Parent = egg
		local base = egg.CFrame
		while egg.Parent do
			for _, angle in ipairs({ 12, -12, 0 }) do
				local tween = TweenService:Create(egg, TweenInfo.new(0.15), { CFrame = base * CFrame.Angles(0, 0, math.rad(angle)) })
				tween:Play()
				tween.Completed:Wait()
			end
			task.wait(1.2)
		end
	end)
	return egg
end

function hatchPlaced(player, entry, egg)
	local profile = DataService.Get(player)
	if not profile or not egg.Parent or os.time() < entry.hatchAt then
		return
	end
	local index = table.find(profile.placedEggs, entry)
	if not index then
		return
	end
	table.remove(profile.placedEggs, index)
	Sounds.PlayAt("hatch", egg.Position)
	egg:Destroy()
	local pet, stored = PetService.AddPet(player, entry.rarity)
	if pet then
		local def = Data.pets[pet.rarity][pet.kind]
		notify(player, "Hatched a " .. Data.rarities[pet.rarity] .. " " .. def.name .. "!" .. (stored and " Your pen is full, so it went to storage." or ""))
	end
end

-- Places one egg of this rarity from the backpack at this spot in the player's own pen.
function EggService.Place(player, rarity, position)
	local profile = DataService.Get(player)
	if not profile or type(rarity) ~= "number" or typeof(position) ~= "Vector3" then
		return
	end
	if not Data.rarities[rarity] or (profile.eggs[rarity] or 0) < 1 then
		return
	end
	local plot = PlotService.GetPlot(player)
	local area = plot and plot:FindFirstChild("PenArea")
	if not area then
		notify(player, "You don't have a pen yet.")
		return
	end
	if #profile.placedEggs >= Config.MaxPlacedEggs then
		notify(player, "Your pen already has " .. Config.MaxPlacedEggs .. " eggs. Hatch one first!")
		return
	end
	-- the spot must be inside YOUR pen (worked out in the pen's own directions, so a turned plot works too)
	local spot = area.CFrame:PointToObjectSpace(position)
	local halfX, halfZ = area.Size.X / 2 - EGG_SIZE.X / 2, area.Size.Z / 2 - EGG_SIZE.Z / 2
	if math.abs(spot.X) > halfX or math.abs(spot.Z) > halfZ or math.abs(spot.Y) > 6 then
		notify(player, "Click inside your pen to place the egg.")
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - position).Magnitude > MAX_REACH then
		notify(player, "Walk closer to your pen.")
		return
	end
	for _, other in ipairs(profile.placedEggs) do
		if Vector2.new(other.x - spot.X, other.z - spot.Z).Magnitude < MIN_GAP then
			notify(player, "Too close to another egg.")
			return
		end
	end

	profile.eggs[rarity] -= 1
	local entry = {
		rarity = rarity,
		x = math.round(spot.X * 10) / 10,
		z = math.round(spot.Z * 10) / 10,
		hatchAt = os.time() + Config.EggHatchSeconds[rarity],
	}
	table.insert(profile.placedEggs, entry)
	spawnPlaced(player, entry)
	EggService.SyncTools(player)
end

-- Rebuilds the saved placed eggs when the player joins.
function EggService.SpawnAllPlaced(player)
	local profile = DataService.Get(player)
	local plot = PlotService.GetPlot(player)
	if not profile or not plot then
		return
	end
	placedFolder(plot):ClearAllChildren()
	for _, entry in ipairs(profile.placedEggs) do
		spawnPlaced(player, entry)
	end
end

function EggService.Init(dataService, plotService, petService, notifyFunction)
	DataService = dataService
	PlotService = plotService
	PetService = petService
	notify = notifyFunction or notify
	PetService.OnEggsChanged(EggService.SyncTools)

	-- the backpack is emptied on every respawn, so fill it again each time
	local function watch(player)
		player.CharacterAdded:Connect(function()
			player:WaitForChild("Backpack", 10)
			task.wait(0.6) -- after CombatService has given the weapon, so the weapon stays in slot 1
			EggService.SyncTools(player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in ipairs(Players:GetPlayers()) do
		watch(player)
	end
end

return EggService
