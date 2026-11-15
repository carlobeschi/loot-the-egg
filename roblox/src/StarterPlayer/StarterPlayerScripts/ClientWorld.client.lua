--[[ ClientWorld  (LocalScript, put it in StarterPlayer > StarterPlayerScripts)
  World 2 (the Ember Wastes) gets a warm, smoky sky on YOUR screen while you are there. The server sets the
  player attribute "World" (1 or 2) when you travel; this script only changes Lighting on this computer.
]]
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- World 1 keeps whatever the place has; remember it so we can go back.
local home = {
	ClockTime = Lighting.ClockTime,
	Ambient = Lighting.Ambient,
	OutdoorAmbient = Lighting.OutdoorAmbient,
	FogColor = Lighting.FogColor,
	FogEnd = Lighting.FogEnd,
	FogStart = Lighting.FogStart,
}
local ember = {
	ClockTime = 18.2, -- low sun
	Ambient = Color3.fromRGB(90, 50, 40),
	OutdoorAmbient = Color3.fromRGB(150, 90, 70),
	FogColor = Color3.fromRGB(120, 60, 40),
	FogEnd = 650,
	FogStart = 80,
}

local function apply()
	local goal = (player:GetAttribute("World") == 2) and ember or home
	TweenService:Create(Lighting, TweenInfo.new(1.5), goal):Play()
end

player:GetAttributeChangedSignal("World"):Connect(apply)
apply()
