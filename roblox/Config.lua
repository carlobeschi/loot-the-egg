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

-- kind = "normal" | "runner" | "tank" | "boss"; floorIndex starts at 0
function Config.enemyStats(depth, floorIndex, kind, world)
	local d = depth + floorIndex * 0.7
	local hp
	if kind == "boss" then
		hp = math.round((150 + 80 * d) * ((world == 2) and 0.78 or 1))
	else
		local mult = (kind == "tank") and 3.5 or ((kind == "runner") and 0.6 or 1)
		hp = math.round((6 + math.floor(d * 2.5)) * mult)
	end
	local baseDamage = (kind == "boss") and ((world == 2) and 19 or 24) or ((kind == "tank") and 15 or ((kind == "runner") and 7 or 9))
	local speed = (kind == "boss") and (0.8 + 0.05 * d) or (((kind == "tank") and 0.65 or ((kind == "runner") and 1.5 or 1)) + d * 0.04)
	return {
		health = hp,
		damage = baseDamage * (1 + 0.14 * (d - 1)),
		armor = (kind == "boss") and 0.7 or ((kind == "tank") and 0.65 or 1), -- damage taken is multiplied by this
		speedFactor = speed, -- 1.0 = the normal player walk speed in the JavaScript game; scale it to your WalkSpeed
	}
end

return Config
