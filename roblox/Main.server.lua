--[[ Main  (Script, put it in ServerScriptService next to the ModuleScripts)
  Starts everything, creates the RemoteEvents the client uses, and runs the once-a-second pet income loop.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local DataService = require(ServerScriptService:WaitForChild("DataService"))
local PlotService = require(ServerScriptService:WaitForChild("PlotService"))
local PetService = require(ServerScriptService:WaitForChild("PetService"))
local DungeonService = require(ServerScriptService:WaitForChild("DungeonService"))

DataService.Init()
PlotService.Init()
PetService.Init(DataService, PlotService)
DungeonService.Init(DataService, PetService)

-- ---------- remotes ----------
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage
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
	State = makeRemote("State"), -- server -> client: your numbers for the HUD
	Notice = makeRemote("Notice"), -- server -> client: a message to show
}

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

local function notice(player, text)
	R.Notice:FireClient(player, text)
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
		result(player, PetService.UpgradePen(player))
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
R.SetShowPets.OnServerEvent:Connect(function(player, value)
	local profile = DataService.Get(player)
	if profile and type(value) == "boolean" then
		profile.showPets = value
	end
end)

-- ---------- players joining / leaving ----------
local function onJoin(player)
	local profile = DataService.Load(player)
	local plot = PlotService.Assign(player)
	if plot then
		PlotService.ApplyPenStyle(player, profile.penLevel)
		PlotService.RefreshPets(player, profile)
		local pad = plot:FindFirstChild("CollectPad")
		if pad then
			pad.Touched:Connect(function(hit)
				if Players:GetPlayerFromCharacter(hit.Parent) == player then
					PetService.Collect(player)
				end
			end)
		end
	end
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		PlotService.TeleportToPlot(player)
	end)
	if player.Character then
		PlotService.TeleportToPlot(player)
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
			})
		end
	end
end
