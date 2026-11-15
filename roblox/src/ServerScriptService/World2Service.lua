--[[ World2Service  (ModuleScript, put it in ServerScriptService)
  World 2, the Ember Wastes, is a second zone in the same place, far east of World 1 (Config.World2Origin).
  It has its own small town (banks eggs like the World 1 town), a portal back home, and Dungeons 10 to 18
  (TowerService builds those). You get there from the World Gate window once World 2 is unlocked.

  The player attribute "World" (1 or 2) says where someone is. It is not saved: joining always starts at home.
  Dying in World 2 puts you back in the World 2 town (Main asks SpawnCFrame for that).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))

local World2Service = {}
local DataService, DungeonService, PlotService
local notify = function(_player, _text) end

local ORIGIN = Config.World2Origin
local GROUND = Vector3.new(620, 16, 560) -- the ground is a thick slab whose top is at y = 0, like the Baseplate
local TOWN = ORIGIN + Vector3.new(0, 0, 200) -- town in the north, the dungeons are south of it

local function part(parent, name, size, cframe, color, material)
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

local function signOn(target, text, face)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Front
	gui.Parent = target
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.Parent = gui
end

-- Where you appear in World 2 (in the town, facing the dungeons).
function World2Service.SpawnCFrame()
	return CFrame.lookAt(TOWN + Vector3.new(0, 4, 10), TOWN + Vector3.new(0, 4, -100))
end

local function build()
	local folder = workspace:FindFirstChild("World2")
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "World2"

	-- scorched ground with a lighter path from the town down to the dungeons
	part(folder, "Ground", GROUND, CFrame.new(ORIGIN - Vector3.new(0, GROUND.Y / 2, 0)), Color3.fromRGB(70, 45, 40), Enum.Material.Basalt)
	part(folder, "Path", Vector3.new(24, 0.2, 420), CFrame.new(ORIGIN + Vector3.new(0, 0.1, 10)), Color3.fromRGB(120, 80, 60), Enum.Material.Sand)

	-- decoration: glowing lava cracks (just for show, they don't hurt) and dark rocks, placed the same every time
	local rng = Random.new(2)
	for _ = 1, 26 do
		local x = rng:NextNumber(-GROUND.X / 2 + 20, GROUND.X / 2 - 20)
		local z = rng:NextNumber(-GROUND.Z / 2 + 20, GROUND.Z / 2 - 20)
		if math.abs(x) > 20 then -- keep the path clear
			local crack = part(folder, "Lava", Vector3.new(rng:NextNumber(3, 6), 0.2, rng:NextNumber(14, 30)),
				CFrame.new(ORIGIN + Vector3.new(x, 0.1, z)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
				Color3.fromRGB(255, 110, 30), Enum.Material.Neon)
			crack.CanCollide = false
			crack.CanQuery = false
		end
	end
	for _ = 1, 40 do
		local x = rng:NextNumber(-GROUND.X / 2 + 10, GROUND.X / 2 - 10)
		local z = rng:NextNumber(-GROUND.Z / 2 + 10, GROUND.Z / 2 - 10)
		if math.abs(x) > 20 then
			local s = rng:NextNumber(3, 9)
			part(folder, "Rock", Vector3.new(s, s * rng:NextNumber(0.6, 1.4), s),
				CFrame.new(ORIGIN + Vector3.new(x, s / 3, z)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3)),
				Color3.fromRGB(45, 35, 35), Enum.Material.Rock)
		end
	end

	-- the town: a plaza, an invisible zone that banks eggs, a sign and the portal home
	part(folder, "Plaza", Vector3.new(70, 0.4, 60), CFrame.new(TOWN + Vector3.new(0, 0.2, 0)), Color3.fromRGB(150, 120, 100), Enum.Material.Cobblestone)
	local zone = part(folder, "TownZone", Vector3.new(70, 30, 60), CFrame.new(TOWN + Vector3.new(0, 15, 0)), Color3.fromRGB(255, 140, 60))
	zone.Transparency = 1
	zone.CanCollide = false
	zone.CanQuery = false
	CollectionService:AddTag(zone, "TownZone")

	local sign = part(folder, "Sign", Vector3.new(26, 6, 1), CFrame.new(TOWN + Vector3.new(0, 9, -32)) * CFrame.Angles(0, math.pi, 0), Color3.fromRGB(60, 35, 25), Enum.Material.Wood)
	signOn(sign, "Ember Wastes (World 2)", Enum.NormalId.Front)
	signOn(sign, "Ember Wastes (World 2)", Enum.NormalId.Back)
	for _, x in ipairs({ -12, 12 }) do
		part(folder, "SignPost", Vector3.new(1, 6, 1), CFrame.new(TOWN + Vector3.new(x, 3, -32)), Color3.fromRGB(60, 35, 25), Enum.Material.Wood)
	end

	-- portal home: a stone arch with a glowing middle and a prompt
	local portalBase = CFrame.new(TOWN + Vector3.new(0, 0, 26))
	part(folder, "PortalLeft", Vector3.new(2, 12, 2), portalBase * CFrame.new(-6, 6, 0), Color3.fromRGB(90, 90, 100), Enum.Material.Slate)
	part(folder, "PortalRight", Vector3.new(2, 12, 2), portalBase * CFrame.new(6, 6, 0), Color3.fromRGB(90, 90, 100), Enum.Material.Slate)
	part(folder, "PortalTop", Vector3.new(14, 2, 2), portalBase * CFrame.new(0, 13, 0), Color3.fromRGB(90, 90, 100), Enum.Material.Slate)
	local glow = part(folder, "Portal", Vector3.new(10, 11, 0.5), portalBase * CFrame.new(0, 6.5, 0), Color3.fromRGB(110, 200, 255), Enum.Material.Neon)
	glow.Transparency = 0.35
	glow.CanCollide = false
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Go home"
	prompt.ObjectText = "Portal to World 1"
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = glow
	prompt.Triggered:Connect(function(player)
		World2Service.Travel(player, 1)
	end)

	-- soft orange light over the town
	local lamp = part(folder, "TownLight", Vector3.new(1, 1, 1), CFrame.new(TOWN + Vector3.new(0, 20, 0)), Color3.new(1, 1, 1))
	lamp.Transparency = 1
	lamp.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 160, 90)
	light.Range = 60
	light.Brightness = 1.2
	light.Parent = lamp

	folder.Parent = workspace
end

-- Moves a player between the worlds. world = 1 (home, at your plot) or 2 (World 2 town).
function World2Service.Travel(player, world)
	local profile = DataService.Get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not profile or not humanoid or humanoid.Health <= 0 then
		return false
	end
	if DungeonService.IsCarrying(player) then
		notify(player, "Bring the egg to town first!")
		return false
	end
	if world == 2 then
		if not profile.world2Unlocked then
			notify(player, "Unlock World 2 at the World Gate first.")
			return false
		end
		player:SetAttribute("World", 2)
		character:PivotTo(World2Service.SpawnCFrame())
		notify(player, "Welcome to the Ember Wastes! Dungeons 10 to 18 are south of here.")
	else
		player:SetAttribute("World", 1)
		PlotService.TeleportToPlot(player)
		notify(player, "Back home.")
	end
	return true
end

function World2Service.Init(dataService, dungeonService, plotService, notifyFunction)
	DataService = dataService
	DungeonService = dungeonService
	PlotService = plotService
	notify = notifyFunction or notify
	build()
	Players.PlayerAdded:Connect(function(player)
		player:SetAttribute("World", 1)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		player:SetAttribute("World", player:GetAttribute("World") or 1)
	end
end

return World2Service
