--[[ ClientShops  (LocalScript, put it in StarterPlayer > StarterPlayerScripts)
  The shop windows. The server opens one when you press E at a station (OpenWindow remote), and the HUD's
  Rebirth button opens the Rebirth window. Prices and names come from Config, your numbers from the State
  remote. Buttons only ASK the server; it checks the coins and does the buying.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Data = Config.Data

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
for _, name in ipairs({ "OpenWindow", "State", "BuyWeapon", "BuyUpgrade", "UpgradePen", "SellWeakest", "EquipBest", "Rebirth", "UnlockWorld2" }) do
	remotes:WaitForChild(name)
end

local state = nil -- the latest numbers from the server
local current = nil -- name of the open window, or nil
local sellArmed = false -- selling needs two clicks

-- ---------- the window frame ----------
local gui = Instance.new("ScreenGui")
gui.Name = "LootTheEggShops"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(460, 380)
frame.Position = UDim2.new(0.5, -230, 0.5, -190)
frame.BackgroundColor3 = Color3.fromRGB(30, 40, 60)
frame.Visible = false
frame.Parent = gui
Instance.new("UICorner", frame)
local sizeLimit = Instance.new("UISizeConstraint") -- shrinks on small phone screens
sizeLimit.MaxSize = Vector2.new(460, 380)
sizeLimit.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -60, 0, 40)
title.Position = UDim2.fromOffset(12, 8)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.FredokaOne
title.TextScaled = true
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(40, 40)
close.Position = UDim2.new(1, -48, 0, 8)
close.BackgroundColor3 = Color3.fromRGB(255, 106, 106)
close.Text = "X"
close.Font = Enum.Font.FredokaOne
close.TextScaled = true
close.Parent = frame
Instance.new("UICorner", close)

local list = Instance.new("Frame")
list.Size = UDim2.new(1, -24, 1, -64)
list.Position = UDim2.fromOffset(12, 56)
list.BackgroundTransparency = 1
list.Parent = frame
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

local function clearRows()
	for _, child in ipairs(list:GetChildren()) do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

-- one row: text on the left, an optional button on the right
local function row(order, text, buttonText, enabled, onClick)
	local r = Instance.new("Frame")
	r.Size = UDim2.new(1, 0, 0, 52)
	r.BackgroundColor3 = Color3.fromRGB(45, 58, 85)
	r.LayoutOrder = order
	r.Parent = list
	Instance.new("UICorner", r)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(buttonText and 0.62 or 1, -12, 1, -8)
	label.Position = UDim2.fromOffset(10, 4)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text
	label.Parent = r
	if buttonText then
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0.38, -12, 1, -12)
		b.Position = UDim2.new(0.62, 4, 0, 6)
		b.BackgroundColor3 = enabled and Color3.fromRGB(111, 209, 111) or Color3.fromRGB(130, 130, 140)
		b.TextColor3 = Color3.new(0, 0, 0)
		b.Font = Enum.Font.FredokaOne
		b.TextScaled = true
		b.Text = buttonText
		b.Parent = r
		Instance.new("UICorner", b)
		b.MouseButton1Click:Connect(onClick)
	end
end

local function short(n)
	n = math.floor(n)
	if n >= 1e9 then
		return string.format("%.1fB", n / 1e9)
	elseif n >= 1e6 then
		return string.format("%.1fM", n / 1e6)
	elseif n >= 1e4 then
		return string.format("%.1fK", n / 1e3)
	end
	return tostring(n)
end

local function tick(ok)
	return ok and "[OK] " or "[  ] "
end

-- ---------- what each window shows ----------
local windows = {}

windows.Weapons = function(s)
	title.Text = "Blacksmith"
	for i, className in ipairs(Config.Classes) do
		local tier = s.weaponTier[className] or 0
		local have = Config.weaponInfo(className, tier).name
		if tier >= s.maxWeaponTier then
			row(i, className .. ": " .. have .. (s.world2 and " (best)" or " (World 2 has more)"), nil)
		else
			local nextInfo = Config.weaponInfo(className, tier + 1)
			row(i, className .. ": " .. have .. "\nNext: " .. nextInfo.name, "Buy " .. short(nextInfo.price), s.coins >= nextInfo.price, function()
				remotes.BuyWeapon:FireServer(className)
			end)
		end
	end
	row(9, "Coins: " .. short(s.coins) .. ". New weapons hit harder.", nil)
end

