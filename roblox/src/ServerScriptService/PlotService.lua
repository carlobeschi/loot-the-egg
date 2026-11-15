--[[ PlotService  (ModuleScript, put it in ServerScriptService)
  Gives every player their own plot with a pen, builds the pen's look from its upgrade level, and spawns the
  player's equipped pets inside it.

  Your map needs a Folder named "Plots" in Workspace. Inside it make one Model per plot (Plot1, Plot2, ...).
  Each plot Model needs these parts (names matter):
    PenArea   - a flat Part covering the inside of the pen (pets wander inside it)
    Spawn     - a Part where the owner appears
    Fence     - a Model or Folder holding all the fence Parts (they get recolored on each pen upgrade)
    CollectPad (optional) - a Part players walk onto to collect pet earnings
    Sign      (optional) - holds a SurfaceGui with a TextLabel named "SignText"
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local PetModels = require(script.Parent:WaitForChild("PetModels"))
local Data = Config.Data

local PlotService = {}
local owners = {} -- [plotModel] = Player or false
local plotOf = {} -- [Player] = plotModel
local rng = Random.new()

local PET_SCALE = { 0.9, 1, 1.15, 1.35, 1.6, 1.8, 2, 2.3 } -- bigger pets for rarer rarities

local function setSign(plot, text)
	local label = plot:FindFirstChild("SignText", true)
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
end

function PlotService.Init()
	local folder = workspace:WaitForChild("Plots", 10)
	if not folder then
		warn("[PlotService] no Folder named Plots in Workspace. Run studio-tools/SetupTestPlace.lua in the Command Bar.")
		return
	end
	for _, plot in ipairs(folder:GetChildren()) do
		if plot:IsA("Model") then
			-- for the minimap (far plots aren't streamed to the client, their Model and its attributes are)
			local cframe, size = plot:GetBoundingBox()
			plot:SetAttribute("Center", cframe.Position)
			plot:SetAttribute("Extent", Vector3.new(size.X, 0, size.Z))
			owners[plot] = false
			setSign(plot, "Open Plot")
		end
	end
end

function PlotService.Assign(player)
	for plot, owner in pairs(owners) do
		if owner == false then
			owners[plot] = player
			plotOf[player] = plot
			plot:SetAttribute("OwnerUserId", player.UserId)
			setSign(plot, player.DisplayName .. "'s Pen")
			return plot
		end
	end
	return nil -- server is full: send the player to another server or show a message
end

function PlotService.Release(player)
	local plot = plotOf[player]
	if not plot then
		return
	end
	for _, name in ipairs({ "Pets", "PlacedEggs" }) do
		local folder = plot:FindFirstChild(name)
		if folder then
			folder:ClearAllChildren()
		end
	end
	plot:SetAttribute("OwnerUserId", nil)
	setSign(plot, "Open Plot")
	owners[plot] = false
	plotOf[player] = nil
end

function PlotService.GetPlot(player)
	return plotOf[player]
end

function PlotService.TeleportToPlot(player)
	local plot = plotOf[player]
	local character = player.Character
	local spawnPart = plot and plot:FindFirstChild("Spawn")
	if character and spawnPart then
		character:PivotTo(spawnPart.CFrame + Vector3.new(0, 4, 0))
	end
end

-- Recolors the fence for the pen level (0 = wooden ... 9 = rainbow). Level 3+ glows.
function PlotService.ApplyPenStyle(player, level)
	local plot = plotOf[player]
	local fence = plot and plot:FindFirstChild("Fence")
	if not fence then
		return
	end
	local color = Color3.fromHex(Data.pen.colors[level + 1])
	for _, part in ipairs(fence:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Color = color
			part.Material = (level >= 3) and Enum.Material.Neon or Enum.Material.Wood
		end
	end
end

local function placeAndWeld(root, parts, cframe)
	root.CFrame = cframe
	for _, p in ipairs(parts) do
		p.CFrame = cframe * p:GetAttribute("Offset")
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = p
		weld.Parent = p
	end
end

local function randomPointIn(area, y)
	local sx, sz = area.Size.X / 2 - 3, area.Size.Z / 2 - 3
	local p = area.CFrame:PointToWorldSpace(Vector3.new(rng:NextNumber(-sx, sx), 0, rng:NextNumber(-sz, sz)))
	return Vector3.new(p.X, y, p.Z)
end

local function move(root, cframe, seconds, style, direction)
	TweenService:Create(root, TweenInfo.new(seconds, style or Enum.EasingStyle.Linear, direction or Enum.EasingDirection.Out), { CFrame = cframe }):Play()
	task.wait(seconds)
end

-- The pet walks about its pen: it turns toward a spot, then trots there in little bouncy steps (bunnies and
-- chicks hop). Flying pets glide there instead, bobbing up and down in the air.
local function wander(model, root, area, info, scale)
	task.spawn(function()
		local baseY = root.Position.Y
		local alive = function()
			return model.Parent ~= nil and root.Parent ~= nil
		end
		while alive() do
			-- rest a moment (flyers bob in place)
			if info.fly then
				for _ = 1, rng:NextInteger(1, 3) do
					move(root, root.CFrame + Vector3.new(0, 0.35 * scale, 0), 0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
					move(root, root.CFrame - Vector3.new(0, 0.35 * scale, 0), 0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
				end
			else
				task.wait(rng:NextNumber(1, 4))
			end
			if not alive() then
				break
			end
			local here = root.Position
			local target = randomPointIn(area, baseY)
			local flat = target - Vector3.new(here.X, baseY, here.Z)
			if flat.Magnitude > 1 then
				-- turn to face the way it is going
				move(root, CFrame.lookAt(here, here + flat.Unit), 0.35, Enum.EasingStyle.Sine)
				if info.fly then
					move(root, CFrame.lookAt(target, target + flat.Unit), flat.Magnitude / 6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
				else
					local stride = (info.hop and 1.1 or 0.7) * scale
					local lift = (info.hop and 0.6 or 0.15) * scale
					local stepTime = info.hop and 0.32 or 0.2
					local steps = math.max(1, math.floor(flat.Magnitude / stride))
					local start = Vector3.new(here.X, baseY, here.Z)
					for i = 1, steps do
						if not alive() then
							return
						end
						local a = start + flat * ((i - 0.5) / steps) + Vector3.new(0, lift, 0)
						local b = start + flat * (i / steps)
						move(root, CFrame.lookAt(a, a + flat.Unit), stepTime / 2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
						move(root, CFrame.lookAt(b, b + flat.Unit), stepTime / 2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
					end
					if info.hop then
						task.wait(0.15)
					end
				end
			end
		end
	end)
end

-- Rebuilds the pets inside the owner's pen from their saved equipped list.
function PlotService.RefreshPets(player, profile)
	local plot = plotOf[player]
	if not plot then
		return
	end
	local area = plot:FindFirstChild("PenArea")
	if not area then
		warn("[PlotService] plot " .. plot.Name .. " has no part named PenArea")
		return
	end
	local folder = plot:FindFirstChild("Pets")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Pets"
		folder.Parent = plot
	end
	folder:ClearAllChildren()

	for _, pet in ipairs(profile.pets) do
		local def = Data.pets[pet.rarity][pet.kind]
		local scale = PET_SCALE[pet.rarity]
		local model, root, parts, info = PetModels.Build(def, pet.rarity, scale)
		local height = info.ground + (info.fly and 1.6 * scale or 0) -- flyers float above the grass
		local start = randomPointIn(area, area.Position.Y + area.Size.Y / 2 + height)
		placeAndWeld(root, parts, CFrame.new(start) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
		model.Parent = folder
		wander(model, root, area, info, scale)
	end
end

return PlotService
