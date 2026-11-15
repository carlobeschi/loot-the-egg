--[[ TestCheats  (NOT a game script - for testing only. Never put this in the published game)
  How to use: start a playtest (Test tab > Play), then in the Test tab switch to SERVER view (the Client/Server
  toggle button). Open View > Command Bar and paste ONE of the snippets below.
  They change the server's copy of your data, and the HUD updates within a second.
]]

-- ===== A) lots of coins, eggs, and a high pen level =====
local SSS = game:GetService("ServerScriptService")
local DataService = require(SSS.DataService)
local PlotService = require(SSS.PlotService)
local player = game.Players:GetPlayers()[1]
local profile = DataService.Get(player)
profile.coins += 50000000
for rarity = 1, 8 do
	profile.eggs[rarity] += 2 -- two eggs of every rarity to hatch
end
profile.penLevel = 7
PlotService.ApplyPenStyle(player, profile.penLevel)
print("Gave coins, eggs and pen level 7 to " .. player.Name)

-- ===== B) check the rebirth and World Gate rules fast (paste after A) =====
-- local PetService = require(game.ServerScriptService.PetService)
-- profile.pets = { { rarity = 6, kind = 1 } }
-- profile.rebirths = 5
-- print("Rebirth:", PetService.Rebirth(player))
-- print("World 2:", PetService.UnlockWorld2(player))
-- print("world2Unlocked =", profile.world2Unlocked)

-- ===== C) see the egg odds the game uses (works in any context) =====
-- local Config = require(game.ReplicatedStorage.Config)
-- for _, depth in ipairs({ 1, 9, 18 }) do
--     local w, total = Config.eggWeights(depth), 0
--     for _, x in ipairs(w) do total += x end
--     local out = {}
--     for i, x in ipairs(w) do out[i] = string.format("%s %.1f%%", Config.Data.rarities[i], x / total * 100) end
--     print("Depth " .. depth .. ": " .. table.concat(out, ", "))
-- end

-- ===== D) spawn a test boss near you, to try the egg + aggro + banking loop =====
-- local DungeonService = require(game.ServerScriptService.DungeonService)
-- local root = player.Character.HumanoidRootPart
-- DungeonService.SpawnEnemy(root.CFrame * CFrame.new(0, 0, -25), 3, 1, "boss", 1, workspace, function(position)
--     DungeonService.OnBossDefeated(player, 3, 1, position)
-- end)
