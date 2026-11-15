--[[ ShopService  (ModuleScript, put it in ServerScriptService)
  The places in town where you spend coins, and what they sell:
    Blacksmith  - weapon tiers for each class (names and prices from the JS game)
    Trainer     - upgrades for your current class: health, speed, ability
    World Gate  - unlocks World 2 when you meet all four requirements
    Pen sign    - on every plot: upgrade the pen, sell your weakest pet, equip best
  Each station is a small hut with a sign and a ProximityPrompt (press E). The prompt asks the client to open
  that window (ClientShops). Buying goes through RemoteEvents, and the server checks every price.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Data = Config.Data

local ShopService = {}
local DataService, PlotService, CombatService
local openWindow -- RemoteEvent: server -> client "open this window"
local notify = function(_player, _text) end

-- ---------- buying ----------
function ShopService.BuyWeapon(player, className)
	local profile = DataService.Get(player)
	if not profile or not Data.weapons[className] then
		return
	end
	local tier = profile.weaponTier[className] or 0
	local maxTier = Config.maxWeaponTier(profile.world2Unlocked)
	if tier >= maxTier then
		notify(player, profile.world2Unlocked and "That's the best weapon there is!" or "Unlock World 2 at the World Gate for stronger weapons.")
		return
	end
	local nextInfo = Config.weaponInfo(className, tier + 1)
	if profile.coins < nextInfo.price then
		notify(player, "You need " .. nextInfo.price .. " coins for the " .. nextInfo.name .. ".")
		return
	end
	profile.coins -= nextInfo.price
	profile.weaponTier[className] = tier + 1
	if profile.class == className then
		CombatService.Equip(player, true)
	end
	notify(player, "Bought the " .. nextInfo.name .. "!")
end

local UPGRADE_KINDS = { health = true, speed = true, ability = true }

function ShopService.BuyUpgrade(player, kind)
	local profile = DataService.Get(player)
	if not profile or not UPGRADE_KINDS[kind] then
		return
	end
	local levels = profile.upgrades[profile.class]
	local level = levels[kind] or 0
	if level >= Data.upgrades[kind].max then
		notify(player, "That upgrade is maxed out for your " .. profile.class .. ".")
		return
	end
	local cost = Config.upgradeCost(kind, level)
	if profile.coins < cost then
		notify(player, "You need " .. cost .. " coins.")
		return
	end
	profile.coins -= cost
	levels[kind] = level + 1
	CombatService.Equip(player, true) -- applies the new health and speed
	notify(player, profile.class .. " " .. kind .. " is now level " .. (level + 1) .. "!")
end

-- ---------- the stations ----------
local function part(parent, name, size, cframe, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Anchored = true
	p.Color = color
	p.Material = material or Enum.Material.WoodPlanks
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function signText(sign, text, face)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.Parent = gui
end

local function addPrompt(target, actionText, objectText, window, allowed)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = target
	prompt.Triggered:Connect(function(player)
		if allowed and not allowed(player) then
			return
		end
		openWindow:FireClient(player, window)
	end)
	return prompt
end

-- A little hut: floor, three walls, a roof, a sign and a counter you press E at. Faces -Z (toward the tower).
local function buildStation(folder, name, position, roofColor, title, actionText, window)
	local model = Instance.new("Model")
	model.Name = name
	local base = CFrame.new(position)
	local wood = Color3.fromRGB(150, 105, 65)
	part(model, "Floor", Vector3.new(16, 1, 12), base * CFrame.new(0, 0.5, 0), Color3.fromRGB(120, 90, 60))
	part(model, "Back", Vector3.new(16, 10, 1), base * CFrame.new(0, 5.5, 5.5), wood)
	part(model, "Left", Vector3.new(1, 10, 12), base * CFrame.new(-7.5, 5.5, 0), wood)
	part(model, "Right", Vector3.new(1, 10, 12), base * CFrame.new(7.5, 5.5, 0), wood)
	part(model, "Roof", Vector3.new(18, 1, 14), base * CFrame.new(0, 11, 0), roofColor, Enum.Material.SmoothPlastic)
	local sign = part(model, "Sign", Vector3.new(14, 3, 0.5), base * CFrame.new(0, 13, -6.5), Color3.fromRGB(60, 40, 25))
	signText(sign, title, Enum.NormalId.Front)
	local counter = part(model, "Counter", Vector3.new(10, 3.5, 2), base * CFrame.new(0, 2.25, -3), Color3.fromRGB(110, 75, 45))
	addPrompt(counter, actionText, title, window)
	model.Parent = folder
	return model
end

function ShopService.Init(dataService, plotService, combatService, openWindowRemote, notifyFunction)
	DataService = dataService
	PlotService = plotService
	CombatService = combatService
	openWindow = openWindowRemote
	notify = notifyFunction or notify

	local folder = workspace:FindFirstChild("Town")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Town"
		folder.Parent = workspace
	end
	-- the town is the TownZone around the middle of the map; the test tower is south (-Z), the plots north (+Z)
	buildStation(folder, "Blacksmith", Vector3.new(-30, 0, -10), Color3.fromRGB(200, 70, 50), "Blacksmith", "Buy weapons", "Weapons")
	buildStation(folder, "Trainer", Vector3.new(30, 0, -10), Color3.fromRGB(70, 140, 220), "Trainer", "Buy upgrades", "Upgrades")
	buildStation(folder, "WorldGate", Vector3.new(0, 0, 30), Color3.fromRGB(150, 80, 220), "World Gate", "Open the gate", "WorldGate")

	-- every plot's sign gets a prompt for the pen window
	local plots = workspace:FindFirstChild("Plots")
	if plots then
		for _, plot in ipairs(plots:GetChildren()) do
			local sign = plot:FindFirstChild("Sign")
			if sign and sign:IsA("BasePart") then
				addPrompt(sign, "Pen options", "Pen", "Pen", function(player)
					if PlotService.GetPlot(player) ~= plot then
						notify(player, "This isn't your pen.")
						return false
					end
					return true
				end)
			end
		end
	end

end

return ShopService
