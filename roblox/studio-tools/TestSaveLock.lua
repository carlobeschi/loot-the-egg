--[[ TestSaveLock  (NOT a game script - for testing only)
  Checks DataService's session lock without real DataStores (it uses a fake store in memory).
  How to use: in Studio, NOT in Play mode, paste this whole file into View > Command Bar and press Enter.
  It pretends to be two servers, A and B, and prints PASS or FAIL for each step.
]]
local module = game:GetService("ServerScriptService"):WaitForChild("DataService")

local function copy(t)
	if type(t) ~= "table" then
		return t
	end
	local c = {}
	for k, v in pairs(t) do
		c[k] = copy(v)
	end
	return c
end
local saved = {}
local fakeStore = {}
function fakeStore:UpdateAsync(key, transform)
	local result = transform(copy(saved[key]))
	if result ~= nil then
		saved[key] = copy(result)
	end
	return result
end

local A = require(module:Clone()) -- two copies of DataService = two servers
local B = require(module:Clone())
A._testSetup(fakeStore, "A", 0)
B._testSetup(fakeStore, "B", 0)
local player = { UserId = 1, Name = "Tester", Parent = workspace }
local key = "player_1"

local function check(name, ok)
	print((ok and "PASS " or "FAIL ") .. name)
end

local a = A.Load(player)
check("new player gets a fresh save, locked by A", a.coins == 0 and saved[key].lock.server == "A")
a.coins = 5
A.Save(player)
check("A saves", saved[key].data.coins == 5)

local b = B.Load(player) -- A still holds it: B waits, then takes it over
check("B takes over after waiting", b.coins == 5 and saved[key].lock.server == "B")
a.coins = 99
A.Save(player)
check("A can't overwrite after B took over", saved[key].data.coins == 5 and a._noSave == true)

b.coins = 7
B.Save(player, true)
check("B leaving saves and lets go", saved[key].data.coins == 7 and saved[key].lock == nil)

local a2 = require(module:Clone())
a2._testSetup(fakeStore, "A", 0)
local loaded = a2.Load(player)
check("A opens it again at once", loaded.coins == 7 and saved[key].lock.server == "A")

saved[key] = { coins = 42, eggs = { 1, 0, 0, 0, 0, 0, 0, 0 } } -- a save from before the lock existed
local b2 = require(module:Clone())
b2._testSetup(fakeStore, "B", 0)
local old = b2.Load(player)
check("an old-style save still loads", old.coins == 42 and old.eggs[1] == 1 and saved[key].data.coins == 42)

saved[key].lock = { server = "C", time = os.time() - 1000 } -- server C crashed long ago
local a3 = require(module:Clone())
a3._testSetup(fakeStore, "A", 30) -- a 30 s wait per try would make this test hang if it waited
local t0 = os.clock()
a3.Load(player)
check("a lock from a crashed server is taken over without waiting", os.clock() - t0 < 2 and saved[key].lock.server == "A")
