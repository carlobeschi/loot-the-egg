--[[ DataService  (ModuleScript, put it in ServerScriptService)
  Loads and saves each player's progress with DataStores.
  Studio: turn on Game Settings > Security > "Enable Studio Access to API Services" to test saving.
  For a real launch, think about a session-locking library such as ProfileService (this starter keeps it simple).
]]
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local store = DataStoreService:GetDataStore("LootTheEgg_v1")

local DataService = {}
local profiles = {} -- [Player] = data table

local function newUpgrades()
	return { health = 0, speed = 0, ability = 0 }
end

local function defaults()
	return {
		coins = 0,
		cash = 0, -- coins your pets have earned that are waiting at the collect pad
		eggs = { 0, 0, 0, 0, 0, 0, 0, 0 }, -- eggs you own, by rarity 1..8
		pets = {}, -- equipped pets in your pen: { rarity = 1..8, kind = 1 or 2 }
		stash = {}, -- pets in storage
		rebirths = 0,
		penLevel = 0,
		class = "Knight",
		weaponTier = { Knight = 0, Wizard = 0, Bowman = 0 },
		upgrades = { Knight = newUpgrades(), Wizard = newUpgrades(), Bowman = newUpgrades() },
		bestDepth = 0, -- highest World 1 dungeon beaten
		bestDepth2 = 0, -- World 2 progress (depth 10 counts as 1)
		world2Unlocked = false,
		showPets = true,
		lastSave = 0,
	}
end

-- Fill in any keys that are missing (new fields you add later) without touching existing data.
local function reconcile(data, template)
	for key, value in pairs(template) do
		if data[key] == nil then
			if type(value) == "table" then
				data[key] = reconcile({}, value)
			else
				data[key] = value
			end
		elseif type(value) == "table" and type(data[key]) == "table" and #value == 0 then
			reconcile(data[key], value)
		end
	end
	return data
end

local function keyFor(player)
	return "player_" .. player.UserId
end

function DataService.Load(player)
	local ok, result = pcall(function()
		return store:GetAsync(keyFor(player))
	end)
	local data
	if ok and type(result) == "table" then
		data = reconcile(result, defaults())
	else
		data = defaults()
		if not ok then
			warn("[DataService] could not load " .. player.Name .. ": " .. tostring(result))
			data._noSave = true -- never overwrite a real save after a failed load
		end
	end
	profiles[player] = data
	return data
end

function DataService.Save(player)
	local data = profiles[player]
	if not data or data._noSave then
		return
	end
	data.lastSave = os.time()
	local ok, err = pcall(function()
		store:SetAsync(keyFor(player), data)
	end)
	if not ok then
		warn("[DataService] could not save " .. player.Name .. ": " .. tostring(err))
	end
end

function DataService.Get(player)
	return profiles[player]
end

function DataService.Init()
	Players.PlayerRemoving:Connect(function(player)
		DataService.Save(player)
		profiles[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in ipairs(Players:GetPlayers()) do
				DataService.Save(player)
			end
		end
	end)

	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do
			DataService.Save(player)
		end
		task.wait(2)
	end)
end

return DataService
