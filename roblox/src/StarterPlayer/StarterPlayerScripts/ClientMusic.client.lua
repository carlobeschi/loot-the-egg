--[[ ClientMusic  (LocalScript, put it in StarterPlayer > StarterPlayerScripts)
  The eerie background music, built the same way as music() in the JS game: a low drone, a slow wind, and single
  bell-like notes from a dark scale that ring out with a long echo, one every few seconds. It is made from sounds
  that ship with Roblox (see Config.Sounds), slowed down and echoed, so nothing has to be uploaded.
  It starts once you are in the game with your class, and it is a little lower and slower in World 2.

  The Settings switch (or M) sets the player attribute SoundOn; this script then mutes the music and the
  "Effects" SoundGroup on your screen only.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Sounds = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Sounds"))

local player = Players.LocalPlayer
local MUSIC_VOLUME = 0.8

-- everything here plays through a "Music" group made on this screen only
local music = Instance.new("SoundGroup")
music.Name = "Music"
music.Volume = MUSIC_VOLUME
music.Parent = SoundService

-- a long echo and a big room, shared by the notes (like the delay + feedback in the JS music)
local echo = Instance.new("EchoSoundEffect")
echo.Delay = 0.55
echo.Feedback = 0.5
echo.DryLevel = 0
echo.WetLevel = -4
echo.Parent = music
local reverb = Instance.new("ReverbSoundEffect")
reverb.DecayTime = 6
reverb.Density = 1
reverb.Diffusion = 1
reverb.DryLevel = -2
reverb.WetLevel = -4
reverb.Parent = music

local function loop(name, speed, volume)
	local def = Sounds.List[name]
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = def.id
	sound.Looped = true
	sound.PlaybackSpeed = speed
	sound.Volume = volume
	sound.SoundGroup = music
	local muffle = Instance.new("EqualizerSoundEffect") -- take the top off, so it sounds far away
	muffle.HighGain = -30
	muffle.MidGain = -8
	muffle.LowGain = 4
	muffle.Parent = sound
	sound.Parent = SoundService
	return sound
end

local wind = loop("musicWind", Sounds.List.musicWind.speed, Sounds.List.musicWind.volume)
local drone = loop("slamWarning", 0.25, 0.18) -- the bass hit, slowed right down, becomes a slow dark pulse

-- the notes of the JS scale [220, 261.6, 311.1, 329.6, 440, 466.2, 622.3] Hz, as speeds of a note at 440 Hz
local SCALE = { 0.5, 0.595, 0.707, 0.749, 1, 1.06, 1.414 }

local function worldPitch()
	return player:GetAttribute("World") == 2 and 0.84 or 1
end

local started = false
local function start()
	if started then
		return
	end
	started = true
	wind:Play()
	drone:Play()
	task.spawn(function()
		local rng = Random.new()
		while true do
			local speed = SCALE[rng:NextInteger(1, #SCALE)] * (rng:NextNumber() < 0.25 and 0.5 or 1) * worldPitch()
			local note = Instance.new("Sound")
			note.SoundId = Sounds.List.musicNote.id
			note.Volume = Sounds.List.musicNote.volume
			note.PlaybackSpeed = speed
			note.SoundGroup = music
			note.Parent = SoundService
			note:Play()
			task.delay(8, function()
				note:Destroy()
			end)
			task.wait(rng:NextNumber(2.2, 6.7))
		end
	end)
end

local function applyWorld()
	local p = worldPitch()
	wind.PlaybackSpeed = Sounds.List.musicWind.speed * p
	drone.PlaybackSpeed = 0.25 * p
end
player:GetAttributeChangedSignal("World"):Connect(applyWorld)

local function applySound()
	local on = player:GetAttribute("SoundOn") ~= false
	music.Volume = on and MUSIC_VOLUME or 0
	Sounds.Group("Effects").Volume = on and 1 or 0
end
player:GetAttributeChangedSignal("SoundOn"):Connect(applySound)

-- start once the HUD has your numbers (so you have a class); the server sends them every second
ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("State").OnClientEvent:Connect(function()
	if not started then
		SoundService:WaitForChild("Effects", 5) -- made by the server, so muting reaches it
		applyWorld()
		applySound()
		start()
	end
end)
