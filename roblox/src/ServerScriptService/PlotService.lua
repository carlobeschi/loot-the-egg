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

-- A simple pet built from Parts so everything works before you have real models.
-- Later: put your own models in ServerStorage.PetModels (named after the pet) and clone those instead.
local function makePet(def, rarity)
	local scale = PET_SCALE[rarity]
	local color = Color3.fromHex(def.color)
	local model = Instance.new("Model")
	model.Name = def.name

	local function part(size, shape, offset, col)
		local p = Instance.new("Part")
		p.Shape = shape
		p.Size = size * scale
		p.Color = col
		p.Material = (rarity >= 5) and Enum.Material.Neon or Enum.Material.SmoothPlastic
		p.CanCollide = false
		p.Massless = true
		p.Anchored = false
		p:SetAttribute("Offset", offset * scale)
		p.Parent = model
		return p
	end

	local body = part(Vector3.new(2.6, 2, 2), Enum.PartType.Ball, Vector3.zero, color)
	body.Name = "Body"
	body.Anchored = true
	local head = part(Vector3.new(1.7, 1.7, 1.7), Enum.PartType.Ball, Vector3.new(1.5, 0.9, 0), color)
	head.Name = "Head"
	local eyeL = part(Vector3.new(0.4, 0.4, 0.4), Enum.PartType.Ball, Vector3.new(2.2, 1.1, -0.45), Color3.new(0, 0, 0))
	local eyeR = part(Vector3.new(0.4, 0.4, 0.4), Enum.PartType.Ball, Vector3.new(2.2, 1.1, 0.45), Color3.new(0, 0, 0))
	local extra = { head, eyeL, eyeR }

	if def.wings and def.wings > 0 then
		local accent = Color3.fromHex(def.accent)
		for _, side in ipairs({ -1, 1 }) do
			local wing = part(Vector3.new(1.6, 0.2, 2.2), Enum.PartType.Block, Vector3.new(-0.2, 0.9, side * 1.8), accent)
			table.insert(extra, wing)
		end
	end

	model.PrimaryPart = body
	return model, body, extra
end

local function placeAndWeld(body, extra, cframe)
	body.CFrame = cframe
	for _, p in ipairs(extra) do
		p.CFrame = cframe * CFrame.new(p:GetAttribute("Offset"))
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = p
		weld.Parent = body
	end
end

local function randomPointIn(area, y)
	local sx, sz = area.Size.X / 2 - 3, area.Size.Z / 2 - 3
	local p = area.CFrame:PointToWorldSpace(Vector3.new(rng:NextNumber(-sx, sx), 0, rng:NextNumber(-sz, sz)))
	return Vector3.new(p.X, y, p.Z)
end

local function wander(model, body, area)
	task.spawn(function()
		while model.Parent and body.Parent do
			task.wait(rng:NextNumber(1, 4))
			if not (model.Parent and body.Parent) then
				break
			end
			local target = randomPointIn(area, body.Position.Y)
			local flat = target - body.Position
			if flat.Magnitude > 0.5 then
				local look = CFrame.lookAt(target, target + flat.Unit)
				local tween = TweenService:Create(body, TweenInfo.new(flat.Magnitude / 4, Enum.EasingStyle.Linear), { CFrame = look })
				tween:Play()
				tween.Completed:Wait()
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
		local model, body, extra = makePet(def, pet.rarity)
		local start = randomPointIn(area, area.Position.Y + area.Size.Y / 2 + 1.1 * PET_SCALE[pet.rarity])
		placeAndWeld(body, extra, CFrame.new(start))
		model.Parent = folder
		wander(model, body, area)
	end
end

return PlotService
