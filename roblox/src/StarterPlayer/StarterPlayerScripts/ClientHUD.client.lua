--[[ ClientHUD  (LocalScript, put it in StarterPlayer > StarterPlayerScripts)
  A simple on-screen HUD: coins and income, plus the Equip Best, Rebirth and Settings buttons.
  The Settings panel has the "Show my pets" switch. It hides your pets on YOUR screen only.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
for _, name in ipairs({ "Hatch", "EquipBest", "Rebirth", "SetShowPets", "ChooseClass", "State", "Notice" }) do
	remotes:WaitForChild(name)
end

local showPets = true

-- ---------- building the UI ----------
local gui = Instance.new("ScreenGui")
gui.Name = "LootTheEggHUD"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function label(parent, size, position, text)
	local l = Instance.new("TextLabel")
	l.Size = size
	l.Position = position
	l.BackgroundTransparency = 0.35
	l.BackgroundColor3 = Color3.fromRGB(20, 24, 30)
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.Text = text
	l.Parent = parent
	Instance.new("UICorner", l)
	return l
end

local function button(text, order, color, callback)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(170, 44)
	b.Position = UDim2.new(1, -184, 0.5, -60 + order * 54)
	b.BackgroundColor3 = color
	b.TextColor3 = Color3.new(0, 0, 0)
	b.Font = Enum.Font.FredokaOne
	b.TextScaled = true
	b.Text = text
	b.Parent = gui
	Instance.new("UICorner", b)
	b.MouseButton1Click:Connect(callback)
	return b
end

local info = label(gui, UDim2.fromOffset(330, 40), UDim2.fromOffset(14, 14), "Loading...")
local info2 = label(gui, UDim2.fromOffset(330, 30), UDim2.fromOffset(14, 60), "")
local notice = label(gui, UDim2.fromOffset(520, 36), UDim2.new(0.5, -260, 0, 14), "")
notice.Visible = false

button("Hatch (nest)", -1, Color3.fromRGB(111, 209, 111), function() remotes.Hatch:FireServer() end)
button("Equip Best", 0, Color3.fromRGB(255, 211, 74), function() remotes.EquipBest:FireServer() end)
local rebirthButton = button("Rebirth", 1, Color3.fromRGB(255, 154, 208), function() remotes.Rebirth:FireServer() end)

-- Settings panel
local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(300, 150)
panel.Position = UDim2.new(0.5, -150, 0.5, -75)
panel.BackgroundColor3 = Color3.fromRGB(30, 50, 80)
panel.Visible = false
panel.Parent = gui
Instance.new("UICorner", panel)
label(panel, UDim2.new(1, -20, 0, 36), UDim2.fromOffset(10, 10), "Settings")
local petsToggle = Instance.new("TextButton")
petsToggle.Size = UDim2.new(1, -20, 0, 44)
petsToggle.Position = UDim2.fromOffset(10, 56)
petsToggle.Font = Enum.Font.FredokaOne
petsToggle.TextScaled = true
petsToggle.Parent = panel
Instance.new("UICorner", petsToggle)
local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(1, -20, 0, 34)
closeButton.Position = UDim2.fromOffset(10, 106)
closeButton.Text = "Close"
closeButton.Font = Enum.Font.FredokaOne
closeButton.TextScaled = true
closeButton.Parent = panel
Instance.new("UICorner", closeButton)
closeButton.MouseButton1Click:Connect(function() panel.Visible = false end)

-- class picker (choosing a class respawns your weapon with that class's health and speed)
local classColors = { Knight = Color3.fromRGB(217, 178, 90), Wizard = Color3.fromRGB(157, 143, 255), Bowman = Color3.fromRGB(127, 192, 108) }
for i, className in ipairs({ "Knight", "Wizard", "Bowman" }) do
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(104, 36)
	b.Position = UDim2.new(0, 14 + (i - 1) * 112, 1, -50)
	b.BackgroundColor3 = classColors[className]
	b.TextColor3 = Color3.new(0, 0, 0)
	b.Font = Enum.Font.FredokaOne
	b.TextScaled = true
	b.Text = className
	b.Parent = gui
	Instance.new("UICorner", b)
	b.MouseButton1Click:Connect(function()
		remotes.ChooseClass:FireServer(className)
	end)
end

button("Settings", 2, Color3.fromRGB(154, 208, 255), function() panel.Visible = not panel.Visible end)

-- ---------- show / hide my pets (client only) ----------
local function myPlot()
	local plots = workspace:FindFirstChild("Plots")
	if not plots then return nil end
	for _, plot in ipairs(plots:GetChildren()) do
		if plot:GetAttribute("OwnerUserId") == player.UserId then
			return plot
		end
	end
	return nil
end

local function applyPetVisibility()
	petsToggle.Text = "Show my pets: " .. (showPets and "ON" or "OFF")
	petsToggle.BackgroundColor3 = showPets and Color3.fromRGB(111, 209, 111) or Color3.fromRGB(255, 106, 106)
	local plot = myPlot()
	local folder = plot and plot:FindFirstChild("Pets")
	if not folder then return end
	for _, d in ipairs(folder:GetDescendants()) do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = showPets and 0 or 1
		elseif d:IsA("BillboardGui") then
			d.Enabled = showPets
		end
	end
end

petsToggle.MouseButton1Click:Connect(function()
	showPets = not showPets
	remotes.SetShowPets:FireServer(showPets) -- saved with your profile
	applyPetVisibility()
end)

-- pets get rebuilt by the server whenever they change, so re-apply the setting each time
task.spawn(function()
	while true do
		task.wait(1)
		applyPetVisibility()
	end
end)

-- ---------- server messages ----------
local firstState = true
remotes.State.OnClientEvent:Connect(function(s)
	info.Text = "Coins " .. math.floor(s.coins) .. "   +" .. math.floor(s.income) .. "/s  (x" .. s.multiplier .. ")   Pets " .. s.pets .. "/" .. s.capacity
	rebirthButton.Text = "Rebirth x" .. s.multiplier
	local eggCount = 0
	for _, n in ipairs(s.eggs or {}) do
		eggCount += n
	end
	info2.Text = s.class .. " - " .. s.weapon .. "   Eggs " .. eggCount .. (s.carrying and "   CARRYING AN EGG!" or "")
	if firstState then
		showPets = s.showPets
		firstState = false
	end
end)

remotes.Notice.OnClientEvent:Connect(function(text)
	notice.Text = text
	notice.Visible = true
	task.delay(4, function()
		if notice.Text == text then notice.Visible = false end
	end)
end)
