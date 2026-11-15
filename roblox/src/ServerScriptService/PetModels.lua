--[[ PetModels  (ModuleScript, put it in ServerScriptService)
  Builds the 16 pets out of Parts so they look like real little animals: a chick with a beak and orange legs,
  a piglet with a snout and a curly tail, a fox with a bushy white-tipped tail, dragons with bat wings and
  spikes, and so on. PlotService calls PetModels.Build and puts the result in the pen.

  How a pet is put together:
    - an invisible "Root" Part in the middle of the body. It is Anchored, and moving it moves the whole pet.
    - every other Part is welded to the Root. Its place is kept in the attribute "Offset" (a CFrame from the
      Root), so PlotService can put the pet anywhere and weld it.
    - pets face -Z (their front), like Roblox characters, so CFrame.lookAt makes them walk forward.
    - round shapes are Parts with a sphere mesh, so they can be ovals (a Ball Part is always perfectly round).
  All sizes below are for a pet of scale 1 (about 2 studs long). Rarer pets are built bigger.

  To use your own models later: put a Model named after the pet in ServerStorage.PetModels and change Build
  to clone it.
]]
local PetModels = {}

local V = Vector3.new
local C = CFrame.new
local A = CFrame.Angles
local rad = math.rad

local BLACK = Color3.fromRGB(28, 22, 22)
local WHITE = Color3.new(1, 1, 1)
local FUR = Enum.Material.Fabric -- soft and fuzzy up close
local SMOOTH = Enum.Material.SmoothPlastic
local GLOW = Enum.Material.Neon

local function darker(c, t)
	return c:Lerp(Color3.new(0, 0, 0), t or 0.3)
end
local function lighter(c, t)
	return c:Lerp(WHITE, t or 0.5)
end

-- ---------- the kit: adds welded parts to the pet being built ----------
local Kit = {}
Kit.__index = Kit

local function newKit(name, scale, material)
	local kit = setmetatable({ parts = {}, scale = scale, material = material, ground = 1, fly = false, hop = false, effectsAt = {} }, Kit)
	kit.model = Instance.new("Model")
	kit.model.Name = name
	return kit
end

function Kit:add(className, size, cframe, color, material)
	local p = Instance.new(className)
	p.Size = size * self.scale
	p.Color = color
	p.Material = material or self.material
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p:SetAttribute("Offset", C(cframe.Position * self.scale) * cframe.Rotation)
	p.Parent = self.model
	table.insert(self.parts, p)
	return p
end

