--[[ DataService  (ModuleScript, put it in ServerScriptService)
  Loads and saves each player's progress with DataStores.
  Studio: turn on Game Settings > Security > "Enable Studio Access to API Services" to test saving.

  Session lock: a player's save says which server has it open ("lock"). Only that server may write it, so when
  someone hops servers, the old server's late save can't overwrite the new progress. Joining waits a little for
  the old server to let go, and takes the save over if that server seems gone (crashed) or never lets go.
  The save looks like { data = <progress>, lock = { server = <JobId>, time = os.time() } }. Old saves that are
  just the progress table still load.
]]
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

-- Studio has no JobId, so each Studio run gets its own name
local SERVER_ID = game.JobId ~= "" and game.JobId or ("studio-" .. HttpService:GenerateGUID(false))
local LOCK_TIMEOUT = 300 -- a lock not refreshed for this long belongs to a server that is gone (autosave is every 60 s)
local LOAD_TRIES = 5 -- how often to wait for another server to let go before taking the save over
local LOAD_WAIT = 6 -- seconds between those tries

-- GetDataStore errors in a place that was never published. Then the game still runs, it just doesn't save.
local okStore, store = pcall(function()
	return DataStoreService:GetDataStore("LootTheEgg_v1")
end)
if not okStore then
	warn("[DataService] saving is off: " .. tostring(store) .. " (publish the place and enable Studio Access to API Services)")
	store = nil
end

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
		placedEggs = {}, -- eggs sitting in your pen: { rarity = 1..8, x = .., z = .. (spot in the pen), hatchAt = os.time() }
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

-- a save from before the session lock is just the progress table
local function readRecord(record)
	if type(record) ~= "table" then
		return nil, nil
	end
	if type(record.data) == "table" then
		return record.data, record.lock
	end
	return record, nil
end

local function lockedByOther(lock, now)
	return type(lock) == "table" and lock.server ~= SERVER_ID and now - (lock.time or 0) < LOCK_TIMEOUT
end

-- Reads the save and marks it as open on this server. Returns ok, progress table (or nil for a new player).
local function openSave(player, force)
	local progress, busy
	local ok, err = pcall(function()
		store:UpdateAsync(keyFor(player), function(record)
			local data, lock = readRecord(record)
			if not force and lockedByOther(lock, os.time()) then
				busy = true
				return nil -- leave it alone, another server still has it open
			end
			busy = false
			progress = data
			return { data = data or defaults(), lock = { server = SERVER_ID, time = os.time() } }, { player.UserId }
		end)
	end)
	if not ok then
		return false, err
	end
	return true, progress, busy
end

function DataService.Load(player)
	if not store then
		local data = defaults()
		data._noSave = true
		profiles[player] = data
		return data
	end
	local ok, result, busy
	for try = 1, LOAD_TRIES + 1 do
		ok, result, busy = openSave(player, try > LOAD_TRIES)
		if not ok or not busy or not player.Parent then
			break
		end
		task.wait(LOAD_WAIT) -- the server they came from is probably still saving
	end
	if not player.Parent then
		if ok then -- the player left while we were loading: let go of the save again
			pcall(function()
				store:UpdateAsync(keyFor(player), function(record)
					local data, lock = readRecord(record)
					if type(lock) == "table" and lock.server == SERVER_ID then
						return { data = data }, { player.UserId }
					end
					return nil
				end)
			end)
		end
		return nil
	end
	local data
	if ok and type(result) == "table" then
		data = reconcile(result, defaults())
	elseif ok then
		data = defaults() -- a new player
	else
		data = defaults()
		warn("[DataService] could not load " .. player.Name .. ": " .. tostring(result))
		data._noSave = true -- never overwrite a real save after a failed load
	end
	profiles[player] = data
	return data
end

-- leaving = true also lets go of the lock, so the next server can open the save straight away
function DataService.Save(player, leaving)
	local data = profiles[player]
	if not data or data._noSave or not store then
		return
	end
	leaving = leaving or player.Parent == nil -- an autosave that runs as they leave must not lock it again
	data.lastSave = os.time()
	local takenOver = false
	local ok, err = pcall(function()
		store:UpdateAsync(keyFor(player), function(record)
			local _, lock = readRecord(record)
			if type(lock) ~= "table" or lock.server ~= SERVER_ID then
				-- No lock: we already let go of it (a second save while leaving). Someone else's lock: another
				-- server took this save over. Either way, never write over it.
				takenOver = type(lock) == "table"
				return nil
			end
			local newLock = (not leaving) and { server = SERVER_ID, time = os.time() } or nil
			return { data = data, lock = newLock }, { player.UserId }
		end)
	end)
	if not ok then
		warn("[DataService] could not save " .. player.Name .. ": " .. tostring(err))
	elseif takenOver then
		warn("[DataService] " .. player.Name .. "'s save is open on another server now, so this server stops saving it")
		data._noSave = true
	end
end

-- For studio-tools/TestSaveLock.lua only: use a fake store and pretend to be server serverId.
function DataService._testSetup(fakeStore, serverId, loadWait)
	store = fakeStore
	SERVER_ID = serverId
	LOAD_WAIT = loadWait
	profiles = {}
end

function DataService.Get(player)
	return profiles[player]
end

function DataService.Init()
	Players.PlayerRemoving:Connect(function(player)
		DataService.Save(player, true)
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
		local waiting = 0
		for _, player in ipairs(Players:GetPlayers()) do
			waiting += 1
			task.spawn(function()
				DataService.Save(player, true)
				waiting -= 1
			end)
		end
		local deadline = os.clock() + 25 -- Roblox gives BindToClose about 30 seconds
		while waiting > 0 and os.clock() < deadline do
			task.wait(0.2)
		end
	end)
end

return DataService
