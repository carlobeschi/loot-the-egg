--[[ Config  (ModuleScript, put it in ReplicatedStorage and name it "Config")
  Put the generated ConfigData ModuleScript INSIDE this one (as a child named "ConfigData").
  These are the game rules copied from the JavaScript game. Rarity is 1..8 (1 = Common ... 8 = Divine).
  Weapon tiers and dungeon floors count from 0, like in the JavaScript game. Pet "kind" is 1 or 2 (the two
  pets of a rarity, in the order they appear in ConfigData.pets).
]]
local Data = require(script:WaitForChild("ConfigData"))

local Config = {}
Config.Data = Data
Config.MaxRebirths = #Data.rebirth.cost
Config.MaxPenLevel = 9
Config.World2 = { rebirths = 5, petRarity = 6, penLevel = 7, coins = 10000000 } -- petRarity 6 = Mythic
Config.AggroSpeedBoost = 1.25 -- enemies move 25% faster once someone grabs an egg

-- ---------- pets, pen, rebirth ----------
function Config.multiplier(rebirths)
	return 1 + Data.rebirth.multiplierStep * rebirths
end

function Config.penCapacity(level)
	return Data.pen.baseCapacity + Data.pen.capacityPerLevel * level
end

function Config.penUpgradeCost(level)
	return math.round(300 * 1.6 ^ level)
end

function Config.sellValue(rarity)
	return Data.income[rarity] * 30
end

-- Returns { rarity = <pet rarity you must own or better>, cost = <coins> }, or nil when fully reborn.
function Config.rebirthRequirement(rebirths)
	local i = rebirths + 1
	if i > Config.MaxRebirths then
		return nil
	end
	return { rarity = Data.rebirth.required[i], cost = Data.rebirth.cost[i] }
end

-- ---------- weapons ----------
function Config.maxWeaponTier(world2Unlocked)
	return world2Unlocked and 11 or 5
end

function Config.weaponDamage(className, tier)
	local base = (className == "Knight") and 1.6 or 1.7
	return base * (1 + 0.35 * tier)
end

function Config.weaponInfo(className, tier)
	local w = Data.weapons[className]
	return { name = w.names[tier + 1], price = w.prices[tier + 1], color = w.colors[tier + 1] }
end

-- ---------- combat ----------
-- The JS game measures in its own units. About 9 JS units = 1 stud (JS walk speed 2.5 per frame = 150 per
-- second, Roblox walk speed 16 studs per second). One tower floor (150 JS units) is about 16 studs.
Config.STUD = 1 / 9
Config.FloorHeight = 16
Config.SameFloorHeight = 5.5 -- hits only land if attacker and target are this close in height (JS: 50)

-- base = the JS hurt() damage before weapon and class multipliers; cooldown in seconds
Config.Combat = {
	Knight = { base = 3, cooldown = 0.3, reach = 92 / 9, reachPerTier = 10 / 9, arc = 1, closeRange = 30 / 9 },
	Wizard = { base = 3, cooldown = 0.4, speed = 480 / 9, life = 110 / 60, blastBase = 2, blastRadius = 66 / 9, blastPerTier = 1 },
	Bowman = { base = 2, cooldown = 0.26, speed = 780 / 9, life = 80 / 60, pierce = 3 },
}
Config.Classes = { "Knight", "Wizard", "Bowman" }

-- Bowman arrows pierce one more enemy at weapon tiers 2, 4 and 8 (like the JS game).
function Config.arrowPierce(tier)
	local n = Config.Combat.Bowman.pierce
	for _, t in ipairs({ 2, 4, 8 }) do
		if tier >= t then
			n += 1
		end
	end
	return n
end

-- ---------- upgrades (damage upgrades were removed; weapons are the damage progression) ----------
function Config.upgradeCost(kind, level) -- kind = "health" | "speed" | "ability"; level = levels already bought
	return Data.upgrades[kind].costs[level + 1]
end

function Config.maxHealth(className, level)
	return math.round(Data.classes[className].health * (1 + 0.15 * level))