-- an oval (sphere mesh stretched to the part's size)
function Kit:oval(size, cframe, color, material)
	local p = self:add("Part", size, cframe, color, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- a long oval from point a to point b (legs, necks, tails, horns)
function Kit:seg(a, b, thick, color, material)
	local dir = b - a
	local up = math.abs(dir.Unit.Y) > 0.95 and Vector3.zAxis or Vector3.yAxis
	return self:oval(V(thick, thick, dir.Magnitude + thick * 0.5), CFrame.lookAt((a + b) / 2, b, up), color, material)
end

-- a square turned 45 degrees: half hidden in the head it makes a pointy ear, on the back a spike
function Kit:diamond(width, thick, cframe, color, material)
	return self:add("Part", V(width, width, thick), cframe * A(0, 0, rad(45)), color, material)
end

-- black shiny eyes with a little white sparkle. x = distance from the middle, y and z = where they sit.
function Kit:eyes(x, y, z, size)
	for _, s in ipairs({ -1, 1 }) do
		self:oval(V(size, size * 1.1, size * 0.7), C(s * x, y, z), BLACK, SMOOTH)
		self:oval(V(size * 0.32, size * 0.32, size * 0.2), C(s * x + s * size * 0.12, y + size * 0.22, z - size * 0.3), WHITE, GLOW)
	end
end

-- a wing made of feathers fanning out from the shoulder.
-- tilt lifts the wing up (flying) or lets it hang; sweep turns it back along the body (folded).
function Kit:featherWing(side, shoulder, length, tilt, sweep, color, tipColor, count)
	count = count or 5
	local frame = C(shoulder) * A(0, -side * sweep, 0) * A(0, 0, side * tilt)
	self:oval(V(length * 0.6, 0.16, 0.7), frame * C(side * length * 0.28, 0.05, 0.12), color)
	for i = 0, count - 1 do
		local a = rad(4 + i * 70 / (count - 1))
		local len = length * (1 - i * 0.1)
		local dir = V(side * math.cos(a), 0, math.sin(a))
		self:oval(V(len, 0.08, 0.3), frame * C(dir * len / 2) * A(0, -side * a, 0), color:Lerp(tipColor, (count - i) / count))
	end
end

-- a bat wing: a bone along the front and a skin triangle behind it
function Kit:batWing(side, shoulder, span, chord, tilt, skinColor, boneColor)
	local frame = C(shoulder) * A(0, -side * rad(10), 0) * A(0, 0, side * tilt)
	-- a WedgePart is a right triangle seen from the side; turn it so the triangle lies flat with its square
	-- corner at the shoulder: front edge out along the wing bone, inner edge back along the body
	local flat = CFrame.fromMatrix(Vector3.zero, V(0, side, 0), V(side, 0, 0), V(0, 0, -1))
	self:add("WedgePart", V(0.06, span, chord), frame * C(side * span / 2, 0, chord / 2) * flat, skinColor, SMOOTH)
	self:add("WedgePart", V(0.06, span * 0.55, chord * 1.35), frame * C(side * span * 0.275, -0.01, chord * 0.675) * flat, skinColor, SMOOTH)
	self:seg((frame * C(0, 0, 0)).Position, (frame * C(side * span, 0, 0)).Position, 0.13, boneColor, SMOOTH)
	self:oval(V(0.14, 0.14, 0.22), frame * C(side * span, 0, -0.08), WHITE, SMOOTH) -- the little claw at the tip
end

-- a ring of glowing beads floating over the head
function Kit:halo(center, radius, color)
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		self:oval(V(0.14, 0.14, 0.14), C(center + V(math.cos(a) * radius, 0, math.sin(a) * radius)), color, GLOW)
	end
end

-- four legs with paws (or hooves). feetY = how far below the middle the feet are.
function Kit:legs(hipX, hipY, frontZ, backZ, feetY, thick, color, pawColor)
	for _, z in ipairs({ frontZ, backZ }) do
		for _, s in ipairs({ -1, 1 }) do
			self:seg(V(s * hipX, hipY, z), V(s * hipX, feetY + thick * 0.3, z), thick, color)
			self:oval(V(thick * 1.15, thick * 0.6, thick * 1.35), C(s * hipX, feetY + thick * 0.3, z - thick * 0.15), pawColor or color)
		end
	end
	self.ground = -feetY
end

-- ---------- body plans ----------

-- a furry four-legged animal. o = the measurements and the bits that make each one different.
local function mammal(kit, o)
	local b, h = o.body, o.head
	kit:oval(b, C(0, 0, 0), o.color).Name = "Body"
	if o.belly then
		kit:oval(V(b.X * 0.8, b.Y * 0.7, b.Z * 0.8), C(0, -b.Y * 0.16, -b.Z * 0.06), o.belly)
	end
	local hp = o.headPos
	if o.neck then
		kit:seg(V(0, b.Y * 0.2, -b.Z * 0.35), hp + V(0, -h.Y * 0.1, h.Z * 0.15), h.X * 0.62, o.color)
	end
	kit:oval(h, C(hp), o.color).Name = "Head"
	-- muzzle and nose
	local front = hp.Z - h.Z * 0.45
	if o.muzzle then
		kit:oval(o.muzzle, C(0, hp.Y - h.Y * 0.18, front), o.muzzleColor or o.color)
		front -= o.muzzle.Z * 0.5
	end
	if o.nose ~= false then
		kit:oval(V(0.22, 0.15, 0.14), C(0, hp.Y - h.Y * (o.muzzle and 0.08 or 0.1), front), o.nose or BLACK, SMOOTH)
	end
	kit:eyes(h.X * 0.25, hp.Y + h.Y * 0.14, hp.Z - h.Z * 0.37, h.X * 0.19)
	-- ears
	for _, s in ipairs({ -1, 1 }) do
		if o.ears == "point" then
			local cf = C(hp + V(s * h.X * 0.3, h.Y * 0.38, h.Z * 0.05)) * A(0, 0, -s * rad(16))
			kit:diamond(h.X * 0.4, 0.12, cf, o.earColor or o.color)
			kit:diamond(h.X * 0.25, 0.06, cf * C(0, -0.02, -0.06), o.earInner or lighter(o.color, 0.4))
		elseif o.ears == "long" then
			local cf = C(hp + V(s * h.X * 0.2, h.Y * 0.5 + 0.55, h.Z * 0.15)) * A(rad(-12), 0, -s * rad(12))
			kit:oval(V(0.32, 1.3, 0.16), cf, o.color)
			kit:oval(V(0.18, 1.0, 0.06), cf * C(0, 0, -0.07), o.earInner, SMOOTH)
		elseif o.ears == "flop" then
			kit:oval(V(0.45, 0.14, 0.42), C(hp + V(s * h.X * 0.36, h.Y * 0.4, -h.Z * 0.05)) * A(rad(25), 0, -s * rad(30)), o.earColor or o.color)
		elseif o.ears == "round" then
			kit:oval(V(0.34, 0.34, 0.12), C(hp + V(s * h.X * 0.36, h.Y * 0.38, h.Z * 0.1)), o.earColor or o.color)
		elseif o.ears == "pony" then
			local cf = C(hp + V(s * h.X * 0.26, h.Y * 0.45, h.Z * 0.2)) * A(0, 0, -s * rad(10))
			kit:oval(V(0.2, 0.5, 0.14), cf, o.color)
		end
	end
	-- legs
	local feetY = -b.Y / 2 - o.legLen
	kit:legs(b.X * 0.28, -b.Y * 0.15, -b.Z * 0.3, b.Z * 0.3, feetY, o.legThick, o.color, o.paws)
	return V(0, b.Y * 0.1, b.Z * 0.48) -- where the tail starts
end

-- tails, starting at point t on the back of the body
local function bushyTail(kit, t, color, tip, yaw, length)
	length = length or 1.4
	local dir = (A(0, yaw or 0, 0) * A(rad(-40), 0, 0)).LookVector * -1 -- back and up
	local cf = CFrame.lookAt(t + dir * length * 0.4, t + dir * length)
	kit:oval(V(0.55, 0.55, length), cf, color)
	kit:oval(V(0.42, 0.42, length * 0.38), C(t + dir * length * 0.85) * cf.Rotation, tip)
end

local function dragonTail(kit, t, color, spadeColor, length)
	local p0, p1 = t, t + V(0, 0.15, 0.6 * length)
	local p2 = p1 + V(0, 0.1, 0.6 * length)
	local p3 = p2 + V(0.25, 0.3, 0.45 * length)
	kit:seg(p0, p1, 0.5, color)
	kit:seg(p1, p2, 0.36, color)
	kit:seg(p2, p3, 0.24, color)
	kit:diamond(0.5, 0.08, CFrame.lookAt(p3, p3 + (p3 - p2)) * A(0, rad(90), 0), spadeColor)
end

-- spikes down the middle of the back (spikes = how many)
local function backSpikes(kit, fromZ, toZ, y, count, color)
	for i = 0, count - 1 do
		local z = fromZ + (toZ - fromZ) * i / math.max(1, count - 1)
		kit:add("Part", V(0.08, 0.32, 0.32), C(0, y(z), z) * A(rad(45), 0, 0), color, SMOOTH)
	end
end

-- a little bird. o.bill = true for a duck's flat bill instead of a pointed beak.
local function bird(kit, o)
	local b = o.body
	kit:oval(b, C(0, 0, 0), o.color).Name = "Body"
	if o.belly then
		kit:oval(V(b.X * 0.82, b.Y * 0.7, b.Z * 0.75), C(0, -b.Y * 0.16, -b.Z * 0.1), o.belly)
	end
	local hp, hs = o.headPos, o.headSize
	kit:oval(V(hs, hs, hs), C(hp), o.headColor or o.color).Name = "Head"
	if o.bill then
		kit:oval(V(hs * 0.5, hs * 0.13, hs * 0.55), C(hp + V(0, -hs * 0.12, -hs * 0.58)), o.beak, SMOOTH)
	else
		-- a wedge's thin edge points forward and down, like a beak
		kit:add("WedgePart", V(hs * 0.22, hs * 0.2, hs * 0.38), C(hp + V(0, -hs * 0.02, -hs * 0.6)), o.beak, SMOOTH)
		kit:add("WedgePart", V(hs * 0.18, hs * 0.1, hs * 0.26), C(hp + V(0, -hs * 0.14, -hs * 0.56)) * A(rad(180), 0, 0) * A(0, rad(180), 0), darker(o.beak, 0.15), SMOOTH)
	end
	kit:eyes(hs * 0.27, hp.Y + hs * 0.1, hp.Z - hs * 0.36, hs * 0.18)
	-- legs with three toes each
	local legLen = o.legLen or 0.35
	local feetY = -b.Y / 2 - legLen + 0.05
	for _, s in ipairs({ -1, 1 }) do
		local x = s * b.X * 0.22
		kit:seg(V(x, -b.Y * 0.35, 0.05), V(x, feetY, 0), 0.11, o.feet, SMOOTH)
		for _, a in ipairs({ -30, 0, 30 }) do
			local dir = A(0, rad(a), 0).LookVector
			kit:oval(o.webbed and V(0.16, 0.05, 0.32) or V(0.07, 0.05, 0.3), CFrame.lookAt(V(x, feetY, 0) + dir * 0.14, V(x, feetY, 0) + dir), o.feet, SMOOTH)
		end
	end
	kit.ground = -feetY + 0.03
end

-- a dragon: scales, horns, spikes, a long tail with a spade at the end
local function dragon(kit, o)
	local col, acc = o.color, o.accent
	local b = o.body or V(1.4, 1.25, 2.3)
	kit:oval(b, C(0, 0, 0), col).Name = "Body"
	kit:oval(V(b.X * 0.78, b.Y * 0.7, b.Z * 0.8), C(0, -b.Y * 0.17, -b.Z * 0.05), o.belly or lighter(col, 0.55))
	local hp = V(0, b.Y * 0.62, -b.Z * 0.55)
	kit:seg(V(0, b.Y * 0.15, -b.Z * 0.35), hp + V(0, -0.1, 0.2), 0.62, col)
	kit:oval(V(1.0, 0.9, 1.05), C(hp), col).Name = "Head"
	kit:oval(V(0.72, 0.5, 0.75), C(hp + V(0, -0.15, -0.55)), col) -- snout
	for _, s in ipairs({ -1, 1 }) do
		kit:oval(V(0.08, 0.06, 0.06), C(hp + V(s * 0.14, -0.05, -0.92)), BLACK, SMOOTH) -- nostrils
		-- horns sweep back
		local root = hp + V(s * 0.24, 0.36, 0.2)
		kit:seg(root, root + V(s * 0.08, 0.28, 0.32), 0.15, o.horns or lighter(acc, 0.6), SMOOTH)
		kit:seg(root + V(s * 0.08, 0.28, 0.32), root + V(s * 0.1, 0.36, 0.6), 0.08, o.horns or lighter(acc, 0.6), SMOOTH)
	end
	kit:eyes(0.27, hp.Y + 0.14, hp.Z - 0.36, 0.2)
	backSpikes(kit, -b.Z * 0.35, b.Z * 0.45, function(z)
		return b.Y * 0.5 * math.sqrt(math.max(0, 1 - (z / (b.Z * 0.5)) ^ 2)) + 0.04
	end, 5, acc)
	backSpikes(kit, hp.Z - 0.1, hp.Z + 0.35, function()
		return hp.Y + 0.42
	end, 2, acc)
	local feetY = -b.Y / 2 - (o.legLen or 0.45)
	if o.twoLegs then -- a wyvern: only back legs
		for _, s in ipairs({ -1, 1 }) do
			kit:seg(V(s * b.X * 0.3, -b.Y * 0.1, b.Z * 0.25), V(s * b.X * 0.3, feetY + 0.12, b.Z * 0.22), 0.36, col)
			kit:oval(V(0.42, 0.22, 0.55), C(s * b.X * 0.3, feetY + 0.11, b.Z * 0.15), darker(col, 0.2))
		end
		kit.ground = -feetY
	else
		kit:legs(b.X * 0.3, -b.Y * 0.1, -b.Z * 0.28, b.Z * 0.28, feetY, 0.36, col, darker(col, 0.2))
	end
	dragonTail(kit, V(0, 0, b.Z * 0.45), col, acc, o.tailLength or 1)
	local shoulder = V(0, b.Y * 0.35, -b.Z * 0.15)
	for _, s in ipairs({ -1, 1 }) do
		local sh = shoulder + V(s * b.X * 0.3, 0, 0)
		if o.feathers then
			kit:featherWing(s, sh, o.wingSpan or 2.2, rad(o.wingTilt or 25), rad(o.wingSweep or 0), WHITE, o.featherTip or lighter(acc, 0.3), 6)
		else
			kit:batWing(s, sh, o.wingSpan or 1.4, o.wingChord or 1.1, rad(o.wingTilt or 35), lighter(acc, 0.15), darker(col, 0.15))
		end
	end
end

-- a phoenix: a fire bird with a crest and long tail feathers
local function phoenix(kit, o)
	bird(kit, {
		body = V(1.2, 1.15, 1.7),
		color = o.color,
		belly = o.belly,
		headPos = V(0, 0.72, -0.72),
		headSize = 0.9,
		beak = o.beak,
		feet = o.feet,
		legLen = 0.3,
	})
	-- crest: three feathers on the head
	for i, a in ipairs({ -18, 0, 18 }) do
		local base = V(0, 1.12, -0.7 + i * 0.05)
		kit:seg(base, base + V(math.sin(rad(a)) * 0.3, 0.45 + (i == 2 and 0.15 or 0), 0.35), 0.12, o.accent)
	end
	-- long tail feathers fanning out behind
	for i = -2, 2 do
		local a = rad(i * 14)
		local start = V(0, 0.1, 0.75)
		local tip = start + V(math.sin(a) * 1.7, -0.25 - math.abs(i) * 0.08, math.cos(a) * 1.7)
		kit:seg(start, tip, 0.22, o.color:Lerp(o.accent, 0.4 + math.abs(i) * 0.15))
		kit:oval(V(0.32, 0.12, 0.45), C(tip) * A(0, a, 0), o.accent)
	end
	for _, s in ipairs({ -1, 1 }) do
		kit:featherWing(s, V(s * 0.45, 0.3, -0.2), 2.3, rad(28), rad(5), o.color, o.accent, 6)
	end
end

-- ---------- the 16 pets ----------
local SPECIES = {}

SPECIES["Chick"] = function(kit, col, acc)
	kit.material = FUR
	kit.hop = true
	bird(kit, { body = V(1.3, 1.25, 1.35), color = col, headPos = V(0, 0.78, -0.32), headSize = 0.98, beak = acc, feet = acc })
	for _, s in ipairs({ -1, 1 }) do
		kit:oval(V(0.16, 0.55, 0.75), C(s * 0.62, 0.05, 0.08) * A(rad(-15), 0, s * rad(8)), darker(col, 0.08))
	end
	kit:seg(V(0, 1.2, -0.3), V(0.05, 1.45, -0.42), 0.12, col) -- fluffy tuft
	kit:seg(V(0, 1.2, -0.3), V(-0.08, 1.4, -0.2), 0.1, col)
end

SPECIES["Duckling"] = function(kit, col, acc)
	kit.material = FUR
	bird(kit, { body = V(1.25, 1.05, 1.75), color = col, headPos = V(0, 0.75, -0.6), headSize = 0.92, beak = acc, bill = true, feet = acc, webbed = true })
	kit:add("WedgePart", V(0.5, 0.4, 0.45), C(0, 0.25, 0.85) * A(0, rad(180), 0), col) -- tail pointing up
	for _, s in ipairs({ -1, 1 }) do
		kit:oval(V(0.16, 0.5, 0.95), C(s * 0.58, 0.08, 0.12) * A(rad(-10), 0, s * rad(8)), darker(col, 0.08))
	end
end

SPECIES["Piglet"] = function(kit, col, acc)
	kit.material = SMOOTH
	local tail = mammal(kit, {
		body = V(1.55, 1.35, 2.05),
		color = col,
		head = V(1.2, 1.1, 1.05),
		headPos = V(0, 0.38, -1.05),
		ears = "flop",
		earColor = acc,
		nose = false,
		legLen = 0.32,
		legThick = 0.36,
		paws = darker(acc, 0.25),
	})
	-- the snout: a flat disc with two nostrils
	local snout = V(0, 0.22, -1.62)
	kit:add("Part", V(0.2, 0.5, 0.5), C(snout) * A(0, rad(90), 0), acc).Shape = Enum.PartType.Cylinder
	for _, s in ipairs({ -1, 1 }) do
		kit:oval(V(0.1, 0.14, 0.06), C(snout + V(s * 0.1, 0, -0.1)), darker(acc, 0.5), SMOOTH)
	end
	-- the curly tail
	for i = 0, 4 do
		local a = i * 1.4
		kit:oval(V(0.13, 0.13, 0.13), C(tail + V(math.cos(a) * 0.13, 0.12 + math.sin(a) * 0.13, 0.08 + i * 0.04)), acc)
	end
end

SPECIES["Bunny"] = function(kit, col, acc)
	kit.material = FUR
	kit.hop = true
	local b = V(1.35, 1.3, 1.6)
	kit:oval(b, C(0, 0, 0.05), col).Name = "Body"
	local hp = V(0, 0.68, -0.68)
	kit:oval(V(1.0, 0.92, 0.95), C(hp), col).Name = "Head"
	kit:oval(V(0.55, 0.4, 0.35), C(hp + V(0, -0.18, -0.38)), lighter(col, 0.6)) -- cheeks
	kit:oval(V(0.16, 0.12, 0.1), C(hp + V(0, -0.08, -0.56)), acc, SMOOTH)
	kit:eyes(0.26, hp.Y + 0.12, hp.Z - 0.33, 0.2)
	for _, s in ipairs({ -1, 1 }) do
		local cf = C(hp + V(s * 0.2, 0.95, 0.12)) * A(rad(-12), 0, -s * rad(10))
		kit:oval(V(0.32, 1.25, 0.16), cf, col)
		kit:oval(V(0.18, 0.95, 0.06), cf * C(0, 0, -0.07), acc, SMOOTH)
		kit:oval(V(0.42, 0.28, 0.85), C(s * 0.42, -0.68, 0.2), col) -- big back feet
		kit:seg(V(s * 0.3, -0.2, -0.45), V(s * 0.3, -0.7, -0.55), 0.24, col) -- front legs
	end
	kit:oval(V(0.5, 0.5, 0.45), C(0, 0.0, 0.85), WHITE) -- cotton tail
	kit.ground = 0.82
end

local function foxLike(kit, col, acc, o)
	kit.material = FUR
	local tail = mammal(kit, {
		body = V(1.15, 1.05, 2.05),
		color = col,
		belly = o.belly,
		head = V(1.0, 0.9, 0.95),
		headPos = V(0, 0.62, -1.1),
		neck = true,
		muzzle = V(0.48, 0.38, 0.55),
		muzzleColor = o.muzzle,
		ears = "point",
		earColor = o.ears or col,
		earInner = o.earInner,
		legLen = 0.62,
		legThick = 0.27,
		paws = o.paws,
	})
	local tails = o.tails or 1
	for i = 1, tails do
		local yaw = tails == 1 and 0 or rad(-50 + 100 * (i - 1) / (tails - 1))
		bushyTail(kit, tail, col, o.tailTip, yaw, o.tailLength)
	end
end

SPECIES["Fox"] = function(kit, col, acc)
	foxLike(kit, col, acc, { belly = acc, muzzle = acc, tailTip = acc, paws = Color3.fromRGB(60, 40, 32), ears = col, earInner = Color3.fromRGB(60, 40, 32) })
end

SPECIES["Wolf Pup"] = function(kit, col, acc)
	foxLike(kit, col, acc, { belly = lighter(col, 0.55), muzzle = lighter(col, 0.6), tailTip = acc, paws = lighter(col, 0.3), ears = acc, earInner = lighter(col, 0.4), tailLength = 1.2 })
end

SPECIES["Baby Dragon"] = function(kit, col, acc)
	kit.material = SMOOTH
	dragon(kit, { color = col, accent = acc, wingSpan = 1.1, wingChord = 0.9, wingTilt = 40, belly = Color3.fromRGB(240, 220, 150) })
end

SPECIES["Griffin Cub"] = function(kit, col, acc)
	kit.material = FUR
	local b = V(1.3, 1.2, 2.1)
	kit:oval(b, C(0, 0, 0), col).Name = "Body"
	kit:oval(V(1.1, 1.0, 0.9), C(0, 0.25, -0.75), acc) -- white feathered chest
	local hp = V(0, 0.82, -1.05)
	kit:oval(V(0.95, 0.95, 0.95), C(hp), acc).Name = "Head"
	local beak = Color3.fromRGB(255, 196, 40)
	kit:add("WedgePart", V(0.26, 0.3, 0.42), C(hp + V(0, -0.02, -0.62)), beak, SMOOTH)
	kit:add("WedgePart", V(0.2, 0.12, 0.28), C(hp + V(0, -0.18, -0.55)) * A(rad(180), 0, 0) * A(0, rad(180), 0), darker(beak, 0.2), SMOOTH)
	kit:eyes(0.26, hp.Y + 0.12, hp.Z - 0.35, 0.18)
	for _, s in ipairs({ -1, 1 }) do
		kit:diamond(0.28, 0.08, C(hp + V(s * 0.3, 0.42, 0.15)) * A(0, 0, -s * rad(25)), acc) -- feather tufts
	end
	kit:legs(0.36, -0.15, -0.62, 0.62, -1.15, 0.3, col, beak)
	local t = V(0, 0.1, 1.0)
	kit:seg(t, t + V(0, 0.55, 0.75), 0.14, col)
	kit:oval(V(0.32, 0.4, 0.32), C(t + V(0, 0.62, 0.85)), darker(col, 0.35))
	for _, s in ipairs({ -1, 1 }) do
		kit:featherWing(s, V(s * 0.45, 0.4, -0.3), 1.4, rad(20), rad(45), acc, darker(col, 0.15), 5)
	end
end

SPECIES["Phoenix"] = function(kit, col, acc)
	kit.material = FUR
	kit.fly = true
	phoenix(kit, { color = col, accent = acc, belly = lighter(acc, 0.3), beak = Color3.fromRGB(255, 220, 90), feet = Color3.fromRGB(120, 60, 30) })
	local fire = Instance.new("Fire")
	fire.Size = 2.5 * kit.scale
	fire.Heat = 2
	fire.Color = acc
	fire.SecondaryColor = col
	table.insert(kit.effectsAt, fire)
end

SPECIES["Golden Drake"] = function(kit, col, acc)
	kit.material = SMOOTH
	kit.fly = true
	dragon(kit, { color = col, accent = acc, horns = WHITE, wingSpan = 1.9, wingChord = 1.4, wingTilt = 25, tailLength = 1.2 })
end

SPECIES["Unicorn"] = function(kit, col, acc)
	kit.material = FUR
	local tail = mammal(kit, {
		body = V(1.2, 1.15, 2.2),
		color = WHITE:Lerp(col, 0.5),
		head = V(0.75, 0.8, 1.1),
		headPos = V(0, 1.15, -1.3),
		neck = true,
		muzzle = V(0.6, 0.55, 0.5),
		muzzleColor = lighter(col, 0.3),
		nose = false,
		ears = "pony",
		legLen = 0.9,
		legThick = 0.26,
		paws = Color3.fromRGB(230, 190, 90), -- golden hooves
	})
	local hp = V(0, 1.15, -1.3)
	-- the horn: a twisty glowing cone on the forehead
	local base = hp + V(0, 0.38, -0.25)
	kit:seg(base, base + V(0, 0.32, -0.16), 0.17, acc, GLOW)
	kit:seg(base + V(0, 0.28, -0.14), base + V(0, 0.6, -0.3), 0.1, lighter(acc, 0.4), GLOW)
	-- the mane: soft bumps down the back of the neck
	for i = 0, 5 do
		local p = hp + V(0, 0.35 - i * 0.2, 0.32 + i * 0.13)
		kit:oval(V(0.28, 0.42, 0.3), C(p), i % 2 == 0 and acc or lighter(acc, 0.35))
	end
	-- the tail: long flowing hair
	for i, a in ipairs({ -12, 0, 12 }) do
		local start = tail + V(0, 0.05, 0)
		local tip = start + V(math.sin(rad(a)) * 0.25, -0.9, 0.5)
		kit:seg(start, tip, 0.26 - i * 0.02, i == 2 and acc or lighter(acc, 0.35))
	end
end

SPECIES["Kitsune"] = function(kit, col, acc)
	foxLike(kit, col, acc, { belly = acc, muzzle = acc, tailTip = acc, paws = acc, ears = col, earInner = acc, tails = 5, tailLength = 1.3 })
	-- little blue fox-fire flames floating around it
	for i = 0, 2 do
		local a = i / 3 * math.pi * 2
		kit:oval(V(0.22, 0.32, 0.22), C(math.cos(a) * 1.1, 0.9, math.sin(a) * 1.2), Color3.fromRGB(110, 200, 255), GLOW)
	end
end

SPECIES["Sky Wyvern"] = function(kit, col, acc)
	kit.material = SMOOTH
	kit.fly = true
	dragon(kit, { color = col, accent = darker(col, 0.25), horns = acc, twoLegs = true, wingSpan = 2.3, wingChord = 1.5, wingTilt = 22, tailLength = 1.5, belly = acc })
end

SPECIES["Cloud Lion"] = function(kit, col, acc)
	kit.material = FUR
	local tail = mammal(kit, {
		body = V(1.35, 1.2, 2.15),
		color = col,
		head = V(0.95, 0.9, 0.9),
		headPos = V(0, 0.65, -1.15),
		muzzle = V(0.55, 0.38, 0.4),
		muzzleColor = lighter(col, 0.6),
		nose = Color3.fromRGB(90, 120, 150),
		ears = "round",
		legLen = 0.6,
		legThick = 0.34,
		paws = lighter(col, 0.6),
	})
	-- the mane: a fluffy ring of cloud puffs around the face
	local hp = V(0, 0.65, -1.15)
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		kit:oval(V(0.45, 0.45, 0.4), C(hp + V(math.cos(a) * 0.55, math.sin(a) * 0.52, 0.22)), i % 2 == 0 and acc or lighter(acc, 0.45))
	end
	kit:seg(tail, tail + V(0, 0.5, 0.8), 0.14, col)
	kit:oval(V(0.42, 0.42, 0.42), C(tail + V(0, 0.58, 0.92)), acc)
	for _, s in ipairs({ -1, 1 }) do
		kit:featherWing(s, V(s * 0.45, 0.45, -0.35), 1.7, rad(30), rad(35), WHITE, acc, 5)
	end
end

SPECIES["Angel Dragon"] = function(kit, col, acc)
	kit.material = SMOOTH
	kit.fly = true
	dragon(kit, { color = col, accent = Color3.fromRGB(255, 214, 90), horns = WHITE, feathers = true, wingSpan = 2.4, wingTilt = 25, featherTip = Color3.fromRGB(255, 240, 180), tailLength = 1.2 })
	kit:halo(V(0, 1.75, -1.4), 0.42, Color3.fromRGB(255, 230, 120))
end

SPECIES["Star Phoenix"] = function(kit, col, acc)
	kit.material = FUR
	kit.fly = true
	phoenix(kit, { color = col, accent = Color3.fromRGB(255, 214, 90), belly = acc, beak = Color3.fromRGB(255, 200, 70), feet = Color3.fromRGB(200, 160, 90) })
	kit:halo(V(0, 1.75, -0.7), 0.42, Color3.fromRGB(255, 240, 150))
end

-- Builds one pet. Returns: the Model, its Root Part (anchored, move it to move the pet), the other Parts
-- (to weld to the Root), and info = { ground = studs from the Root down to the feet, fly = true for flying pets,
-- hop = true for pets that hop }.
function PetModels.Build(def, rarity, scale)
	local kit = newKit(def.name, scale, FUR)
	local color, accent = Color3.fromHex(def.color), Color3.fromHex(def.accent)
	local build = SPECIES[def.name]
	if build then
		build(kit, color, accent)
	else
		-- a pet added to the list later without a shape yet: a round critter
		mammal(kit, { body = V(1.4, 1.2, 1.9), color = color, head = V(1, 1, 1), headPos = V(0, 0.55, -1), ears = "round", legLen = 0.4, legThick = 0.32 })
	end

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = V(1, 1, 1) * scale
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Parent = kit.model
	kit.model.PrimaryPart = root

	-- rare pets glow a little; the rarest sparkle
	if rarity >= 5 then
		local light = Instance.new("PointLight")
		light.Color = accent
		light.Range = 6 + 2 * scale
		light.Brightness = 0.6 + 0.1 * rarity
		light.Parent = root
	end
	if rarity >= 7 then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = accent
		sparkles.Parent = root
	end
	for _, effect in ipairs(kit.effectsAt) do
		effect.Parent = root
	end

	return kit.model, root, kit.parts, { ground = kit.ground * scale, fly = kit.fly, hop = kit.hop }
end

return PetModels
