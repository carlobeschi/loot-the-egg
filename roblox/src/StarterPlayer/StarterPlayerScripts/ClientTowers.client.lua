--[[ ClientTowers  (LocalScript, put it in StarterPlayer > StarterPlayerScripts)
  Each dungeon's door has a Gate. On YOUR screen it is a solid red force field while the dungeon is locked
  for you, and a faint green one you can walk through once it is open. (A Part changed by a LocalScript only
  changes on this player's screen, and your own character's physics runs here, so the red gate blocks you
  without blocking anyone else.) The server checks again at the door, so this is only for show and comfort.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local state = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("State")

local function unlocked(s, depth, world)
	if world == 2 then
		return s.world2 and (s.bestDepth2 or 0) >= depth - 10
	end
	return (s.bestDepth or 0) >= depth - 1
end

state.OnClientEvent:Connect(function(s)
	local towers = workspace:FindFirstChild("Towers")
	if not towers then
		return
	end
	for _, tower in ipairs(towers:GetChildren()) do
		local gate = tower:FindFirstChild("Gate")
		local depth = tower:GetAttribute("Depth")
		if gate and depth then
			local open = unlocked(s, depth, tower:GetAttribute("World") or 1)
			gate.CanCollide = not open
			gate.Color = open and Color3.fromRGB(111, 209, 111) or Color3.fromRGB(255, 80, 80)
			gate.Transparency = open and 0.85 or 0.3
		end
	end
end)
