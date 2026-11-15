--[[ TestCheats  (NOT a game script - for testing only)
  How to use: start a playtest (Test tab > Play), then switch to SERVER view (the Client/Server toggle in the
  Test tab). Open View > Command Bar and paste ONE line below, then press Enter.

  Why a "Cheat" function: the Command Bar runs separately from the game's scripts, so requiring DataService
  there gives you a fresh, empty copy. Main.server.lua makes ServerStorage.Cheat (in Studio only), and calling
  it runs inside the real game. The HUD updates within a second. It never exists in the published game.
]]
local Cheat = game:GetService("ServerStorage"):WaitForChild("Cheat")

print(Cheat:Invoke("coins", 50000000)) -- add 50 million coins
-- print(Cheat:Invoke("eggs", 2))         -- two eggs of every rarity (press Hatch to hatch them)
-- print(Cheat:Invoke("pen", 7))          -- pen level 7 (Amethyst fence)
-- print(Cheat:Invoke("rebirths", 5))     -- set rebirths to 5
-- print(Cheat:Invoke("weapon", 5))       -- weapon tier 5 for your current class (0 to 11)
-- print(Cheat:Invoke("class", "Wizard")) -- switch class: "Knight", "Wizard" or "Bowman"
-- print(Cheat:Invoke("boss", 3))         -- spawn an awake depth-3 boss in front of you (it drops an egg)

-- See the egg odds the game uses (works in any view, because Config has no saved data):
-- local Config = require(game.ReplicatedStorage.Config)
-- for _, depth in ipairs({ 1, 9, 18 }) do
--     local w, total = Config.eggWeights(depth), 0
--     for _, x in ipairs(w) do total += x end
--     local out = {}
--     for i, x in ipairs(w) do out[i] = string.format("%s %.1f%%", Config.Data.rarities[i], x / total * 100) end
--     print("Depth " .. depth .. ": " .. table.concat(out, ", "))
-- end
