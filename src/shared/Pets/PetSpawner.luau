--!strict
--[[
	PetSpawner
	Runs on every client and gives characters their pets. Pets are cosmetic and
	local: each client builds and animates the pets it can see, nothing is
	replicated and the server does not have to do anything.

	  PetSpawner.start(config, models) -- models is optional

	config.Pets       pet names every player gets, e.g. { "Dog" }
	config.GiveTo     "Everyone" (default) or "Attribute": only players whose
	                  "Pet" attribute is set get pets
	config.Attribute  name of that attribute (default "Pet"). On any player it
	                  overrides config.Pets: "Dog", "Dog,Snake" or "" for none
	config.ShowOtherPlayersPets  false = each player only sees their own pets
	config.<PetName>  settings of one pet: Scale, Spot, Sound, SoundStart,
	                  Volume, Texts, Every (see PetKit.Options)

	Pet modules are found next to this one by name ("Dog" -> DogPet). A Model
	with the pet's name inside `models` is used as the look of the pet (see
	PetKit.build); without one the pets keep their original look.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PetKit = require(script.Parent.PetKit)

local FOLDER_NAME = "AnimatedPets"

type Entry = {
	names: { string },
	pets: { PetKit.Pet },
	connections: { RBXScriptConnection },
}

type State = {
	config: { [string]: any },
	models: Instance?,
	folder: Folder,
	raycastParams: RaycastParams,
	entries: { [Player]: Entry },
	connections: { RBXScriptConnection },
	classes: { [string]: PetKit.PetClass },
	unknown: { [string]: boolean },
}

local PetSpawner = {}

local active: State? = nil

local function classOf(state: State, name: string): PetKit.PetClass?
	local cached = state.classes[name]
	if cached or state.unknown[name] then
		return cached
	end
	local module = script.Parent:FindFirstChild(name .. "Pet")
	if module and module:IsA("ModuleScript") then
		local class = (require :: any)(module) :: PetKit.PetClass
		state.classes[name] = class
		return class
	end
	state.unknown[name] = true
	warn(`[Pets] There is no pet called "{name}". Check the pet names in the Config.`)
	return nil
end

local function namesFor(state: State, player: Player): { string }
	local config = state.config
	if config.ShowOtherPlayersPets == false and player ~= Players.LocalPlayer then
		return {}
	end
	local value = player:GetAttribute(config.Attribute or "Pet")
	if type(value) == "string" then
		local names = {}
		for name in string.gmatch(value, "[^,]+") do
			name = string.match(name, "^%s*(.-)%s*$") :: string
			if name ~= "" then
				table.insert(names, name)
			end
		end
		return names
	end
	if config.GiveTo == "Attribute" then
		return {}
	end
	local names = {}
	for _, name in config.Pets or {} do
		if type(name) == "string" then
			table.insert(names, name)
		end
	end
	return names
end

local function optionsFor(state: State, name: string): PetKit.Options
	local settings = state.config[name]
	local template = if state.models then state.models:FindFirstChild(name) else nil
	local options: PetKit.Options = {
		raycastParams = state.raycastParams,
		template = if template and template:IsA("Model") then template else nil,
	}
	if type(settings) == "table" then
		options.scale = settings.Scale
		options.spot = settings.Spot
		options.sound = settings.Sound
		options.soundStart = settings.SoundStart
		options.volume = settings.Volume
		options.texts = settings.Texts
		options.every = settings.Every
	end
	return options
end

local function refreshIgnoreList(state: State)
	local ignore: { Instance } = { state.folder }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	state.raycastParams.FilterDescendantsInstances = ignore
end

local function clearPets(entry: Entry)
	for _, pet in entry.pets do
		pet:destroy()
	end
	table.clear(entry.pets)
	table.clear(entry.names)
end

local function spawnPets(state: State, player: Player)
	local entry = state.entries[player]
	if not entry then
		return
	end
	clearPets(entry)
	local character = player.Character
	if not character then
		return
	end
	refreshIgnoreList(state)
	for _, name in namesFor(state, player) do
		local class = classOf(state, name)
		if class then
			table.insert(entry.pets, class.new(character, state.folder, optionsFor(state, name)))
			table.insert(entry.names, name)
		end
	end
end

local function watch(state: State, player: Player)
	local entry: Entry = { names = {}, pets = {}, connections = {} }
	state.entries[player] = entry
	table.insert(
		entry.connections,
		player.CharacterAdded:Connect(function()
			spawnPets(state, player)
		end)
	)
	table.insert(
		entry.connections,
		player.CharacterRemoving:Connect(function()
			clearPets(entry)
			refreshIgnoreList(state)
		end)
	)
	table.insert(
		entry.connections,
		player:GetAttributeChangedSignal(state.config.Attribute or "Pet"):Connect(function()
			spawnPets(state, player)
		end)
	)
	spawnPets(state, player)
end

local function unwatch(state: State, player: Player)
	local entry = state.entries[player]
	if entry then
		state.entries[player] = nil
		clearPets(entry)
		for _, connection in entry.connections do
			connection:Disconnect()
		end
	end
	refreshIgnoreList(state)
end

function PetSpawner.start(config: { [string]: any }, models: Instance?)
	assert(active == nil, "PetSpawner is already running")
	assert(type(config) == "table", "PetSpawner.start needs the Config table")
	-- The Config is edited by hand: say what is wrong instead of failing quietly.
	if config.Pets ~= nil and type(config.Pets) ~= "table" then
		warn('[Pets] Config.Pets should be a list of pet names like { "Dog" }.')
		config.Pets = {}
	end
	for _, name in config.Pets or {} do
		if type(name) ~= "string" then
			warn('[Pets] Config.Pets should only hold pet names in quotes, like { "Dog" }.')
		end
	end
	if config.GiveTo ~= nil and config.GiveTo ~= "Everyone" and config.GiveTo ~= "Attribute" then
		warn(`[Pets] Config.GiveTo should be "Everyone" or "Attribute", not "{config.GiveTo}". Using "Everyone".`)
		config.GiveTo = "Everyone"
	end
	if config.Attribute ~= nil and (type(config.Attribute) ~= "string" or config.Attribute == "") then
		warn('[Pets] Config.Attribute should be the name of an attribute, like "Pet". Using "Pet".')
		config.Attribute = "Pet"
	end

	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = Workspace

	-- Ground probes ignore the pets and every character (no standing on heads).
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.RespectCanCollide = true

	local state: State = {
		config = config,
		models = models,
		folder = folder,
		raycastParams = raycastParams,
		entries = {},
		connections = {},
		classes = {},
		unknown = {},
	}
	active = state

	for _, name in config.Pets or {} do
		if type(name) == "string" then
			classOf(state, name)
		end
	end
	for _, player in Players:GetPlayers() do
		watch(state, player)
	end
	table.insert(
		state.connections,
		Players.PlayerAdded:Connect(function(player)
			watch(state, player)
		end)
	)
	table.insert(
		state.connections,
		Players.PlayerRemoving:Connect(function(player)
			unwatch(state, player)
		end)
	)
	table.insert(
		state.connections,
		RunService.PreRender:Connect(function(dt)
			for _, entry in state.entries do
				for _, pet in entry.pets do
					pet:update(dt)
				end
			end
		end)
	)
end

-- The pets a player has right now (empty when the spawner is not running).
function PetSpawner.getPets(player: Player): { PetKit.Pet }
	local entry = if active then active.entries[player] else nil
	return if entry then table.clone(entry.pets) else {}
end

-- Makes a player's pets react right now: the dog barks, the snake hisses...
-- Only the pet called `name` when it is given.
function PetSpawner.react(player: Player, name: string?, count: number?)
	local entry = if active then active.entries[player] else nil
	if not entry then
		return
	end
	for index, pet in entry.pets do
		if name == nil or entry.names[index] == name then
			pet:react(count)
		end
	end
end

function PetSpawner.stop()
	local state = active
	if not state then
		return
	end
	active = nil
	for _, connection in state.connections do
		connection:Disconnect()
	end
	for player in state.entries do
		unwatch(state, player)
	end
	state.folder:Destroy()
end

return table.freeze(PetSpawner)
