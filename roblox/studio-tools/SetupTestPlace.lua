--[[ SetupTestPlace  (NOT a game script - paste it into Studio's Command Bar and press Enter)
  View tab > Command Bar. Run it in EDIT mode (not while playing), in a new Baseplate place.
  It builds everything the scripts expect so you can test right away:
    - Workspace.Plots with 8 plots (PenArea, Spawn, Fence, CollectPad, Sign with a "SignText" label)
    - Workspace.TownZone (an invisible safe area around the middle of the map)
    - ServerStorage.Enemies with Zombie, Runner, Tank and Boss rigs
  Running it again deletes and rebuilds those three things. It does not touch your scripts.
  The test tower (Dungeon 1, south of the town) is NOT built here: TowerService builds it when you press Play.
]]
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local function remove(parent, name)
	local old = parent:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end

local function part(parent, name, size, cframe, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Anchored = true
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- ---------- 1) plots ----------
remove(workspace, "Plots")
local plots = Instance.new("Folder")
plots.Name = "Plots"
plots.Parent = workspace

for i = 1, 8 do
	local column = (i - 1) % 4
	local row = math.floor((i - 1) / 4)
	local origin = Vector3.new(column * 70 - 105, 0.5, row * 70 + 130)
	local plot = Instance.new("Model")
	plot.Name = "Plot" .. i
	plot.Parent = plots

	part(plot, "Base", Vector3.new(60, 1, 60), CFrame.new(origin), Color3.fromRGB(90, 160, 80), Enum.Material.Grass)
	local area = part(plot, "PenArea", Vector3.new(34, 0.4, 26), CFrame.new(origin + Vector3.new(0, 0.8, -7)), Color3.fromRGB(120, 200, 100), Enum.Material.Grass)
	area.CanCollide = false
	part(plot, "Spawn", Vector3.new(6, 1, 6), CFrame.new(origin + Vector3.new(0, 1, 22)), Color3.fromRGB(255, 255, 255))

	local fence = Instance.new("Model")
	fence.Name = "Fence"
	fence.Parent = plot
	local wood = Color3.fromRGB(154, 106, 58)
	local function rail(size, offset)
		part(fence, "Rail", size, CFrame.new(origin + offset), wood, Enum.Material.Wood)
	end
	rail(Vector3.new(36, 3, 1), Vector3.new(0, 2.5, -21)) -- back
	rail(Vector3.new(1, 3, 28), Vector3.new(-18, 2.5, -7)) -- left
	rail(Vector3.new(1, 3, 28), Vector3.new(18, 2.5, -7)) -- right
	rail(Vector3.new(12, 3, 1), Vector3.new(-12, 2.5, 7)) -- front left (gap in the middle)
	rail(Vector3.new(12, 3, 1), Vector3.new(12, 2.5, 7)) -- front right

	part(plot, "CollectPad", Vector3.new(8, 0.6, 8), CFrame.new(origin + Vector3.new(24, 1, 7)), Color3.fromRGB(255, 211, 74), Enum.Material.Neon)

	local sign = part(plot, "Sign", Vector3.new(16, 5, 0.6), CFrame.new(origin + Vector3.new(0, 4, 14)), Color3.fromRGB(70, 50, 30), Enum.Material.Wood)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.Parent = sign
	local text = Instance.new("TextLabel")
	text.Name = "SignText"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextScaled = true
	text.Font = Enum.Font.FredokaOne
	text.Text = "Open Plot"
	text.Parent = gui

	plot.PrimaryPart = plot:FindFirstChild("Base")
end

-- ---------- 2) town zone ----------
remove(workspace, "TownZone")
local town = part(workspace, "TownZone", Vector3.new(90, 30, 90), CFrame.new(0, 15, 0), Color3.fromRGB(80, 160, 255))
town.Transparency = 1
town.CanCollide = false
town.CanQuery = false -- shouldn't block raycasts, but still fires Touched

-- ---------- 3) enemy rigs ----------
remove(ServerStorage, "Enemies")
local enemies = Instance.new("Folder")
enemies.Name = "Enemies"
enemies.Parent = ServerStorage

local function makeRig(name, color, scale)
	local rig
	local ok = pcall(function()
		rig = Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	end)
	if not ok or not rig then
		-- fallback: a very simple block rig, good enough to test chasing and damage
		rig = Instance.new("Model")
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Size = Vector3.new(2, 2, 1)
		root.Parent = rig
		local head = Instance.new("Part")
		head.Name = "Head"
		head.Size = Vector3.new(2, 1, 1)
		head.CFrame = root.CFrame * CFrame.new(0, 1.5, 0)
		head.Parent = rig
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = head
		weld.Parent = root
		local humanoid = Instance.new("Humanoid")
		humanoid.HipHeight = 2
		humanoid.Parent = rig
		rig.PrimaryPart = root
	end
	rig.Name = name
	local bodyColors = rig:FindFirstChildOfClass("BodyColors")
	if bodyColors then
		bodyColors:Destroy() -- otherwise it overrides the colors below
	end
	for _, d in ipairs(rig:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Color = color
		end
	end
	local root = rig:FindFirstChild("HumanoidRootPart")
	if root then
		root.Anchored = false
	end
	rig:ScaleTo(scale)
	rig.Parent = enemies
end

makeRig("Zombie", Color3.fromRGB(143, 193, 90), 1)
makeRig("Runner", Color3.fromRGB(111, 138, 74), 0.85)
makeRig("Tank", Color3.fromRGB(180, 80, 60), 1.4)
makeRig("Boss", Color3.fromRGB(90, 30, 110), 2.4)

print("Setup done: Plots (8), TownZone and ServerStorage.Enemies are ready.")
