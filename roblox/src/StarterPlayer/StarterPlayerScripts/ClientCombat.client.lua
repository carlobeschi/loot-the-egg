--[[ ClientCombat  (LocalScript, put it in StarterPlayer > StarterPlayerScripts)
  When you click (or tap) with your weapon in hand, this tells the server which way you are aiming.
  The server (CombatService) checks the cooldown and works out the hits, so this script can't cheat.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local attack = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Attack")

local function aimDirection(character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	-- aim at the point under the mouse (or your tap); if that is too close, aim where you face
	local target = mouse.Hit and mouse.Hit.Position
	if target then
		local flat = Vector3.new(target.X - root.Position.X, 0, target.Z - root.Position.Z)
		if flat.Magnitude > 1 then
			return flat.Unit
		end
	end
	return root.CFrame.LookVector
end

local function hookTool(tool)
	if not tool:IsA("Tool") or tool:GetAttribute("Hooked") or not tool:GetAttribute("WeaponClass") then
		return
	end
	tool:SetAttribute("Hooked", true)
	tool.Activated:Connect(function()
		attack:FireServer(aimDirection(player.Character))
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
