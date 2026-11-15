--[[ ConfigData (ModuleScript, child of Config in ReplicatedStorage)
  GENERATED from the JavaScript game by tools/export_config.js - do not edit by hand.
  Re-run the tool after changing numbers in the JavaScript game.
  NOTE: Lua tables start at 1. Rarity 1 = Common ... rarity 8 = Divine. Weapon tier arrays start at tier 0 in the
  JavaScript game, so tier N is index N+1 here. Colors are hex strings; use Color3.fromHex(...).
]]
return {
	rarities = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Celestial", "Divine" },
	rarityColors = { "#cfd2d6", "#6fd16f", "#4aa3ff", "#b25cff", "#ffb02e", "#ff4fa3", "#39e6ff", "#fff3a0" },
	income = { 1, 3, 9, 28, 100, 350, 1200, 5000 },
	pets = {
		{
			{
				name = "Chick",
				color = "#ffe14a",
				accent = "#ff9a2a",
				wings = 0
			},
			{
				name = "Duckling",
				color = "#f5f0a0",
				accent = "#ffa030",
				wings = 0
			}
		},
		{
			{
				name = "Piglet",
				color = "#f4a3b5",
				accent = "#e27890",
				wings = 0
			},
			{
				name = "Bunny",
				color = "#f0f0f0",
				accent = "#f4a3b5",
				wings = 0
			}
		},
		{
			{
				name = "Fox",
				color = "#e8782a",
				accent = "#f8f0e0",
				wings = 0
			},
			{
				name = "Wolf Pup",
				color = "#8f9aa6",
				accent = "#4c5662",
				wings = 0
			}
		},
		{
			{
				name = "Baby Dragon",
				color = "#58c0a0",
				accent = "#d04a4a",
				wings = 1
			},
			{
				name = "Griffin Cub",
				color = "#c9a24b",
				accent = "#f0f0f0",
				wings = 1
			}
		},
		{
			{
				name = "Phoenix",
				color = "#ff6a1a",
				accent = "#ffd24a",
				wings = 2
			},
			{
				name = "Golden Drake",
				color = "#ffc933",
				accent = "#ffffff",
				wings = 2
			}
		},
		{
			{
				name = "Unicorn",
				color = "#ffd0f0",
				accent = "#ff4fa3",
				wings = 1
			},
			{
				name = "Kitsune",
				color = "#ff9a6a",
				accent = "#ffffff",
				wings = 1
			}
		},
		{
			{
				name = "Sky Wyvern",
				color = "#39e6ff",
				accent = "#ffffff",
				wings = 2
			},
			{
				name = "Cloud Lion",
				color = "#cff6ff",
				accent = "#39e6ff",
				wings = 2
			}
		},
		{
			{
				name = "Angel Dragon",
				color = "#fff3a0",
				accent = "#ffffff",
				wings = 2
			},
			{
				name = "Star Phoenix",
				color = "#ffffff",
				accent = "#fff3a0",
				wings = 2
			}
		}
	},
	rebirth = {
		required = { 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8 },
		cost = { 2000, 5600, 15700, 43900, 122900, 344200, 963800, 2698600, 7556000, 21156900, 59239400, 165870200 },
		multiplierStep = 0.5
	},
	pen = {
		colors = { "#9a6a3a", "#8a8f98", "#b0b8c4", "#c8743a", "#ffc933", "#3ed67a", "#3a8bff", "#b25cff", "#ff4fa3", "#ffffff" },
		names = { "Wooden", "Stone", "Iron", "Copper", "Golden", "Emerald", "Sapphire", "Amethyst", "Ruby", "Rainbow" },
		baseCapacity = 6,
		capacityPerLevel = 2
	},
	classes = {
		Knight = {
			health = 150,
			speed = 2.3,
			cooldownMs = 300,
			ability = "Shield Slam"
		},
		Wizard = {
			health = 90,
			speed = 2.5,
			cooldownMs = 400,
			ability = "Blink Burst"
		},
		Bowman = {
			health = 100,
			speed = 3,
			cooldownMs = 260,
			ability = "Arrow Volley"
		}
	},
	weapons = {
		Knight = {
			names = { "Rusty Sword", "Iron Sword", "Steel Sword", "Golden Sword", "Diamond Sword", "Dragon Slayer", "Flamebrand", "Frostbite Blade", "Thunder Edge", "Shadow Reaver", "Sun Blade", "World Ender" },
			prices = { 0, 300, 900, 2500, 7000, 20000, 60000, 150000, 400000, 1000000, 3000000, 10000000 },
			colors = { "#9aa0a6", "#dfe5e8", "#cfd6dc", "#ffd34a", "#6ff0ff", "#ff5a3a", "#ff7a2a", "#7fd8ff", "#ffe45f", "#7a3aff", "#ffc933", "#ff3a8a" },
			perk = "+10 reach per tier, 1.6x damage, faster swings"
		},
		Wizard = {
			names = { "Wooden Staff", "Crystal Staff", "Moonstone Staff", "Flame Staff", "Storm Staff", "Archmage Staff", "Ember Staff", "Glacier Staff", "Tempest Staff", "Void Staff", "Sunfire Staff", "Cosmos Staff" },
			prices = { 0, 300, 900, 2500, 7000, 20000, 60000, 150000, 400000, 1000000, 3000000, 10000000 },
			colors = { "#b9aeff", "#7fffd4", "#dcdcff", "#ff8a3d", "#5ac8ff", "#ff4fd8", "#ff6a2a", "#9fe8ff", "#fff06a", "#8a3aff", "#ffb02e", "#ff5af0" },
			perk = "+9 blast radius per tier, 1.7x damage, faster casts"
		},
		Bowman = {
			names = { "Short Bow", "Hunter Bow", "Longbow", "Elven Bow", "Dragonbone Bow", "Starfall Bow", "Ember Bow", "Glacier Bow", "Tempest Bow", "Void Bow", "Sunfire Bow", "Cosmos Bow" },
			prices = { 0, 300, 900, 2500, 7000, 20000, 60000, 150000, 400000, 1000000, 3000000, 10000000 },
			colors = { "#8a5a2a", "#6b8e3a", "#b08a4a", "#4ad07a", "#e8e4d8", "#ffd34a", "#ff8a3a", "#8fe0ff", "#fff06a", "#9a4aff", "#ffd23a", "#ff6af0" },
			perk = "+1 pierce at tiers 2, 4 and 8, 1.7x damage, faster shots"
		}
	},
	upgrades = {
		health = {
			max = 20,
			costs = { 120, 192, 307, 492, 786, 1258, 2013, 3221, 5154, 8246, 13194, 21111, 33777, 54043, 86469, 138351, 221361, 354177, 566684, 906694 }
		},
		speed = {
			max = 15,
			costs = { 140, 238, 405, 688, 1169, 1988, 3379, 5745, 9766, 16602, 28224, 47981, 81567, 138664, 235729 }
		},
		ability = {
			max = 10,
			costs = { 200, 340, 578, 983, 1670, 2840, 4828, 8207, 13952, 23718 }
		}
	}
}
