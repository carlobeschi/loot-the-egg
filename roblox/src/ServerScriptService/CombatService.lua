--[[ CombatService  (ModuleScript, put it in ServerScriptService)
  Weapons for the three classes, worked out on the SERVER so nobody can cheat damage:
    Knight - sword: a wide swing that hits every enemy in front of you (reach grows with the weapon tier)
    Wizard - staff: a magic bolt that explodes and hurts everything near where it lands
    Bowman - bow:   a fast arrow that goes through several enemies (more at tiers 2, 4 and 8)
  The client (ClientCombat) only says "I attacked, aiming this way". The server checks the cooldown and does the rest.
  Numbers come from Config.Combat, which copies attack() and hurt() in the JS game.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("Config"))

local CombatService = {}
local DataService, DungeonService
local lastAttack = {} -- [Player] = os.clock() of their last attack
local projectiles = {} -- moving bolts and arrows
local projectileFolder

-- ---------- the weapon Tools (simple Part models, swap for real models later) ----------
local function weld(a, b)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
end

local function toolPart(tool, name, size, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.Massless = true
	p.Parent = tool
	return p
end

local function makeTool(className, tier)
	local info = Config.weaponInfo(className, tier)
	local color = Color3.fromHex(info.color)
	local tool = Instance.new("Tool")
	tool.Name = info.name
	tool.CanBeDropped = false
	tool.ToolTip = className .. " weapon, tier " .. tier
	tool:SetAttribute("WeaponClass", className)
	tool:SetAttribute("Tier", tier)
	local material = (tier >= 6) and Enum.Material.Neon or Enum.Material.Metal

	if className == "Knight" then
		-- the Handle is the grip; the blade points forward out of the hand
		local handle = toolPart(tool, "Handle", Vector3.new(0.35, 0.35, 1.2), Color3.fromRGB(90, 60, 35), Enum.Material.Wood)
		local blade = toolPart(tool, "Blade", Vector3.new(0.2, 0.6, 3.6), color, material)
		blade.CFrame = handle.CFrame * CFrame.new(0, 0, -2.4)
		local guard = toolPart(tool, "Guard", Vector3.new(0.3, 1.2, 0.3), Color3.fromRGB(200, 170, 80), Enum.Material.Metal)
		guard.CFrame = handle.CFrame * CFrame.new(0, 0, -0.6)
		weld(handle, blade)
		weld(handle, guard)
	elseif className == "Wizard" then
		local handle = toolPart(tool, "Handle", Vector3.new(0.3, 5, 0.3), Color3.fromRGB(110, 75, 45), Enum.Material.Wood)
		local orb = toolPart(tool, "Orb", Vector3.new(0.9, 0.9, 0.9), color, Enum.Material.Neon)
		orb.Shape = Enum.PartType.Ball
		orb.CFrame = handle.CFrame * CFrame.new(0, 2.8, 0)
		weld(handle, orb)
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 8
		light.Parent = orb
		tool.GripPos = Vector3.new(0, -0.5, 0)
	else
		local handle = toolPart(tool, "Handle", Vector3.new(0.3, 1, 0.3), Color3.fromRGB(90, 60, 35), Enum.Material.Wood)
		for _, side in ipairs({ -1, 1 }) do
			local limb = toolPart(tool, "Limb", Vector3.new(0.25, 2, 0.25), color, material)
			limb.CFrame = handle.CFrame * CFrame.new(0, side * 1.3, 0.35) * CFrame.Angles(math.rad(-20 * side), 0, 0)
			weld(handle, limb)
		end
		local string_ = toolPart(tool, "String", Vector3.new(0.05, 4.4, 0.05), Color3.new(1, 1, 1))
		string_.CFrame = handle.CFrame * CFrame.new(0, 0, 0.9)
		weld(handle, string_)
	end
	return tool
end

-- Gives the player the weapon for their class and current tier, and sets their health and speed.
function CombatService.Equip(player)
	local profile = DataService.Get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not profile or not humanoid then
		return
	end
	local className = profile.class
	local upgrades = profile.upgrades[className]
	humanoid.MaxHealth = Config.maxHealth(className, upgrades.health)
	humanoid.Health = humanoid.MaxHealth
	humanoid.WalkSpeed = Config.walkSpeed(className, upgrades.speed)

	-- remove old weapons (in the backpack and in the hand)
	for _, container in ipairs({ player:FindFirstChildOfClass("Backpack"), character }) do
		for _, item in ipairs(container and container:GetChildren() or {}) do
			if item:IsA("Tool") and item:GetAttribute("WeaponClass") then
				item:Destroy()
			end
		end
	end
	local tool = makeTool(className, profile.weaponTier[className] or 0)
	tool.Parent = player:FindFirstChildOfClass("Backpack")
	humanoid:EquipTool(tool)
end

-- ---------- hitting enemies ----------
local function damageFor(className, tier, base)
	return base * Config.weaponDamage(className, tier)
end

local function enemyRoots()
	local list = {}
	for _, enemy in ipairs(CollectionService:GetTagged("Enemy")) do
		local root = enemy:FindFirstChild("HumanoidRootPart")
		local humanoid = enemy:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 then
			-- an enemy's "radius" grows with the rig size (bosses are big)
			table.insert(list, { model = enemy, root = root, radius = math.max(root.Size.X, root.Size.Z) })
		end
	end
	return list
end

local function slashEffect(origin, direction, reach)
	local p = Instance.new("Part")
	p.Name = "Slash"
	p.Size = Vector3.new(reach * 1.6, 0.2, reach * 0.9)
	p.CFrame = CFrame.lookAt(origin, origin + direction) * CFrame.new(0, 0, -reach * 0.45)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(241, 234, 210)
	p.Transparency = 0.6
	p.Parent = projectileFolder
	Debris:AddItem(p, 0.15)
end

local function swordSwing(player, origin, direction, tier)
	local c = Config.Combat.Knight
	local reach = c.reach + c.reachPerTier * tier
	local cosArc = math.cos(c.arc)
	local damage = damageFor("Knight", tier, c.base)
	for _, e in ipairs(enemyRoots()) do
		local offset = e.root.Position - origin
		local flat = Vector3.new(offset.X, 0, offset.Z)
		local d = flat.Magnitude
		if d < reach + e.radius and math.abs(offset.Y) < Config.SameFloorHeight + e.radius then
			if d < c.closeRange or (d > 0 and flat.Unit:Dot(direction) > cosArc) then
				DungeonService.DamageEnemy(e.model, damage, player)
			end
		end
	end
	slashEffect(origin, direction, reach)
end

local function explode(player, position, tier)
	local c = Config.Combat.Wizard
	local radius = c.blastRadius + c.blastPerTier * tier
	local damage = damageFor("Wizard", tier, c.blastBase)
	for _, e in ipairs(enemyRoots()) do
		local offset = e.root.Position - position
		if Vector3.new(offset.X, 0, offset.Z).Magnitude < radius + e.radius and math.abs(offset.Y) < Config.SameFloorHeight + e.radius then
			DungeonService.DamageEnemy(e.model, damage, player)
		end
	end
	local blast = Instance.new("Part")
	blast.Name = "Blast"
	blast.Shape = Enum.PartType.Ball
	blast.Size = Vector3.one * radius * 2
	blast.Position = position
	blast.Anchored = true
	blast.CanCollide = false
	blast.CanQuery = false
	blast.CanTouch = false
	blast.Material = Enum.Material.Neon
	blast.Color = Color3.fromRGB(157, 143, 255)
	blast.Transparency = 0.7
	blast.Parent = projectileFolder
	Debris:AddItem(blast, 0.25)
end

local function launch(player, kind, origin, direction, tier, color)
	local c = (kind == "bolt") and Config.Combat.Wizard or Config.Combat.Bowman
	local p = Instance.new("Part")
	p.Name = (kind == "bolt") and "Bolt" or "Arrow"
	if kind == "bolt" then
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.one * 1.2
	else
		p.Size = Vector3.new(0.2, 0.2, 2.4)
	end
	p.CFrame = CFrame.lookAt(origin, origin + direction)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Parent = projectileFolder
	table.insert(projectiles, {
		part = p,
		kind = kind,
		player = player,
		tier = tier,
		position = origin,
		velocity = direction * c.speed,
		life = c.life,
		pierce = (kind == "arrow") and Config.arrowPierce(tier) or 1,
		hit = {},
	})
end

-- moves every bolt and arrow a little each frame, checking walls (raycast) and enemies (distance)
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function stepProjectiles(dt)
	if #projectiles == 0 then
		return
	end
	local exclude = { projectileFolder }
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	for _, enemy in ipairs(CollectionService:GetTagged("Enemy")) do
		table.insert(exclude, enemy)
	end
	rayParams.FilterDescendantsInstances = exclude
	local enemies = enemyRoots()

	for i = #projectiles, 1, -1 do
		local pr = projectiles[i]
		local step = pr.velocity * dt
		local from = pr.position
		local wall = workspace:Raycast(from, step, rayParams)
		local to = wall and wall.Position or (from + step)
		pr.position = to
		pr.life -= dt
		local dead = wall ~= nil or pr.life <= 0

		-- enemy hits along this step (checked at the end point, steps are short)
		for _, e in ipairs(enemies) do
			if dead and pr.kind == "bolt" then
				break
			end
			local offset = e.root.Position - to
			if not pr.hit[e.model] and Vector3.new(offset.X, 0, offset.Z).Magnitude < e.radius + 0.8 and math.abs(offset.Y) < Config.SameFloorHeight then
				pr.hit[e.model] = true
				if pr.kind == "bolt" then
					DungeonService.DamageEnemy(e.model, damageFor("Wizard", pr.tier, Config.Combat.Wizard.base), pr.player)
					dead = true
				else
					DungeonService.DamageEnemy(e.model, damageFor("Bowman", pr.tier, Config.Combat.Bowman.base), pr.player)
					pr.pierce -= 1
					if pr.pierce <= 0 then
						dead = true
						break
					end
				end
			end
		end

		if dead then
			if pr.kind == "bolt" then
				explode(pr.player, to, pr.tier)
			end
			pr.part:Destroy()
			table.remove(projectiles, i)
		else
			pr.part.CFrame = CFrame.lookAt(to, to + pr.velocity)
		end
	end
end

-- ---------- the Attack request from the client ----------
function CombatService.Attack(player, aim)
	local profile = DataService.Get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not profile or not humanoid or humanoid.Health <= 0 or not root then
		return
	end
	local className = profile.class
	local tool = character:FindFirstChildOfClass("Tool")
	if not tool or tool:GetAttribute("WeaponClass") ~= className then
		return -- weapon not in hand
	end
	local now = os.clock()
	if now - (lastAttack[player] or 0) < Config.Combat[className].cooldown * 0.9 then
		return -- too fast (a little slack for network timing)
	end
	lastAttack[player] = now

	-- aim: only the flat direction is used, like the JS game. Fall back to where the character faces.
	local direction = root.CFrame.LookVector
	if typeof(aim) == "Vector3" and aim.X == aim.X and aim.Z == aim.Z then
		local flat = Vector3.new(aim.X, 0, aim.Z)
		if flat.Magnitude > 0.01 then
			direction = flat.Unit
		end
	end
	direction = Vector3.new(direction.X, 0, direction.Z).Unit
	local tier = tool:GetAttribute("Tier") or 0
	local origin = root.Position

	if className == "Knight" then
		swordSwing(player, origin, direction, tier)
	elseif className == "Wizard" then
		launch(player, "bolt", origin + direction * (34 / 9), direction, tier, Color3.fromRGB(157, 143, 255))
	else
		launch(player, "arrow", origin + direction * (20 / 9), direction, tier, Color3.fromRGB(240, 220, 160))
	end
end

function CombatService.SetClass(player, className)
	local profile = DataService.Get(player)
	if not profile or not Config.Combat[className] or profile.class == className then
		return false
	end
	profile.class = className
	if player.Character then
		CombatService.Equip(player)
	end
	return true
end

function CombatService.Init(dataService, dungeonService)
	DataService = dataService
	DungeonService = dungeonService

	projectileFolder = Instance.new("Folder")
	projectileFolder.Name = "Projectiles"
	projectileFolder.Parent = workspace

	RunService.Heartbeat:Connect(stepProjectiles)
	Players.PlayerRemoving:Connect(function(player)
		lastAttack[player] = nil
	end)
end

return CombatService
