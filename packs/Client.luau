--[[
	{{CLIENT}}
	Starts the pets on this player's device. Every player sees every player's
	pets, and nothing has to run on the server.

	Settings: ReplicatedStorage > {{FOLDER}} > Config
	Looks:    ReplicatedStorage > {{FOLDER}} > Models

	This LocalScript goes in StarterPlayer > StarterPlayerScripts.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = ReplicatedStorage:WaitForChild("{{FOLDER}}", 10)
if not folder then
	warn(
		"[Pets] {{FOLDER}} is missing from ReplicatedStorage. Drag {{FOLDER}}.rbxm into ReplicatedStorage (see README.txt)."
	)
	return
end

local PetSpawner = require(folder:WaitForChild("Modules"):WaitForChild("PetSpawner"))
PetSpawner.start(require(folder:WaitForChild("Config")), folder:FindFirstChild("Models"))
