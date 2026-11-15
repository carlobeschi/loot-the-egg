--[[ Sounds  (ModuleScript inside ReplicatedStorage.Config, so both server and client can use it)
  Every sound effect in one list. They all use sound files that ship with Roblox itself ("rbxasset://sounds/..."),
  so nothing has to be uploaded and there are no rights to worry about. Checked in Studio on 2026-11-15 that each
  one loads. To use your own sound later, upload it and swap the id for "rbxassetid://<number>".

  speed changes the pitch (0.5 = an octave lower), like the frequencies in sfx() in the JS game.

  Server:  Sounds.PlayAt("hit", position)     -- a 3D sound everyone nearby hears
  Client:  Sounds.PlayLocal("jingle")         -- only this player hears it (menus, music stings)
  Every effect goes through the SoundGroup "Effects", so the Settings switch can mute them on one screen.
]]
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local Sounds = {}

local S = "rbxasset://sounds/"
Sounds.List = {
	-- weapons and abilities
	swingKnight = { id = S .. "swordslash.wav", volume = 0.6 },
	castWizard = { id = S .. "electronicpingshort.wav", volume = 0.4, speed = 0.6 },
	shootBowman = { id = S .. "snap.wav", volume = 0.6, speed = 0.8 },
	shieldSlam = { id = S .. "impact_explosion_03.mp3", volume = 0.5, speed = 1.2 },
	blink = { id = S .. "flashbulb.wav", volume = 0.6 },
	volley = { id = S .. "snap.wav", volume = 0.8, speed = 0.6 },
	-- enemies
	hit = { id = S .. "hit.wav", volume = 0.5 },
	enemyDown = { id = S .. "splat.wav", volume = 0.6, speed = 0.8 },
	playerHurt = { id = S .. "oof.ogg", volume = 0.6 },
	-- bosses
	bossRoar = { id = S .. "HalloweenGhost.wav", volume = 0.9, speed = 0.5, range = 160 },
	bossDown = { id = S .. "HalloweenGhost.wav", volume = 1, speed = 0.35, range = 200 },
	slamWarning = { id = S .. "bass.wav", volume = 0.8, speed = 0.6 },
	slam = { id = S .. "impact_explosion_03.mp3", volume = 0.9, speed = 0.7, range = 120 },
	-- eggs and pets
	eggTaken = { id = S .. "HalloweenGhost.wav", volume = 1, speed = 0.7, range = 200 },
	eggBanked = { id = S .. "Victory.wav", volume = 0.7 },
	hatch = { id = S .. "electronicpingshort.wav", volume = 0.5, speed = 1.6 },
	buy = { id = S .. "clickfast.wav", volume = 0.6 },
	classPick = { id = S .. "unsheath.wav", volume = 0.7 },
	-- the music's notes (ClientMusic) use this one at different speeds
	musicNote = { id = S .. "electronicpingshort.wav", volume = 0.18 },
	musicWind = { id = S .. "action_swim.mp3", volume = 0.25, speed = 0.3 },
}

-- the SoundGroup every effect plays through (made once, on whichever side asks first)
function Sounds.Group(name)
	local group = SoundService:FindFirstChild(name)
	if not group then
		group = Instance.new("SoundGroup")
		group.Name = name
		group.Volume = 1
		group.Parent = SoundService
	end
	return group
end

local function make(name, speed)
	local def = Sounds.List[name]
	if not def then
		warn("[Sounds] no sound called " .. tostring(name))
		return nil, nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = def.id
	sound.Volume = def.volume or 0.5
	sound.PlaybackSpeed = speed or def.speed or 1
	sound.RollOffMaxDistance = def.range or 90
	sound.SoundGroup = Sounds.Group("Effects")
	return sound, def
end

-- Server (or client): a sound at a spot in the world. where = a Vector3 or a BasePart.
function Sounds.PlayAt(name, where, speed)
	local sound = make(name, speed)
	if not sound then
		return
	end
	local holder
	if typeof(where) == "Vector3" then
		holder = Instance.new("Part")
		holder.Name = "Sound_" .. name
		holder.Size = Vector3.new(0.2, 0.2, 0.2)
		holder.Transparency = 1
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.Position = where
		holder.Parent = workspace
		sound.Parent = holder
		Debris:AddItem(holder, 8)
	else
		sound.Parent = where
		Debris:AddItem(sound, 8)
	end
	sound:Play()
end

-- Client only: a sound just for this player (not in the world).
function Sounds.PlayLocal(name, speed)
	local sound = make(name, speed)
	if not sound then
		return
	end
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 8)
end

return Sounds
