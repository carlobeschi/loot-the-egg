--[[ ClientMinimap  (LocalScript, put it in StarterPlayer > StarterPlayerScripts)
  A small map on the left of the screen, like minimap() in the JS game. It shows the world you are in, seen from
  above with north (-Z) at the top:
    - the town (orange), the pen plots (brown, yours in gold)
    - each dungeon as a square with its number: green = open for you, red = locked, flashing = its egg alarm is on
    - eggs lying on the ground (yellow dots), other players (white dots) and you (the arrow)
  Positions come from attributes the server puts on the tower and plot Models and on Workspace, because with
  streaming on, far-away parts are not on your computer but those Models and attributes are.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))

local player = Players.LocalPlayer
local SIZE = 170 -- pixels
local MARGIN = 20 -- studs of empty border around the world

local gui = Instance.new("ScreenGui")
gui.Name = "Minimap"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Name = "Map"
frame.Size = UDim2.fromOffset(SIZE, SIZE)
frame.Position = UDim2.fromOffset(14, 148) -- under the coins, clear of the phone thumbstick
frame.BackgroundColor3 = Color3.fromRGB(63, 127, 53)
frame.BackgroundTransparency = 0.15
frame.ClipsDescendants = true
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
local stroke = Instance.new("UIStroke", frame)
stroke.Color = Color3.fromRGB(20, 24, 30)
stroke.Thickness = 2

local function box(color, zIndex)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.ZIndex = zIndex or 1
	f.Parent = frame
	return f
end

-- ---------- what is in the current world ----------
local state = nil -- the latest numbers from the server (for which dungeons are open)
local world = 1
local minX, minZ, span = -300, -300, 600
local towerBoxes = {} -- [tower Model] = Frame
local staticBoxes = {} -- town and plots
local dots = {} -- reused dots for eggs and players

local function worldOf(position)
	return (position - Config.World2Origin).Magnitude < 1000 and 2 or 1
end

local function toMap(position)
	return UDim2.fromScale((position.X - minX) / span, (position.Z - minZ) / span)
end
local function sizeOnMap(x, z)
	return UDim2.fromScale(x / span, z / span)
end

local function plots()
	local folder = workspace:FindFirstChild("Plots")
	return folder and folder:GetChildren() or {}
end
local function towers()
	local folder = workspace:FindFirstChild("Towers")
	return folder and folder:GetChildren() or {}
end

local function rebuild()
	for _, f in pairs(towerBoxes) do
		f:Destroy()
	end
	for _, f in ipairs(staticBoxes) do
		f:Destroy()
	end
	towerBoxes, staticBoxes = {}, {}
	world = player:GetAttribute("World") or 1
	frame.BackgroundColor3 = world == 2 and Color3.fromRGB(90, 58, 48) or Color3.fromRGB(63, 127, 53)

	-- the area to show: everything that belongs to this world, plus a margin, as a square
	local lo, hi = Vector3.new(math.huge, 0, math.huge), Vector3.new(-math.huge, 0, -math.huge)
	local function include(center, extent)
		lo = Vector3.new(math.min(lo.X, center.X - extent.X / 2), 0, math.min(lo.Z, center.Z - extent.Z / 2))
		hi = Vector3.new(math.max(hi.X, center.X + extent.X / 2), 0, math.max(hi.Z, center.Z + extent.Z / 2))
	end
	local town = workspace:GetAttribute("Town" .. world .. "Center")
	local townExtent = workspace:GetAttribute("Town" .. world .. "Extent")
	if town and townExtent then
		include(town, townExtent)
	end
	if world == 1 then
		for _, plot in ipairs(plots()) do
			local c, e = plot:GetAttribute("Center"), plot:GetAttribute("Extent")
			if c and e then
				include(c, e)
			end
		end
	end
	for _, tower in ipairs(towers()) do
		local c, s = tower:GetAttribute("Center"), tower:GetAttribute("Size")
		if c and s and tower:GetAttribute("World") == world then
			include(c, Vector3.new(s, 0, s))
		end
	end
	if lo.X == math.huge then
		return -- nothing known yet
	end
	span = math.max(hi.X - lo.X, hi.Z - lo.Z) + MARGIN * 2
	minX = (lo.X + hi.X) / 2 - span / 2
	minZ = (lo.Z + hi.Z) / 2 - span / 2

	if town and townExtent then
		local f = box(Color3.fromRGB(255, 154, 61), 1)
		f.Position = toMap(town)
		f.Size = sizeOnMap(townExtent.X, townExtent.Z)
		table.insert(staticBoxes, f)
	end
	if world == 1 then
		for _, plot in ipairs(plots()) do
			local c, e = plot:GetAttribute("Center"), plot:GetAttribute("Extent")
			if c and e then
				local f = box(Color3.fromRGB(138, 90, 42), 1)
				f.Name = "Plot"
				f.Position = toMap(c)
				f.Size = sizeOnMap(e.X, e.Z)
				f:SetAttribute("PlotOf", plot.Name)
				table.insert(staticBoxes, f)
			end
		end
	end
	for _, tower in ipairs(towers()) do
		local c, s = tower:GetAttribute("Center"), tower:GetAttribute("Size")
		if c and s and tower:GetAttribute("World") == world then
			local f = box(Color3.fromRGB(255, 80, 80), 2)
			f.Position = toMap(c)
			f.Size = sizeOnMap(s, s)
			local n = Instance.new("TextLabel")
			n.Size = UDim2.fromScale(1, 1)
			n.BackgroundTransparency = 1
			n.Text = tostring(tower:GetAttribute("Depth"))
			n.TextScaled = true
			n.Font = Enum.Font.FredokaOne
			n.TextColor3 = Color3.new(0, 0, 0)
			n.ZIndex = 3
			n.Parent = f
			towerBoxes[tower] = f
		end
	end
