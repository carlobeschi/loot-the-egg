--[[ DungeonService  (ModuleScript, put it in ServerScriptService)
  Starter code for the dungeon loop: enemies, boss defeated -> egg appears -> taking it wakes every enemy ->
  carry it back to the town to bank it.

  Your map needs:
    - a Part named "TownZone" in Workspace (invisible, CanCollide off) covering the safe town area
    - a ServerStorage Folder "Enemies" with Models named Zombie, Runner, Tank, Boss. Each Model needs a Humanoid
      and a HumanoidRootPart (R6 or R15 rigs both work)
  How you build the dungeon towers is up to you. Build them in Studio, or generate them with a script like the
  JavaScript game does (floors 150 studs tall in the JS units, stairs, rooms, torches).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Data = Config.Data

local DungeonService = {}
local DataService, PetService
local carrying = {} -- [Player] = rarity of the egg they are carrying

function DungeonService.Init(dataService, petService)
	DataService = dataService
	PetService = petService

	local town = workspace:FindFirstChild("TownZone")
	if town then
		town.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if player and carrying[player] then
				DungeonService.BankEgg(player)
			end
		end)
	else
		warn("[DungeonService] no part named TownZone in Workspace")
	end

	Players.PlayerRemoving:Connect(function(player)
		carrying[player] = nil
	end)
end

-- ---------- enemies ----------
local function nearestPlayerRoot(position, maxDistance)
	local best, bestDistance = nil, maxDistance
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 then
			local d = (root.Position - position).Magnitude
			if d < bestDistance then
				best, bestDistance = root, d
			end
		end
	end
	return best
end

local KIND_TEMPLATE = { normal = "Zombie", runner = "Runner", tank = "Tank", boss = "Boss" }
local BASE_WALK_SPEED = 14

-- kind = "normal" | "runner" | "tank" | "boss". onBossDefeated(position) is called when a boss dies.
function DungeonService.SpawnEnemy(cframe, depth, floorIndex, kind, world, parent, onBossDefeated)
	local folder = ServerStorage:FindFirstChild("Enemies")
	local template = folder and folder:FindFirstChild(KIND_TEMPLATE[kind])
	if not template then
		warn("[DungeonService] missing enemy template for " .. kind)
		return nil
	end
	local stats = Config.enemyStats(depth, floorIndex, kind, world)
	local enemy = template:Clone()
	local humanoid = enemy:FindFirstChildOfClass("Humanoid")
	local root = enemy:FindFirstChild("HumanoidRootPart")
	humanoid.MaxHealth = stats.health
	humanoid.Health = stats.health
	humanoid.WalkSpeed = BASE_WALK_SPEED * stats.speedFactor
	enemy:SetAttribute("Damage", stats.damage)
	enemy:SetAttribute("Armor", stats.armor) -- weapon scripts: damage dealt = base * Armor
	enemy:SetAttribute("Kind", kind)
	enemy:SetAttribute("Depth", depth)
	enemy:SetAttribute("Awake", false)
	enemy:PivotTo(cframe)
	enemy.Parent = parent or workspace
	CollectionService:AddTag(enemy, "Enemy")

	-- chase loop: sleeps until a player gets close (or until an egg is taken and everything wakes up)
	task.spawn(function()
		while enemy.Parent and humanoid.Health > 0 do
			local woke = enemy:GetAttribute("Awake") or workspace:GetAttribute("Aggro")
			local target = nearestPlayerRoot(root.Position, woke and math.huge or 55)
			if target then
				enemy:SetAttribute("Awake", true)
				humanoid:MoveTo(target.Position) -- swap for PathfindingService when you add walls and stairs
			end
			task.wait(0.3)
		end
	end)

	-- hurt players on touch, once per second per enemy
	local lastHit = 0
	root.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		local targetHumanoid = hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")
		if player and targetHumanoid and os.clock() - lastHit > 1 and enemy:GetAttribute("Awake") then
			lastHit = os.clock()
			targetHumanoid:TakeDamage(enemy:GetAttribute("Damage"))
		end
	end)

	humanoid.Died:Connect(function()
		if kind == "boss" and onBossDefeated then
			onBossDefeated(root.Position)
		end
		task.wait(3)
		enemy:Destroy()
	end)
	return enemy
end

-- ---------- boss defeated -> progress -> egg ----------
-- player = whoever dealt the killing blow (your weapon script can set a "LastHitBy" attribute on enemies).
function DungeonService.OnBossDefeated(player, depth, world, position)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	if world == 2 then
		profile.bestDepth2 = math.max(profile.bestDepth2, depth - 9)
	else
		profile.bestDepth = math.max(profile.bestDepth, depth)
	end
	-- Unlocking the next dungeon: your map script can compare each dungeon's Depth attribute with
	-- profile.bestDepth (World 1) or profile.bestDepth2 + 9 (World 2) and open its gate.
	local rarity = Config.rollEgg(depth)
	DungeonService.SpawnEgg(position, rarity)
	return rarity
end

function DungeonService.SpawnEgg(position, rarity)
	local egg = Instance.new("Part")
	egg.Name = "Egg"
	egg.Shape = Enum.PartType.Ball
	egg.Size = Vector3.new(3, 4, 3)
	egg.Color = Color3.fromHex(Data.rarityColors[rarity])
	egg.Material = Enum.Material.Neon
	egg.Anchored = true
	egg.CanCollide = false
	egg.Position = position + Vector3.new(0, 3, 0)
	egg.Parent = workspace

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Take the " .. Data.rarities[rarity] .. " egg"
	prompt.ObjectText = "Careful: everything will wake up!"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 10
	prompt.Parent = egg
	prompt.Triggered:Connect(function(player)
		carrying[player] = rarity
		player:SetAttribute("CarryingEgg", rarity)
		workspace:SetAttribute("Aggro", true) -- wakes every enemy and speeds them up (see Config.AggroSpeedBoost)
		for _, enemy in ipairs(CollectionService:GetTagged("Enemy")) do
			local humanoid = enemy:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.WalkSpeed *= Config.AggroSpeedBoost
			end
		end
		egg:Destroy()
	end)
	return egg
end

-- Reaching the town with the egg banks it. If the player dies on the way, the egg is lost.
function DungeonService.BankEgg(player)
	local rarity = carrying[player]
	if not rarity then
		return
	end
	PetService.BankEgg(player, rarity)
	carrying[player] = nil
	player:SetAttribute("CarryingEgg", nil)
	if next(carrying) == nil then
		workspace:SetAttribute("Aggro", false) -- calm everything down when nobody is carrying an egg
	end
end

function DungeonService.DropEgg(player) -- call this when a carrier's character dies
	carrying[player] = nil
	player:SetAttribute("CarryingEgg", nil)
end

return DungeonService
