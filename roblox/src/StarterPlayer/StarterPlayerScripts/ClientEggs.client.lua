--[[ ClientEggs  (LocalScript, put it in StarterPlayer > StarterPlayerScripts)
  Egg items in your backpack: equip one and click (or tap) a spot in your pen to place it there.
  While an egg is in your hand, a see-through egg shows where it will go.
  The server (EggService) checks that the spot is really in your pen before placing it.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local placeEgg = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("PlaceEgg")

-- the see-through preview egg
local ghost = Instance.new("Part")
ghost.Name = "EggPreview"
ghost.Size = Vector3.new(2.4, 3.2, 2.4)
ghost.Anchored = true
ghost.CanCollide = false
ghost.CanQuery = false
ghost.CanTouch = false
ghost.Transparency = 0.6
ghost.Material = Enum.Material.Neon
local mesh = Instance.new("SpecialMesh")
mesh.MeshType = Enum.MeshType.Sphere
mesh.Parent = ghost

local heldEgg = nil -- the egg Tool in your hand, if any

local function myPenArea()
	local plots = workspace:FindFirstChild("Plots")
	if not plots then
		return nil
	end
	for _, plot in ipairs(plots:GetChildren()) do
		if plot:GetAttribute("OwnerUserId") == player.UserId then
			return plot:FindFirstChild("PenArea")
		end
	end
	return nil
end

-- the spot under the mouse, and whether it is inside your pen (the server checks again)
local function targetSpot()
	local area = myPenArea()
	local hit = mouse.Hit
	if not area or not hit then
		return nil, false
	end
	local spot = area.CFrame:PointToObjectSpace(hit.Position)
	local inside = math.abs(spot.X) < area.Size.X / 2 - 1.2 and math.abs(spot.Z) < area.Size.Z / 2 - 1.2 and math.abs(spot.Y) < 6
	return hit.Position, inside, area
end

RunService.RenderStepped:Connect(function()
	if not heldEgg or not heldEgg.Parent then
		ghost.Parent = nil
		return
	end
	local position, inside, area = targetSpot()
	if position and area then
		local spot = area.CFrame:PointToObjectSpace(position)
		ghost.CFrame = area.CFrame * CFrame.new(spot.X, area.Size.Y / 2 + 1.6, spot.Z)
		ghost.Color = inside and Color3.fromRGB(111, 209, 111) or Color3.fromRGB(255, 90, 90)
		mouse.TargetFilter = ghost
		ghost.Parent = workspace
	else
		ghost.Parent = nil
	end
end)

local function hookTool(tool)
	if not tool:IsA("Tool") or not tool:GetAttribute("EggRarity") or tool:GetAttribute("EggHooked") then
		return
	end
	tool:SetAttribute("EggHooked", true)
	tool.Equipped:Connect(function()
		heldEgg = tool
	end)
	tool.Unequipped:Connect(function()
		if heldEgg == tool then
			heldEgg = nil
		end
	end)
	tool.Activated:Connect(function()
		local position = targetSpot()
		if position then
			placeEgg:FireServer(tool:GetAttribute("EggRarity"), position)
		end
	end)
end

local function watch(container)
	for _, child in ipairs(container:GetChildren()) do
		hookTool(child)
	end
	container.ChildAdded:Connect(hookTool)
end

player.CharacterAdded:Connect(watch)
if player.Character then
	watch(player.Character)
end