windows.Upgrades = function(s)
	title.Text = "Trainer (" .. s.class .. ")"
	local labels = { health = "Health", speed = "Speed", ability = "Ability cooldown" }
	for i, kind in ipairs({ "health", "speed", "ability" }) do
		local level = s.upgrades[kind] or 0
		local max = Data.upgrades[kind].max
		if level >= max then
			row(i, labels[kind] .. ": level " .. level .. " (max)", nil)
		else
			local cost = Config.upgradeCost(kind, level)
			row(i, labels[kind] .. ": level " .. level .. "/" .. max, "Buy " .. short(cost), s.coins >= cost, function()
				remotes.BuyUpgrade:FireServer(kind)
			end)
		end
	end
	row(9, "Upgrades belong to each class. Coins: " .. short(s.coins), nil)
end

windows.Pen = function(s)
	title.Text = "Your pen: " .. Data.pen.names[s.penLevel + 1]
	row(1, "Pets " .. s.pets .. "/" .. s.capacity .. " in the pen, " .. s.stored .. " in storage", "Equip best", true, function()
		remotes.EquipBest:FireServer()
	end)
	if s.penLevel >= Config.MaxPenLevel then
		row(2, "Fully upgraded!", nil)
	else
		local cost = Config.penUpgradeCost(s.penLevel)
		row(2, "Upgrade to " .. Data.pen.names[s.penLevel + 2] .. " (+" .. Data.pen.capacityPerLevel .. " pets)", "Upgrade " .. short(cost), s.coins >= cost, function()
			remotes.UpgradePen:FireServer()
		end)
	end
	row(3, sellArmed and "Sure? Click again to sell your weakest pet." or "Sell your weakest pet for coins", sellArmed and "Yes, sell" or "Sell", s.pets + s.stored > 0, function()
		if sellArmed then
			sellArmed = false
			remotes.SellWeakest:FireServer()
		else
			sellArmed = true
			task.delay(4, function()
				sellArmed = false
			end)
		end
	end)
end

windows.Rebirth = function(s)
	title.Text = "Rebirth"
	local req = Config.rebirthRequirement(s.rebirths)
	if not req then
		row(1, "You reached the maximum rebirth!", nil)
		return
	end
	row(1, "Rebirths: " .. s.rebirths .. ". Pets earn x" .. s.multiplier .. " now, x" .. Config.multiplier(s.rebirths + 1) .. " after.", nil)
	row(2, tick(s.bestPet >= req.rarity) .. "A " .. Data.rarities[req.rarity] .. " pet or better", nil)
	row(3, tick(s.coins >= req.cost) .. short(req.cost) .. " coins (you keep your pets)", nil)
	row(4, "", "REBIRTH", s.bestPet >= req.rarity and s.coins >= req.cost, function()
		remotes.Rebirth:FireServer()
	end)
end

windows.WorldGate = function(s)
	title.Text = "World Gate"
	if s.world2 then
		row(1, "World 2 is unlocked! Stronger weapons are at the Blacksmith.", nil)
		row(2, "(The World 2 map comes in a later update.)", nil)
		return
	end
	local need = Config.World2
	local ok1, ok2 = s.rebirths >= need.rebirths, s.bestPet >= need.petRarity
	local ok3, ok4 = s.penLevel >= need.penLevel, s.coins >= need.coins
	row(1, tick(ok1) .. need.rebirths .. " rebirths (you have " .. s.rebirths .. ")", nil)
	row(2, tick(ok2) .. "A " .. Data.rarities[need.petRarity] .. " pet (or better)", nil)
	row(3, tick(ok3) .. "An " .. Data.pen.names[need.penLevel + 1] .. " fence (pen level " .. need.penLevel .. ")", nil)
	row(4, tick(ok4) .. short(need.coins) .. " coins", "Unlock", ok1 and ok2 and ok3 and ok4, function()
		remotes.UnlockWorld2:FireServer()
	end)
end

local function render()
	clearRows()
	if not current or not state then
		frame.Visible = false
		return
	end
	frame.Visible = true
	windows[current](state)
end

local function open(name)
	if windows[name] then
		current = name
		sellArmed = false
		render()
	end
end

close.MouseButton1Click:Connect(function()
	current = nil
	render()
end)

remotes.OpenWindow.OnClientEvent:Connect(open)
-- the HUD's Rebirth button sets this attribute (only on this computer) to open the Rebirth window
player:GetAttributeChangedSignal("OpenWindow"):Connect(function()
	local name = player:GetAttribute("OpenWindow")
	if name then
		player:SetAttribute("OpenWindow", nil)
		open(name)
	end
end)

remotes.State.OnClientEvent:Connect(function(s)
	state = s
	if current then
		render()
	end
end)

-- walking away closes the window
task.spawn(function()
	local openedAt
	while true do
		task.wait(0.5)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if current and current ~= "Rebirth" and root then
			openedAt = openedAt or root.Position
			if (root.Position - openedAt).Magnitude > 25 then
				current = nil
				render()
			end
		else
			openedAt = nil
		end
	end
end)