end

function Config.walkSpeedMultiplier(level)
	return 1 + 0.04 * level
end

-- Roblox WalkSpeed for a class. 16 (the Roblox default) matches the JS Wizard speed of 2.5.
function Config.walkSpeed(className, level)
	return 16 * (Data.classes[className].speed / 2.5) * Config.walkSpeedMultiplier(level)
end

function Config.abilityCooldownSeconds(level)
	return math.max(3, 7 - 0.5 * level)
end

-- ---------- egg odds ----------
local BASE_WEIGHTS = { 100, 40, 15, 6, 2, 0.6, 0.2, 0.05 }

function Config.eggWeights(depth)
	local lowPenalty = math.max(0.04, 1 - 0.115 * (depth - 1)) -- deeper dungeons rarely drop Common/Uncommon/Rare
	local w = {}
	for i = 1, 8 do
		local idx = i - 1
		w[i] = BASE_WEIGHTS[i] * (1 + (depth - 1) * idx * 0.5) * ((idx < 3) and lowPenalty or 1)
	end
	return w
end

function Config.rollEgg(depth)
	local w = Config.eggWeights(depth)
	local total = 0
	for _, x in ipairs(w) do
		total += x
	end
	local r = math.random() * total
	for i = 1, 8 do
		r -= w[i]
		if r <= 0 then
			return i
		end
	end
	return 8
end

-- ---------- dungeons and enemies ----------
-- World 1 dungeons are depth 1..9, World 2 dungeons are depth 10..18.
function Config.dungeonFloors(depth, world)
	if world == 2 then
		return 5
	end
	return math.min(4, 1 + math.ceil(depth / 3))
end

-- kind = "normal" | "runner" | "tank" | "boss"; floorIndex starts at 0. Matches spawn() in the JS game.
function Config.enemyStats(depth, floorIndex, kind, world)
	local d = depth + floorIndex * 0.7
	local hp
	if kind == "boss" then
		hp = math.round((150 + 80 * d) * ((world == 2) and 0.78 or 0.8)) -- World 1 bosses were nerfed in the JS game
	else
		local mult = (kind == "tank") and 3.5 or ((kind == "runner") and 0.6 or 1)
		hp = math.round((6 + math.floor(d * 2.5)) * mult)
	end
	local baseDamage = (kind == "boss") and ((world == 2) and 19 or 18) or ((kind == "tank") and 15 or ((kind == "runner") and 7 or 9))
	local speed = (kind == "boss") and (0.8 + 0.05 * d) or (((kind == "tank") and 0.65 or ((kind == "runner") and 1.5 or 1)) + d * 0.04)
	return {
		health = math.max(1, hp),
		damage = baseDamage * (1 + 0.14 * (d - 1)),
		armor = (kind == "boss") and 0.7 or ((kind == "tank") and 0.65 or 1), -- damage taken is multiplied by this
		-- JS speed units: the player walks at about 2.5, so WalkSpeed = 16 * speedFactor / 2.5 (see DungeonService)
		speedFactor = speed + ((kind == "boss") and 0 or math.random() * 0.25),
	}
end

-- Boss moves, from bossAI() in the JS game (JS frames are 1/60 s, distances converted to studs).
Config.Boss = {
	slamEvery = { [1] = 400 / 60, [2] = 380 / 60 }, -- seconds between ground slams, by world
	slamEveryEnraged = { [1] = 250 / 60, [2] = 240 / 60 },
	slamWarning = 50 / 60, -- the red ring shows this long before the slam lands
	slamRadius = 96 / 9,
	slamDamage = 0.9, -- times the boss damage
	summonEvery = 760 / 60,
	summonEveryEnraged = 500 / 60,
	summonCount = 2,
	maxHelpers = 12,
	enrageAt = 0.5, -- below half health
	enrageSpeed = 1.25,
	enrageDamage = 1.15,
}
Config.WakeDistance = 170 / 9 -- sleeping enemies wake when a player comes this close on the same floor

return Config
