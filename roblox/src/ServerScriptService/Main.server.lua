--[[ Main  (Script, put it in ServerScriptService next to the ModuleScripts)
  Starts everything, creates the RemoteEvents the client uses, and runs the once-a-second pet income loop.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
require(ReplicatedStorage.Config:WaitForChild("Sounds")).Group("Effects") -- every sound effect plays through this group
local DataService = require(ServerScriptService:WaitForChild("DataService"))
local PlotService = require(ServerScriptService:WaitForChild("PlotService"))
local PetService = require(ServerScriptService:WaitForChild("PetService"))
local DungeonService = require(ServerScriptService:WaitForChild("DungeonService"))
local CombatService = require(ServerScriptService:WaitForChild("CombatService"))
local TowerService = require(ServerScriptService:WaitForChild("TowerService"))
local EggService = require(ServerScriptService:WaitForChild("EggService"))
local ShopService = require(ServerScriptService:WaitForChild("ShopService"))
local World2Service = require(ServerScriptService:WaitForChild("World2Service"))

-- ---------- remotes (made first, so the client never waits on a service that is still starting) ----------
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local function makeRemote(name)
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end
local R = {
	Hatch = makeRemote("Hatch"),
	EquipBest = makeRemote("EquipBest"),
	SellWeakest = makeRemote("SellWeakest"),
	UpgradePen = makeRemote("UpgradePen"),
	Rebirth = makeRemote("Rebirth"),
	UnlockWorld2 = makeRemote("UnlockWorld2"),
	Collect = makeRemote("Collect"),
	SetShowPets = makeRemote("SetShowPets"),
	SetSoundOn = makeRemote("SetSoundOn"), -- client -> server: true | false (music and sounds, from Settings)
	PlaceEgg = makeRemote("PlaceEgg"),
	BuyWeapon = makeRemote("BuyWeapon"), -- client -> server: class name
	BuyUpgrade = makeRemote("BuyUpgrade"), -- client -> server: "health" | "speed" | "ability"
	OpenWindow = makeRemote("OpenWindow"), -- server -> client: "Weapons" | "Upgrades" | "WorldGate" | "Pen" -- client -> server: (rarity, spot clicked in the pen)
	Attack = makeRemote("Attack"),
	Ability = makeRemote("Ability"), -- client -> server: "I used my ability, aiming this way" -- client -> server: "I attacked, aiming this way"
	ChooseClass = makeRemote("ChooseClass"), -- client -> server: "Knight" | "Wizard" | "Bowman" (only once, at the start)
	Travel = makeRemote("Travel"), -- client -> server: 1 (home) or 2 (World 2), from the World Gate window
	State = makeRemote("State"), -- server -> client: your numbers for the HUD
	Notice = makeRemote("Notice"), -- server -> client: a message to show
}
remotes.Parent = ReplicatedStorage -- parent last, so the client sees every remote at once

local function notice(player, text)
	if player and text then
		R.Notice:FireClient(player, text)
	end
end

DataService.Init()
PlotService.Init()
PetService.Init(DataService, PlotService)
DungeonService.Init(DataService, PetService, notice)
CombatService.Init(DataService, DungeonService)
TowerService.Init(DungeonService, DataService, notice)
EggService.Init(DataService, PlotService, PetService, notice)
ShopService.Init(DataService, PlotService, CombatService, R.OpenWindow, notice)
World2Service.Init(DataService, DungeonService, PlotService, notice)

-- Basic anti-spam: each player can use each action at most once per `gap` seconds.
local lastUse = {}
local function allowed(player, key, gap)
	lastUse[player] = lastUse[player] or {}
	local now = os.clock()
	if now - (lastUse[player][key] or 0) < gap then
		return false
	end
	lastUse[player][key] = now
	return true
end

local function result(player, ok, message)
	if message then
		notice(player, message)
	elseif ok then
		notice(player, "Done!")
	end
end

R.Hatch.OnServerEvent:Connect(function(player)
	if not allowed(player, "Hatch", 1.2) then return end
	local pet, message = PetService.Hatch(player)
	if pet then
		local def = Config.Data.pets[pet.rarity][pet.kind]
		notice(player, "Hatched a " .. Config.Data.rarities[pet.rarity] .. " " .. def.name .. "!")
	else
		notice(player, message)
	end
end)
R.EquipBest.OnServerEvent:Connect(function(player)
	if allowed(player, "EquipBest", 1) then
		PetService.EquipBest(player)
		notice(player, "Equipped your best pets!")
	end
end)
R.SellWeakest.OnServerEvent:Connect(function(player)
	if not allowed(player, "Sell", 1) then return end
	local value, message = PetService.SellWeakest(player)
	notice(player, value and ("Sold your weakest pet for " .. value .. " coins.") or message)
end)
R.UpgradePen.OnServerEvent:Connect(function(player)
	if allowed(player, "UpgradePen", 1) then
		local ok, message = PetService.UpgradePen(player)
		local profile = DataService.Get(player)
		result(player, ok, ok and profile and ("Your pen is now " .. Config.Data.pen.names[profile.penLevel + 1] .. "!") or message)
	end
end)
R.Rebirth.OnServerEvent:Connect(function(player)
	if allowed(player, "Rebirth", 1) then
		local ok, message = PetService.Rebirth(player)
		result(player, ok, ok and "REBIRTH! Your pets earn more coins now." or message)
	end
end)
R.UnlockWorld2.OnServerEvent:Connect(function(player)
	if allowed(player, "World2", 1) then
		local ok, message = PetService.UnlockWorld2(player)
		result(player, ok, ok and "World 2 unlocked!" or message)
	end
end)
R.Collect.OnServerEvent:Connect(function(player)
	if allowed(player, "Collect", 0.5) then
		local n = PetService.Collect(player)
		if n > 0 then notice(player, "Collected " .. n .. " coins!") end
	end
end)
R.BuyWeapon.OnServerEvent:Connect(function(player, className)
	if allowed(player, "Buy", 0.3) and type(className) == "string" then
		ShopService.BuyWeapon(player, className)
	end
end)
R.BuyUpgrade.OnServerEvent:Connect(function(player, kind)
	if allowed(player, "Buy", 0.3) and type(kind) == "string" then
		ShopService.BuyUpgrade(player, kind)
	end
end)
R.PlaceEgg.OnServerEvent:Connect(function(player, rarity, position)
	if allowed(player, "PlaceEgg", 0.4) then
		EggService.Place(player, rarity, position)
	end
end)
R.Attack.OnServerEvent:Connect(function(player, aim)
	CombatService.Attack(player, aim) -- CombatService checks the cooldown itself
end)
R.Ability.OnServerEvent:Connect(function(player, aim)
	CombatService.Ability(player, aim) -- checks its own cooldown
end)
R.ChooseClass.OnServerEvent:Connect(function(player, className)
	if allowed(player, "ChooseClass", 1) and type(className) == "string" and CombatService.SetClass(player, className) then
		notice(player, "You are now a " .. className .. "!")
	end
end)
R.Travel.OnServerEvent:Connect(function(player, world)
	if allowed(player, "Travel", 2) and (world == 1 or world == 2) then
		World2Service.Travel(player, world)
	end
end)
R.SetShowPets.OnServerEvent:Connect(function(player, value)
	local profile = DataService.Get(player)
	if profile and type(value) == "boolean" then
		profile.showPets = value
	end
end)
R.SetSoundOn.OnServerEvent:Connect(function(player, value)
	local profile = DataService.Get(player)
	if profile and type(value) == "boolean" then
		profile.soundOn = value
	end
end)

-- ---------- players joining / leaving ----------
local function onJoin(player)
	local profile = DataService.Load(player)
	if not profile or not player.Parent then
		return -- left while loading
	end
	local plot = PlotService.Assign(player)
	if plot then
		PlotService.ApplyPenStyle(player, profile.penLevel)
		PlotService.RefreshPets(player, profile)
		EggService.SpawnAllPlaced(player)
		local pad = plot:FindFirstChild("CollectPad")
		if pad then
			pad.Touched:Connect(function(hit)
				if Players:GetPlayerFromCharacter(hit.Parent) == player and allowed(player, "Pad", 1) then
					local n = PetService.Collect(player)
					if n > 0 then
						notice(player, "Collected " .. n .. " coins!")
					end
				end
			end)
		end
	else
		notice(player, "This server has no free plot for you.")
	end
	local function onCharacter(character)
		character:WaitForChild("Humanoid", 10)
		task.wait(0.5)
		if player:GetAttribute("World") == 2 then
			character:PivotTo(World2Service.SpawnCFrame()) -- died in World 2: back to the World 2 town
		else
			PlotService.TeleportToPlot(player)
		end
		CombatService.Equip(player)
		EggService.SyncTools(player)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

Players.PlayerAdded:Connect(onJoin)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onJoin, player)
end
Players.PlayerRemoving:Connect(function(player)
	PlotService.Release(player)
	lastUse[player] = nil
end)

-- ---------- Studio-only test cheats (see studio-tools/TestCheats.lua) ----------
-- The Command Bar can't reach this script's data directly, so it calls this BindableFunction instead.
if RunService:IsStudio() then
	local function runCheat(command, value)
		local player = Players:GetPlayers()[1]
		local profile = player and DataService.Get(player)
		if not profile then
			return "no player yet"
		end
		if command == "coins" then
			profile.coins += value or 1000000
		elseif command == "eggs" then
			for rarity = 1, 8 do
				profile.eggs[rarity] += value or 2
			end
			PetService.EggsChanged(player)
		elseif command == "pen" then
			profile.penLevel = math.clamp(value or 7, 0, Config.MaxPenLevel)
			PlotService.ApplyPenStyle(player, profile.penLevel)
		elseif command == "rebirths" then
			profile.rebirths = math.clamp(value or 5, 0, Config.MaxRebirths)
		elseif command == "weapon" then
			profile.weaponTier[profile.class] = math.clamp(value or 5, 0, 11)
			CombatService.Equip(player)
		elseif command == "class" then
			CombatService.SetClass(player, value, true) -- test cheat: change class even after picking
		elseif command == "boss" then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root then
				DungeonService.SpawnEnemy(root.CFrame * CFrame.new(0, 4, -25), value or 1, 0, "boss", 1, workspace, nil, true)
			end
		elseif command == "depth" then
			profile.bestDepth = math.clamp(value or 9, 0, 9) -- pretend you beat dungeons 1..value
		elseif command == "world2" then
			profile.world2Unlocked = true -- skip the World Gate requirements
		elseif command == "depth2" then
			profile.bestDepth2 = math.clamp(value or 9, 0, 9) -- World 2: 1 = Dungeon 10 beaten
		elseif command == "kill" then
			-- defeat every enemy in Dungeon <value> as if you hit them (the boss drops its egg as usual)
			local tower = workspace:FindFirstChild("Towers") and workspace.Towers:FindFirstChild("Tower" .. tostring(value))
			if not tower then
				return "no Tower" .. tostring(value)
			end
			for _, enemy in ipairs(tower.Enemies:GetChildren()) do
				DungeonService.DamageEnemy(enemy, 1e9, player)
			end
		elseif command == "zoo" then
			-- show one of every pet in your pen (only on screen: your saved pets don't change; re-equip to undo)
			local all = {}
			for rarity, kinds in ipairs(Config.Data.pets) do
				for kind in ipairs(kinds) do
					table.insert(all, { rarity = rarity, kind = kind })
				end
			end
			PlotService.RefreshPets(player, { pets = all })
		elseif command == "reset" then
			-- empty Dungeon <value> so the next visit fills it again
			local tower = workspace:FindFirstChild("Towers") and workspace.Towers:FindFirstChild("Tower" .. tostring(value))
			if not tower then
				return "no Tower" .. tostring(value)
			end
			TowerService.Reset(tower)
		elseif command == "die" then
			-- your character dies on the server (to test what happens when you die)
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.Health = 0
			end
		elseif command == "travel" then
			World2Service.Travel(player, value or 2)
		elseif command == "profile" then
			return profile
		else
			return "unknown command " .. tostring(command)
		end
		return "ok"
	end
	local cheat = Instance.new("BindableFunction")
	cheat.Name = "Cheat"
	cheat.OnInvoke = runCheat
	cheat.Parent = ServerStorage
	-- The same cheats from the CLIENT Command Bar: game.ReplicatedStorage.StudioCheat:InvokeServer("coins", 1000)
	-- (handy when the Server view is slow to switch). Made in Studio only, like the one above.
	local studioCheat = Instance.new("RemoteFunction")
	studioCheat.Name = "StudioCheat"
	studioCheat.OnServerInvoke = function(_player, command, value)
		local result = runCheat(command, value)
		return type(result) == "table" and "profile is only readable from the Server view" or result
	end
	studioCheat.Parent = ReplicatedStorage
end

-- ---------- income loop and HUD updates ----------
while true do
	task.wait(1)
	for _, player in ipairs(Players:GetPlayers()) do
		local profile = DataService.Get(player)
		if profile then
			PetService.Tick(player, 1)
			R.State:FireClient(player, {
				coins = profile.coins,
				cash = math.floor(profile.cash),
				income = PetService.IncomePerSecond(profile),
				rebirths = profile.rebirths,
				multiplier = Config.multiplier(profile.rebirths),
				penLevel = profile.penLevel,
				pets = #profile.pets,
				stored = #profile.stash,
				capacity = Config.penCapacity(profile.penLevel),
				world2 = profile.world2Unlocked,
				showPets = profile.showPets,
				soundOn = profile.soundOn,
				class = profile.class,
				classChosen = profile.classChosen,
				weapon = Config.weaponInfo(profile.class, profile.weaponTier[profile.class] or 0).name,
				eggs = profile.eggs,
				carrying = player:GetAttribute("CarryingEgg"),
				weaponTier = profile.weaponTier,
				maxWeaponTier = Config.maxWeaponTier(profile.world2Unlocked),
				upgrades = profile.upgrades[profile.class],
				bestPet = PetService.BestRarity(profile),
				bestDepth = profile.bestDepth,
				bestDepth2 = profile.bestDepth2,
			})
		end
	end
end
