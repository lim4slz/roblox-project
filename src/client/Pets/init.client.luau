--!strict
--[[
	Pets (client)
	Gives characters their pets. Each client renders the pets locally: they are
	cosmetic and nothing replicates (see Shared.Pets.PetSpawner).

	Until the pet equip flow exists, every player gets every finished pet so
	they can be play-tested; later the server should set each player's "Pet"
	attribute to their equipped pet instead.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pets = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Pets")
local PetSpawner = require(Pets:WaitForChild("PetSpawner"))

PetSpawner.start({
	Pets = { "Dog", "Snake" },
})
