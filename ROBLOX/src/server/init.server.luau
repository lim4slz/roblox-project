local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Ember = ReplicatedStorage:WaitForChild("Ember")
local Abilities = require(Ember.Abilities)
local Config = require(Ember.Config)
local Rig = require(Ember.Rig)
local Hits = require(script.Hits)

local remote = Ember:FindFirstChild("Remote") :: RemoteEvent?
if remote == nil then
	local r = Instance.new("RemoteEvent")
	r.Name = "Remote"
	r.Parent = Ember
	remote = r
end
local Remote = remote :: RemoteEvent

local cooldowns: { [Player]: { [string]: number } } = {}
local casting: { [Player]: number } = {}

local function onCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if humanoid == nil or humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		warn(`[Ember] {player.Name} não está em R15, a habilidade precisa de R15`)
		return
	end
	character:WaitForChild("RightHand", 10)
	character:WaitForChild("UpperTorso", 10)
	Rig.augment(character)
	humanoid.Died:Connect(function()
		if casting[player] then
			casting[player] = nil
			Remote:FireAllClients("stop", player)
		end
	end)
end

Players.PlayerAdded:Connect(function(player)
	cooldowns[player] = {}
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		onCharacter(player, player.Character)
	end
end)

for _, player in Players:GetPlayers() do
	cooldowns[player] = cooldowns[player] or {}
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
end

Players.PlayerRemoving:Connect(function(player)
	cooldowns[player] = nil
	casting[player] = nil
end)

Remote.OnServerEvent:Connect(function(player, action, name)
	if action ~= "cast" or type(name) ~= "string" then
		return
	end
	local ability = Abilities[name]
	local settings = Config.Abilities[name]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if ability == nil or settings == nil or humanoid == nil or humanoid.Health <= 0 or casting[player] then
		return
	end
	local now = os.clock()
	local list = cooldowns[player]
	if list == nil or (list[name] and now < list[name]) then
		return
	end
	list[name] = now + settings.cooldown
	local id = now
	casting[player] = id
	local started = Workspace:GetServerTimeNow()
	Remote:FireAllClients("start", player, name, started)
	Hits.schedule(player, character :: Model, name, ability, function()
		return casting[player] == id
	end)
	task.delay(ability.Duration, function()
		if casting[player] == id then
			casting[player] = nil
		end
	end)
end)
