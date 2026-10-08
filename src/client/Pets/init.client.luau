--!strict
--[[
	Pets (client)
	Gives every character in the server a dog that follows it around. Each
	client renders the dogs locally: they are cosmetic and nothing replicates.

	Until the pet equip flow exists, every player gets the dog so it can be
	play-tested; later this should spawn the player's equipped pet instead.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local DogPet = require(script:WaitForChild("DogPet"))

local folder = Instance.new("Folder")
folder.Name = "Pets"
folder.Parent = Workspace

-- Ground probes ignore the dogs and every character (no standing on heads).
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.RespectCanCollide = true

local dogs: { [Player]: DogPet.DogPet } = {}

local function refreshIgnoreList()
	local ignore: { Instance } = { folder }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	raycastParams.FilterDescendantsInstances = ignore
end

local function removeDog(player: Player)
	local dog = dogs[player]
	if dog then
		dogs[player] = nil
		dog:destroy()
	end
end

local function addDog(player: Player, character: Model)
	removeDog(player)
	refreshIgnoreList()
	dogs[player] = DogPet.new(character, folder, raycastParams)
end

local function watch(player: Player)
	player.CharacterAdded:Connect(function(character)
		addDog(player, character)
	end)
	player.CharacterRemoving:Connect(function()
		removeDog(player)
		refreshIgnoreList()
	end)
	if player.Character then
		addDog(player, player.Character)
	end
end

for _, player in Players:GetPlayers() do
	watch(player)
end
Players.PlayerAdded:Connect(watch)
Players.PlayerRemoving:Connect(function(player)
	removeDog(player)
	refreshIgnoreList()
end)

RunService.PreRender:Connect(function(dt)
	for _, dog in dogs do
		dog:update(dt)
	end
end)
