--[[ DungeonService  (ModuleScript, put it in ServerScriptService)
  The dungeon loop: enemies sleep until you come close, the boss slams, summons help and enrages, the boss drops
  an egg, taking the egg wakes every enemy, and carrying it back to the town banks it. Dying with the egg loses it.

  Your map needs:
    - a Part named "TownZone" in Workspace (invisible, CanCollide off) covering the safe town area
    - a ServerStorage Folder "Enemies" with Models named Zombie, Runner, Tank, Boss. Each Model needs a Humanoid
      and a HumanoidRootPart (R6 or R15 rigs both work). studio-tools/SetupTestPlace.lua makes these.
  TowerService builds a test tower and calls SpawnEnemy for each floor.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Data = Config.Data

local DungeonService = {}
local DataService, PetService
local carrying = {} -- [Player] = rarity of the egg they are carrying
local notify = function(_player, _text) end -- set by Main so we can show messages

-- JS enemy speeds are in "per frame" units where the player walks at about 2.5. Roblox players walk at 16.
local SPEED_TO_WALKSPEED = 16 / 2.5
local PLAYER_HIT_COOLDOWN = 40 / 60 -- after getting hit, a player can't be hit again for this long (JS P.hit=40)

local function setAggro(on)
	if (workspace:GetAttribute("Aggro") == true) == on then
		return
	end
	workspace:SetAttribute("Aggro", on)
	-- wakes every enemy and speeds them up (Config.AggroSpeedBoost), or calms them back down
	for _, enemy in ipairs(CollectionService:GetTagged("Enemy")) do
		local humanoid = enemy:FindFirstChildOfClass("Humanoid")
		local base = enemy:GetAttribute("BaseWalkSpeed")
		if humanoid and base then
			humanoid.WalkSpeed = base * (on and Config.AggroSpeedBoost or 1)
		end
	end
end

function DungeonService.Init(dataService, petService, notifyFunction)
	DataService = dataService
	PetService = petService
	if notifyFunction then
		notify = notifyFunction
	end
	workspace:SetAttribute("Aggro", false)

	local town = workspace:FindFirstChild("TownZone")
	if town then
		town.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if player and carrying[player] then
				DungeonService.BankEgg(player)
			end
		end)
	else
		warn("[DungeonService] no part named TownZone in Workspace, so eggs can't be banked")
	end

	-- dying while carrying an egg loses it
	local function watchCharacter(player, character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid then
			humanoid.Died:Connect(function()
				if carrying[player] then
					DungeonService.DropEgg(player)
					notify(player, "You lost the egg! Beat the boss again for a new one.")
				end
			end)
		end
	end
	local function watchPlayer(player)
		player.CharacterAdded:Connect(function(character)
			watchCharacter(player, character)
		end)
		if player.Character then
			task.spawn(watchCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		watchPlayer(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		if carrying[player] then
			DungeonService.DropEgg(player)
		end
	end)
end

-- ---------- helpers ----------
local function nearestPlayerRoot(position, maxDistance, sameFloorOnly)
	local best, bestDistance = nil, maxDistance
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 then
			local offset = root.Position - position
			local onFloor = math.abs(offset.Y) < Config.FloorHeight * 0.4
			if onFloor or not sameFloorOnly then
				local d = Vector3.new(offset.X, 0, offset.Z).Magnitude
				if d < bestDistance then
					best, bestDistance = root, d
				end
			end
		end
	end
	return best
end

-- Hurts a player unless they were hit very recently. Used by touches and boss slams.
local function hurtPlayer(character, amount)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end
	local now = os.clock()
	if now < (character:GetAttribute("HitUntil") or 0) then
		return false
	end
	character:SetAttribute("HitUntil", now + PLAYER_HIT_COOLDOWN)
	humanoid:TakeDamage(amount)
	return true
end

-- A flat ring on the ground (used for the boss slam warning and the slam itself).
local function groundRing(position, radius, color, transparency, lifetime)
	local ring = Instance.new("Part")
	ring.Name = "SlamRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.3, radius * 2, radius * 2)
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = transparency
	ring.Parent = workspace
	Debris:AddItem(ring, lifetime)
	return ring
end

-- ---------- damage (called by CombatService) ----------
-- amount is already multiplied by the weapon; the enemy's Armor is applied here.
function DungeonService.DamageEnemy(enemy, amount, player)
	local humanoid = enemy:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	if player then
		enemy:SetAttribute("LastHitBy", player.UserId)
	end
	enemy:SetAttribute("Awake", true)
	humanoid:TakeDamage(amount * (enemy:GetAttribute("Armor") or 1))
end

-- ---------- enemies ----------
local KIND_TEMPLATE = { normal = "Zombie", runner = "Runner", tank = "Tank", boss = "Boss" }

local runBossAI -- defined below

-- kind = "normal" | "runner" | "tank" | "boss". Enemies start asleep (awake = true makes them chase at once).
-- onBossDefeated(player, position) is optional: by default the boss's egg goes to whoever hit it last.
function DungeonService.SpawnEnemy(cframe, depth, floorIndex, kind, world, parent, onBossDefeated, awake)
	local folder = ServerStorage:FindFirstChild("Enemies")
	local template = folder and folder:FindFirstChild(KIND_TEMPLATE[kind])
	if not template then
		warn("[DungeonService] missing enemy template ServerStorage.Enemies." .. tostring(KIND_TEMPLATE[kind]))
		return nil
	end
	local stats = Config.enemyStats(depth, floorIndex, kind, world)
	local enemy = template:Clone()
	local humanoid = enemy:FindFirstChildOfClass("Humanoid")
	local root = enemy:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		warn("[DungeonService] enemy template " .. template.Name .. " needs a Humanoid and a HumanoidRootPart")
		enemy:Destroy()
		return nil
	end
	local walkSpeed = SPEED_TO_WALKSPEED * stats.speedFactor
	humanoid.MaxHealth = stats.health
	humanoid.Health = stats.health
	humanoid.WalkSpeed = walkSpeed * (workspace:GetAttribute("Aggro") and Config.AggroSpeedBoost or 1)
	humanoid.BreakJointsOnDeath = false
	enemy:SetAttribute("BaseWalkSpeed", walkSpeed)
	enemy:SetAttribute("Damage", stats.damage)
	enemy:SetAttribute("Armor", stats.armor) -- damage taken is multiplied by this
	enemy:SetAttribute("Kind", kind)
	enemy:SetAttribute("Depth", depth)
	enemy:SetAttribute("World", world)
	enemy:SetAttribute("Awake", awake == true)
	enemy:PivotTo(cframe)
	enemy.Parent = parent or workspace
	pcall(function()
		root:SetNetworkOwner(nil) -- the server moves enemies, so players can't fling them around
	end)
	CollectionService:AddTag(enemy, "Enemy")

	-- chase loop: sleeps until a player gets close on the same floor (or an egg is taken and everything wakes up)
	task.spawn(function()
		while enemy.Parent and humanoid.Health > 0 do
			local woke = enemy:GetAttribute("Awake") or workspace:GetAttribute("Aggro")
			local target
			if woke then
				target = nearestPlayerRoot(root.Position, math.huge, false)
			else
				target = nearestPlayerRoot(root.Position, Config.WakeDistance, true)
				if target then
					enemy:SetAttribute("Awake", true)
				end
			end
			if target and not enemy:GetAttribute("Busy") then
				humanoid:MoveTo(target.Position) -- swap for PathfindingService when towers get walls and stairs
			end
			task.wait(0.3)
		end
	end)

	-- hurt players on touch
	local function onTouch(hit)
		local character = hit.Parent
		if enemy:GetAttribute("Awake") and humanoid.Health > 0 and Players:GetPlayerFromCharacter(character) then
			hurtPlayer(character, enemy:GetAttribute("Damage"))
		end
	end
	for _, part in ipairs(enemy:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Touched:Connect(onTouch)
		end
	end

	humanoid.Died:Connect(function()
		CollectionService:RemoveTag(enemy, "Enemy")
		if kind == "boss" then
			local killer = Players:GetPlayerByUserId(enemy:GetAttribute("LastHitBy") or 0)
			if onBossDefeated then
				onBossDefeated(killer, root.Position)
			elseif killer then
				DungeonService.OnBossDefeated(killer, depth, world, root.Position)
			end
		end
		task.wait(2)
		enemy:Destroy()
	end)

	if kind == "boss" then
		task.spawn(runBossAI, enemy, humanoid, root, depth, floorIndex, world, parent)
	end
	return enemy
end

-- ---------- boss moves (from bossAI() in the JS game) ----------
-- Slam: a red ring shows for a moment, then everyone on the boss's floor inside it gets hurt.
-- Summon: every so often two helpers appear next to the boss. Enrage: below half health it gets faster and stronger.
function runBossAI(boss, humanoid, root, depth, floorIndex, world, parent)
	local B = Config.Boss
	local enraged = false
	local nextSlam = os.clock() + B.slamEvery[world]
	local nextSummon = os.clock() + B.summonEvery
	local nextCharge = os.clock() + B.chargeEvery[world]
	local helpers = {}

	local function restoreSpeed()
		humanoid.WalkSpeed = boss:GetAttribute("BaseWalkSpeed") * (workspace:GetAttribute("Aggro") and Config.AggroSpeedBoost or 1)
	end

	-- the charge: telegraph with a red strip, then dash in a straight line, hurting the first time it touches you
	local function charge(target)
		local flat = Vector3.new(target.Position.X - root.Position.X, 0, target.Position.Z - root.Position.Z)
		if flat.Magnitude < 0.1 then
			return
		end
		local direction = flat.Unit
		local length = B.chargeSpeed * B.chargeTime
		boss:SetAttribute("Busy", true)
		humanoid:MoveTo(root.Position)
		local floorY = root.Position.Y - humanoid.HipHeight - root.Size.Y / 2 + 0.2
		local start = Vector3.new(root.Position.X, floorY, root.Position.Z)
		local strip = Instance.new("Part")
		strip.Name = "ChargeWarning"
		strip.Size = Vector3.new(B.chargeWidth, 0.3, length)
		strip.CFrame = CFrame.lookAt(start, start + direction) * CFrame.new(0, 0, -length / 2)
		strip.Anchored = true
		strip.CanCollide = false
		strip.CanQuery = false
		strip.CanTouch = false
		strip.Material = Enum.Material.Neon
		strip.Color = Color3.fromRGB(255, 42, 42)
		strip.Transparency = 0.5
		strip.Parent = workspace
		Debris:AddItem(strip, B.chargeWarning + 0.1)
		task.wait(B.chargeWarning)
		if humanoid.Health <= 0 then
			return
		end
		humanoid.WalkSpeed = B.chargeSpeed
		humanoid:MoveTo(root.Position + direction * length)
		local hitAlready = {}
		local stopAt = os.clock() + B.chargeTime
		while os.clock() < stopAt and humanoid.Health > 0 do
			for _, player in ipairs(Players:GetPlayers()) do
				local character = player.Character
				local proot = character and character:FindFirstChild("HumanoidRootPart")
				if proot and not hitAlready[player] then
					local offset = proot.Position - root.Position
					if Vector3.new(offset.X, 0, offset.Z).Magnitude < root.Size.X + 2 and math.abs(offset.Y) < Config.FloorHeight * 0.5 then
						hitAlready[player] = true
						if hurtPlayer(character, boss:GetAttribute("Damage") * B.chargeDamage) then
							proot.AssemblyLinearVelocity += direction * 50 + Vector3.new(0, 25, 0)
						end
					end
				end
			end
			task.wait(0.05)
		end
		restoreSpeed()
		humanoid:MoveTo(root.Position)
		boss:SetAttribute("Busy", false)
	end

	while boss.Parent and humanoid.Health > 0 do
		task.wait(0.1)
		if not boss:GetAttribute("Awake") and not workspace:GetAttribute("Aggro") then
			nextSlam = os.clock() + B.slamEvery[world]
			nextSummon = os.clock() + B.summonEvery
			continue
		end
		local now = os.clock()

		if not enraged and humanoid.Health < humanoid.MaxHealth * B.enrageAt then
			enraged = true
			boss:SetAttribute("BaseWalkSpeed", boss:GetAttribute("BaseWalkSpeed") * B.enrageSpeed)
			humanoid.WalkSpeed *= B.enrageSpeed
			boss:SetAttribute("Damage", boss:GetAttribute("Damage") * B.enrageDamage)
			for _, player in ipairs(Players:GetPlayers()) do
				notify(player, "The boss is ENRAGED!")
			end
		end

		-- only slam when a player is on the boss's floor
		local target = nearestPlayerRoot(root.Position, math.huge, true)
		if target and now >= nextSlam then
			nextSlam = now + (enraged and B.slamEveryEnraged[world] or B.slamEvery[world]) + B.slamWarning
			boss:SetAttribute("Busy", true)
			humanoid:MoveTo(root.Position) -- stand still while slamming
			local floorY = root.Position.Y - humanoid.HipHeight - root.Size.Y / 2 + 0.2
			local center = Vector3.new(root.Position.X, floorY, root.Position.Z)
			groundRing(center, B.slamRadius, Color3.fromRGB(255, 42, 42), 0.55, B.slamWarning)
			task.wait(B.slamWarning)
			if humanoid.Health > 0 then
				groundRing(center, B.slamRadius * 1.05, Color3.fromRGB(255, 90, 42), 0.2, 0.25)
				for _, player in ipairs(Players:GetPlayers()) do
					local character = player.Character
					local proot = character and character:FindFirstChild("HumanoidRootPart")
					if proot then
						local offset = proot.Position - center
						local flat = Vector3.new(offset.X, 0, offset.Z).Magnitude
						if flat < B.slamRadius and math.abs(offset.Y) < Config.FloorHeight * 0.5 then
							if hurtPlayer(character, boss:GetAttribute("Damage") * B.slamDamage) and flat > 0.1 then
								-- knock the player away from the boss
								proot.AssemblyLinearVelocity += Vector3.new(offset.X, 0, offset.Z).Unit * 40 + Vector3.new(0, 25, 0)
							end
						end
					end
				end
			end
			boss:SetAttribute("Busy", false)
		end

		if target and now >= nextCharge and not boss:GetAttribute("Busy") then
			local d = Vector3.new(target.Position.X - root.Position.X, 0, target.Position.Z - root.Position.Z).Magnitude
			if d > B.chargeMinDistance and d < B.chargeMaxDistance then
				nextCharge = now + (enraged and B.chargeEveryEnraged[world] or B.chargeEvery[world])
				charge(target)
				now = os.clock()
			end
		end

		if target and now >= nextSummon then
			nextSummon = now + (enraged and B.summonEveryEnraged or B.summonEvery)
			for i = #helpers, 1, -1 do
				if not helpers[i].Parent then
					table.remove(helpers, i)
				end
			end
			if #helpers < B.maxHelpers then
				for _ = 1, B.summonCount do
					local offset = Vector3.new(math.random(-5, 5), 0, math.random(-5, 5))
					local helper = DungeonService.SpawnEnemy(root.CFrame + offset, depth, floorIndex, "normal", world, parent, nil, true)
					if helper then
						table.insert(helpers, helper)
					end
				end
				for _, player in ipairs(Players:GetPlayers()) do
					notify(player, "The boss calls for help!")
				end
			end
		end
	end
end

-- ---------- boss defeated -> progress -> egg ----------
-- player = whoever dealt the last hit (CombatService sets the "LastHitBy" attribute on enemies).
function DungeonService.OnBossDefeated(player, depth, world, position)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local firstTime
	if world == 2 then
		firstTime = depth - 9 > profile.bestDepth2
		profile.bestDepth2 = math.max(profile.bestDepth2, depth - 9)
	else
		firstTime = depth > profile.bestDepth
		profile.bestDepth = math.max(profile.bestDepth, depth)
	end
	local rarity = Config.rollEgg(depth)
	DungeonService.SpawnEgg(position, rarity)
	local opened = (firstTime and depth ~= 9 and depth < 18) and (" Dungeon " .. (depth + 1) .. " is open now!") or ""
	notify(player, "The boss is down! Grab the " .. Data.rarities[rarity] .. " egg and run home!" .. opened)
	return rarity
end

function DungeonService.SpawnEgg(position, rarity)
	local egg = Instance.new("Part")
	egg.Name = "Egg"
	egg.Size = Vector3.new(3, 4, 3)
	egg.Color = Color3.fromHex(Data.rarityColors[rarity])
	egg.Material = Enum.Material.Neon
	egg.Anchored = true
	egg.CanCollide = false
	egg.Position = position + Vector3.new(0, 1, 0)
	local mesh = Instance.new("SpecialMesh") -- a Ball part is always round, so a mesh gives the egg shape
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = egg
	egg.Parent = workspace

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Take the " .. Data.rarities[rarity] .. " egg"
	prompt.ObjectText = "Careful: everything will wake up!"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = egg
	prompt.Triggered:Connect(function(player)
		if carrying[player] or not egg.Parent then
			return
		end
		carrying[player] = rarity
		player:SetAttribute("CarryingEgg", rarity)
		egg:Destroy()
		setAggro(true)
		notify(player, "Everything is awake! Run back to town!")
	end)
	return egg
end

-- Reaching the town with the egg banks it.
function DungeonService.BankEgg(player)
	local rarity = carrying[player]
	if not rarity then
		return
	end
	PetService.BankEgg(player, rarity)
	carrying[player] = nil
	player:SetAttribute("CarryingEgg", nil)
	notify(player, "You brought home a " .. Data.rarities[rarity] .. " egg! It's in your backpack: equip it and click inside your pen to place it.")
	if next(carrying) == nil then
		setAggro(false) -- calm everything down when nobody is carrying an egg
	end
end

function DungeonService.DropEgg(player)
	carrying[player] = nil
	player:SetAttribute("CarryingEgg", nil)
	if next(carrying) == nil then
		setAggro(false)
	end
end

function DungeonService.IsCarrying(player)
	return carrying[player] ~= nil
end

return DungeonService
