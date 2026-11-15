--[[ ClientCombat  (LocalScript, put it in StarterPlayer > StarterPlayerScripts)
  When you click (or tap) with your weapon in hand, this tells the server which way you are aiming.
  The server (CombatService) checks the cooldown and works out the hits, so this script can't cheat.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local ContextActionService = game:GetService("ContextActionService")
local attack = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Attack")
local abilityRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Ability")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

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

-- ---------- ability: press Q (or Y on a controller, or the on-screen button on phones) ----------
local ABILITY_NAMES = { Knight = "Shield Slam", Wizard = "Blink Burst", Bowman = "Arrow Volley" }
local lastState = nil
local readyAt = 0

local function useAbility(_, inputState)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	if os.clock() < readyAt then
		return Enum.ContextActionResult.Sink
	end
	local level = lastState and lastState.upgrades and lastState.upgrades.ability or 0
	readyAt = os.clock() + Config.abilityCooldownSeconds(level)
	abilityRemote:FireServer(aimDirection(player.Character))
	return Enum.ContextActionResult.Sink
end

ContextActionService:BindAction("LootAbility", useAbility, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonY)
ContextActionService:SetTitle("LootAbility", "Ability")

-- show the ability name and its cooldown on the phone button
ReplicatedStorage.Remotes:WaitForChild("State").OnClientEvent:Connect(function(s)
	lastState = s
end)
task.spawn(function()
	while true do
		task.wait(0.25)
		local name = lastState and ABILITY_NAMES[lastState.class] or "Ability"
		local left = readyAt - os.clock()
		ContextActionService:SetTitle("LootAbility", left > 0 and tostring(math.ceil(left)) or name)
	end
end)