end

local function unlocked(depth, w)
	if not state then
		return false
	end
	if w == 2 then
		return state.world2 and (state.bestDepth2 or 0) >= depth - 10
	end
	return (state.bestDepth or 0) >= depth - 1
end

-- ---------- the moving parts ----------
local arrow = Instance.new("TextLabel")
arrow.AnchorPoint = Vector2.new(0.5, 0.5)
arrow.Size = UDim2.fromOffset(16, 16)
arrow.BackgroundTransparency = 1
arrow.Text = "▲"
arrow.TextScaled = true
arrow.TextColor3 = Color3.new(1, 1, 1)
arrow.TextStrokeTransparency = 0
arrow.ZIndex = 6
arrow.Parent = frame

local function dot(i, color, zIndex)
	local d = dots[i]
	if not d then
		d = box(color, zIndex)
		d.Size = UDim2.fromOffset(6, 6)
		Instance.new("UICorner", d).CornerRadius = UDim.new(1, 0)
		dots[i] = d
	end
	d.BackgroundColor3 = color
	d.ZIndex = zIndex
	d.Visible = true
	return d
end

local function update()
	if (player:GetAttribute("World") or 1) ~= world then
		rebuild()
	end
	local blink = os.clock() % 0.6 < 0.3
	for tower, f in pairs(towerBoxes) do
		if not tower.Parent then
			f:Destroy()
			towerBoxes[tower] = nil
		else
			local open = unlocked(tower:GetAttribute("Depth"), world)
			local enemies = tower:FindFirstChild("Enemies")
			if enemies and enemies:GetAttribute("Alarm") and blink then
				f.BackgroundColor3 = Color3.fromRGB(255, 211, 74)
			else
				f.BackgroundColor3 = open and Color3.fromRGB(111, 209, 111) or Color3.fromRGB(255, 80, 80)
			end
		end
	end
	local mine = nil
	for _, plot in ipairs(plots()) do
		if plot:GetAttribute("OwnerUserId") == player.UserId then
			mine = plot.Name
		end
	end
	for _, f in ipairs(staticBoxes) do
		if f.Name == "Plot" then
			f.BackgroundColor3 = f:GetAttribute("PlotOf") == mine and Color3.fromRGB(255, 211, 74) or Color3.fromRGB(138, 90, 42)
		end
	end

	-- eggs on the ground and other players
	local used = 0
	for _, child in ipairs(workspace:GetChildren()) do
		if child.Name == "Egg" and child:IsA("BasePart") and worldOf(child.Position) == world then
			used += 1
			dot(used, Color3.fromRGB(255, 211, 74), 4).Position = toMap(child.Position)
		end
	end
	for _, other in ipairs(Players:GetPlayers()) do
		local root = other ~= player and other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		if root and worldOf(root.Position) == world then
			used += 1
			dot(used, Color3.new(1, 1, 1), 5).Position = toMap(root.Position)
		end
	end
	for i = used + 1, #dots do
		dots[i].Visible = false
	end

	-- you
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	arrow.Visible = root ~= nil
	if root then
		local look = root.CFrame.LookVector
		arrow.Position = toMap(root.Position)
		arrow.Rotation = math.deg(math.atan2(look.X, -look.Z))
	end
end

ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("State").OnClientEvent:Connect(function(s)
	state = s
end)

-- towers and plots can arrive a little after the game starts: rebuild when they do
local function watch(folderName)
	local folder = workspace:WaitForChild(folderName, 30)
	if folder then
		folder.ChildAdded:Connect(function()
			task.wait(0.5)
			rebuild()
		end)
	end
end
task.spawn(watch, "Towers")
task.spawn(watch, "Plots")
workspace:GetAttributeChangedSignal("Town1Center"):Connect(rebuild)
workspace:GetAttributeChangedSignal("Town2Center"):Connect(rebuild)

rebuild()
while true do
	update()
	task.wait(0.15)
end
