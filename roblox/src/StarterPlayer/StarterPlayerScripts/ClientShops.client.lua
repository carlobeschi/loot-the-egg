--[[ ClientShops  (LocalScript, put it in StarterPlayer > StarterPlayerScripts)
  The shop windows. The server opens one when you press E at a station (OpenWindow remote), and the HUD's
  Rebirth button opens the Rebirth window. Prices and names come from Config, your numbers from the State
  remote. Buttons only ASK the server; it checks the coins and does the buying.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Data = Config.Data
local Sounds = require(ReplicatedStorage.Config:WaitForChild("Sounds"))
local WeaponModels = require(ReplicatedStorage.Config:WaitForChild("WeaponModels"))

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
for _, name in ipairs({ "OpenWindow", "State", "BuyWeapon", "BuyWeaponRobux", "BuyUpgrade", "UpgradePen", "SellWeakest", "EquipBest", "Rebirth", "UnlockWorld2", "Travel" }) do
	remotes:WaitForChild(name)
end

local state = nil -- the latest numbers from the server
local current = nil -- name of the open window, or nil
local sellArmed = false -- selling needs two clicks

-- ---------- the window frame ----------
local gui = Instance.new("ScreenGui")
gui.Name = "LootTheEggShops"
gui.ResetOnSpawn = false
gui.DisplayOrder = 10 -- in front of the HUD
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.Size = UDim2.fromScale(0.94, 0.9) -- fills a small phone screen; the size limit below stops it at 460x380
frame.Position = UDim2.fromScale(0.5, 0.5)
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

local list = Instance.new("ScrollingFrame") -- scrolls when the screen is too short for every row
list.Size = UDim2.new(1, -24, 1, -64)
list.Position = UDim2.fromOffset(12, 56)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.ScrollBarThickness = 6
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
		b.MouseButton1Click:Connect(function()
			if enabled then
				Sounds.PlayLocal("buy")
			end
			onClick()
		end)
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

-- ---------- the Blacksmith: a card with a spinning picture of your next weapon ----------
local spinner = nil -- { camera, distance, center } of the picture on screen
local robuxPrices = {} -- [productId] = price in Robux (asked from Roblox once)

local function robuxPrice(productId)
	if robuxPrices[productId] == nil then
		robuxPrices[productId] = false -- asking
		task.spawn(function()
			local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, productId, Enum.InfoType.Product)
			robuxPrices[productId] = ok and info and info.PriceInRobux or false
		end)
	end
	return robuxPrices[productId] or nil
end

local function cardButton(parent, text, color, position, size, onClick)
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = position
	b.BackgroundColor3 = color
	b.TextColor3 = Color3.new(0, 0, 0)
	b.Font = Enum.Font.FredokaOne
	b.TextScaled = true
	b.Text = text
	b.Parent = parent
	Instance.new("UICorner", b)
	b.MouseButton1Click:Connect(onClick)
	return b
end

local function cardText(parent, text, position, size, color)
	local l = Instance.new("TextLabel")
	l.Size = size
	l.Position = position
	l.BackgroundTransparency = 1
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = text
	l.Parent = parent
	return l
end

-- what the card shows; when this doesn't change, the card isn't rebuilt (so the picture keeps spinning)
local function weaponsKey(s)
	local tier = s.weaponTier[s.class] or 0
	local nextInfo = Config.weaponInfo(s.class, math.min(tier + 1, 11))
	local productId = Config.weaponRobuxProduct(tier + 1)
	return table.concat({ s.class, tier, s.maxWeaponTier, tostring(s.coins >= (nextInfo.price or 0)), tostring(productId and robuxPrice(productId)) }, "|")
end

windows.Weapons = function(s)
	local className = s.class -- your class is for good, so only its weapons are for sale
	local tier = s.weaponTier[className] or 0
	local have = Config.weaponInfo(className, tier)
	local maxed = tier >= s.maxWeaponTier
	local showTier = maxed and tier or tier + 1
	local show = Config.weaponInfo(className, showTier)
	title.Text = "Blacksmith (" .. className .. ")"

	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, 200)
	card.BackgroundColor3 = Color3.fromRGB(45, 58, 85)
	card.LayoutOrder = 1
	card.Parent = list
	Instance.new("UICorner", card)

	-- the picture: the real weapon model in a ViewportFrame, turning slowly
	local view = Instance.new("ViewportFrame")
	view.Size = UDim2.new(0.42, -8, 1, -12)
	view.Position = UDim2.fromOffset(6, 6)
	view.BackgroundColor3 = Color3.fromHex(show.color):Lerp(Color3.fromRGB(20, 26, 40), 0.75)
	view.Ambient = Color3.fromRGB(170, 170, 180)
	view.LightColor = Color3.new(1, 1, 1)
	view.LightDirection = Vector3.new(-1, -1, -1)
	view.Parent = card
	Instance.new("UICorner", view)
	local model = WeaponModels.Build(className, showTier)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
		end
	end
	model.Parent = view
	local center, size = model:GetBoundingBox()
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.Parent = view
	view.CurrentCamera = camera
	spinner = { camera = camera, center = center.Position, distance = size.Magnitude * 1.25 }

	-- the words and the buttons
	local right = UDim2.new(0.42, 6, 0, 0)
	if maxed then
		cardText(card, have.name, right + UDim2.fromOffset(0, 10), UDim2.new(0.58, -14, 0, 34))
		cardText(card, s.world2 and "The best weapon there is!" or "Unlock World 2 at the World Gate for stronger weapons.", right + UDim2.fromOffset(0, 50), UDim2.new(0.58, -14, 0, 44), Color3.fromRGB(255, 220, 120))
	else
		local stronger = math.round((Config.weaponDamage(className, tier + 1) / Config.weaponDamage(className, tier) - 1) * 100)
		cardText(card, "Next weapon", right + UDim2.fromOffset(0, 8), UDim2.new(0.58, -14, 0, 20), Color3.fromRGB(180, 200, 230))
		cardText(card, show.name, right + UDim2.fromOffset(0, 28), UDim2.new(0.58, -14, 0, 32), Color3.fromHex(show.color):Lerp(Color3.new(1, 1, 1), 0.5))
		cardText(card, "Hits " .. stronger .. "% harder than your " .. have.name, right + UDim2.fromOffset(0, 62), UDim2.new(0.58, -14, 0, 34))
		local canPay = s.coins >= show.price
		cardButton(card, "Buy for " .. short(show.price) .. " coins", canPay and Color3.fromRGB(255, 211, 74) or Color3.fromRGB(130, 130, 140), right + UDim2.fromOffset(0, 104), UDim2.new(0.58, -14, 0, 40), function()
			if canPay then
				Sounds.PlayLocal("buy")
			end
			remotes.BuyWeapon:FireServer(className)
		end)
		local productId = Config.weaponRobuxProduct(tier + 1)
		local price = productId and robuxPrice(productId)
		if productId then
			cardButton(card, price and ("Buy for R$ " .. price) or "Buy with Robux", Color3.fromRGB(111, 209, 111), right + UDim2.fromOffset(0, 150), UDim2.new(0.58, -14, 0, 40), function()
				remotes.BuyWeaponRobux:FireServer()
			end)
		end
	end
	row(2, "Coins: " .. short(s.coins) .. ". Each new weapon hits harder.", nil)
end

RunService.RenderStepped:Connect(function()
	if spinner and spinner.camera.Parent then
		local a = os.clock() * 0.8
		local offset = Vector3.new(math.sin(a), 0.35, math.cos(a)).Unit * spinner.distance
		spinner.camera.CFrame = CFrame.lookAt(spinner.center + offset, spinner.center)
	end
end)

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
	row(9, "Upgrades for your class. Coins: " .. short(s.coins), nil)
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
		row(2, "Ember Wastes: Dungeons 10 to 18", "Travel", true, function()
			remotes.Travel:FireServer(2)
			current = nil -- close the window (the same as the X button)
			clearRows()
			frame.Visible = false
		end)
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

local lastKey = nil -- the Blacksmith card is only rebuilt when what it shows changes
local function render()
	if current == "Weapons" and state and frame.Visible then
		local key = weaponsKey(state)
		if key == lastKey then
			return
		end
		lastKey = key
	else
		lastKey = nil
	end
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
