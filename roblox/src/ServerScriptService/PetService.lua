--[[ PetService  (ModuleScript, put it in ServerScriptService)
  Everything about eggs, pets, the pen, rebirths and the World Gate. All of it runs on the SERVER, because the
  client can never be trusted with coins or pets. The client only asks ("please hatch") through RemoteEvents.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Data = Config.Data

local PetService = {}
local DataService, PlotService

function PetService.Init(dataService, plotService)
	DataService = dataService
	PlotService = plotService
end

local function ownsPetOfRarity(profile, rarity)
	for _, list in ipairs({ profile.pets, profile.stash }) do
		for _, pet in ipairs(list) do
			if pet.rarity >= rarity then
				return true
			end
		end
	end
	return false
end

-- ---------- income ----------
function PetService.IncomePerSecond(profile)
	local sum = 0
	for _, pet in ipairs(profile.pets) do
		sum += Data.income[pet.rarity]
	end
	return sum * Config.multiplier(profile.rebirths)
end

function PetService.Tick(player, dt)
	local profile = DataService.Get(player)
	if profile then
		profile.cash += PetService.IncomePerSecond(profile) * dt
	end
end

-- Called when the player steps on the collect pad.
function PetService.Collect(player)
	local profile = DataService.Get(player)
	if not profile then
		return 0
	end
	local amount = math.floor(profile.cash)
	profile.coins += amount
	profile.cash -= amount
	return amount
end

-- ---------- hatching and equipping ----------
function PetService.Hatch(player)
	local profile = DataService.Get(player)
	if not profile then
		return nil, "no data"
	end
	local rarity = 0
	for i = 8, 1, -1 do
		if profile.eggs[i] > 0 then
			rarity = i
			break
		end
	end
	if rarity == 0 then
		return nil, "You have no eggs. Eggs only drop from dungeon bosses."
	end
	profile.eggs[rarity] -= 1
	PetService.EggsChanged(player)
	return PetService.AddPet(player, rarity)
end

-- Makes a new pet of this rarity (one of its two kinds at random). Used when a placed egg hatches.
-- Returns the pet, and true if it went to storage because the pen was full.
function PetService.AddPet(player, rarity)
	local profile = DataService.Get(player)
	if not profile then
		return nil
	end
	local pet = { rarity = rarity, kind = math.random(1, 2) }
	if #profile.pets < Config.penCapacity(profile.penLevel) then
		table.insert(profile.pets, pet)
		PlotService.RefreshPets(player, profile)
		return pet, false
	end
	table.insert(profile.stash, pet) -- pen is full, so it goes to storage
	return pet, true
end

function PetService.EquipBest(player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local all = {}
	for _, pet in ipairs(profile.pets) do
		table.insert(all, pet)
	end
	for _, pet in ipairs(profile.stash) do
		table.insert(all, pet)
	end
	table.sort(all, function(a, b)
		if a.rarity ~= b.rarity then
			return a.rarity > b.rarity
		end
		return a.kind > b.kind
	end)
	local capacity = Config.penCapacity(profile.penLevel)
	profile.pets, profile.stash = {}, {}
	for i, pet in ipairs(all) do
		table.insert((i <= capacity) and profile.pets or profile.stash, pet)
	end
	PlotService.RefreshPets(player, profile)
end

-- Sells the weakest pet (storage first). The client should ask the player to confirm before calling this.
function PetService.SellWeakest(player)
	local profile = DataService.Get(player)
	if not profile then
		return nil
	end
	local weakest, fromList, index
	for _, list in ipairs({ profile.stash, profile.pets }) do
		for i, pet in ipairs(list) do
			if not weakest or pet.rarity < weakest.rarity then
				weakest, fromList, index = pet, list, i
			end
		end
	end
	if not weakest then
		return nil, "You have no pets to sell."
	end
	table.remove(fromList, index)
	local value = Config.sellValue(weakest.rarity)
	profile.coins += value
	PlotService.RefreshPets(player, profile)
	return value
end

-- ---------- pen upgrades ----------
function PetService.UpgradePen(player)
	local profile = DataService.Get(player)
	if not profile then
		return false
	end
	if profile.penLevel >= Config.MaxPenLevel then
		return false, "Your pen is fully upgraded."
	end
	local cost = Config.penUpgradeCost(profile.penLevel)
	if profile.coins < cost then
		return false, "You need " .. cost .. " coins."
	end
	profile.coins -= cost
	profile.penLevel += 1
	PlotService.ApplyPenStyle(player, profile.penLevel)
	return true
end

-- ---------- rebirth (you keep all your pets) ----------
function PetService.Rebirth(player)
	local profile = DataService.Get(player)
	if not profile then
		return false
	end
	local req = Config.rebirthRequirement(profile.rebirths)
	if not req then
		return false, "You reached the maximum rebirth."
	end
	if not ownsPetOfRarity(profile, req.rarity) then
		return false, "You need a " .. Data.rarities[req.rarity] .. " pet or better."
	end
	if profile.coins < req.cost then
		return false, "You need " .. req.cost .. " coins."
	end
	profile.coins -= req.cost
	profile.rebirths += 1
	return true
end

-- ---------- World Gate ----------
function PetService.UnlockWorld2(player)
	local profile = DataService.Get(player)
	if not profile or profile.world2Unlocked then
		return false
	end
	local need = Config.World2
	if profile.rebirths < need.rebirths then
		return false, "You need " .. need.rebirths .. " rebirths."
	end
	if not ownsPetOfRarity(profile, need.petRarity) then
		return false, "You need a Mythic pet or better."
	end
	if profile.penLevel < need.penLevel then
		return false, "You need an Amethyst fence (pen level " .. need.penLevel .. ")."
	end
	if profile.coins < need.coins then
		return false, "You need " .. need.coins .. " coins."
	end
	profile.coins -= need.coins
	profile.world2Unlocked = true
	return true
end

-- ---------- eggs coming home from a dungeon ----------
-- profile.eggs is the egg inventory. EggService shows it as egg items in the backpack, so tell it about changes.
local eggListeners = {}
function PetService.OnEggsChanged(callback)
	table.insert(eggListeners, callback)
end
function PetService.EggsChanged(player)
	for _, callback in ipairs(eggListeners) do
		task.spawn(callback, player)
	end
end

function PetService.BankEgg(player, rarity)
	local profile = DataService.Get(player)
	if profile then
		profile.eggs[rarity] += 1
		PetService.EggsChanged(player)
	end
end

return PetService
