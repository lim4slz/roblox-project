--[[
	PetPacks
	Builds the folders that go to the client:

	  Work꞉ pet animation/
	    Dog/          README.md + ReplicatedStorage/DogPet.rbxm
	                  + StarterPlayer/StarterPlayerScripts/DogPetClient.rbxm
	    Snake/ ...    (one folder per pet)
	    Dragon/       placeholder until its model arrives
	    All in One/   every pet in one install

	The folders inside each pack mirror the Roblox Explorer, so every file is
	dragged onto the place with the same name. The scripts are the game's own
	modules (src/shared/Pets); the Config, the LocalScript and the READMEs
	come from packs/. Every pack also gets a demo place (baseplate + the two
	files installed) used by the end-to-end tests.

	Windows does not allow ":" in folder names (git and zip extraction fail
	there), so the top folder uses U+A789 "꞉", which looks the same.

	  local PetPacks = require("./PetPacks")
	  PetPacks.build({ out = "Work꞉ pet animation", places = "build/packs" })
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local Shared = require("../tests/harness/Shared")

local Instance = roblox.Instance
local Enum = roblox.Enum
local CFrame = roblox.CFrame
local Vector3 = roblox.Vector3
local Color3 = roblox.Color3

local PetPacks = {}

PetPacks.FolderName = "Work\u{A789} pet animation"

local SOURCE = "src/shared/Pets"
local COMMON = { "PetFollow", "PetKit", "PetRig", "PetSpawner" }

-- Everything the README and the Config need to know about each pet.
PetPacks.Pets = {
	Dog = {
		modules = { "DogAnimation", "DogModel", "DogPet" },
		model = "DogModel",
		lower = "dog",
		react = "bark",
		reacts = "barks",
		soundWord = "bark",
		bodyPart = "Body",
		textExample = '"BARK!", "Arf arf!"',
		soundCredit = 'The default bark is "beagle barking", a public sound from the Creator Store.',
	},
	Snake = {
		modules = { "SnakeAnimation", "SnakeModel", "SnakePet" },
		model = "SnakeModel",
		lower = "snake",
		react = "hiss",
		reacts = "hisses",
		soundWord = "hiss",
		bodyPart = "Body3",
		textExample = '"SSSS!", "Hiss!"',
		soundCredit = 'The default hiss is "Snake Hiss 1 (SFX)" by Pro Sound Effects, licensed by Roblox for every '
			.. "experience. It has 2.8 seconds of silence at the start, that's why the default `SoundStart` is 2.8.",
	},
}

PetPacks.Packs = {
	{
		dir = "Dog",
		folder = "DogPet",
		pets = { "Dog" },
		title = "Animated Dog Pet",
		intro = "A cartoon dog that follows each player around: it walks, runs, wags its tail, blinks, pants and barks "
			.. '"WOOF!" with a pop-up bubble.',
	},
	{
		dir = "Snake",
		folder = "SnakePet",
		pets = { "Snake" },
		title = "Animated Snake Pet",
		intro = "A long cartoon snake that slithers after each player: it weaves through an S-shaped path, climbs "
			.. 'stairs segment by segment, flicks its forked tongue and rears up to "HISS!" with a pop-up bubble.',
	},
	{
		dir = "All in One",
		folder = "AllPets",
		pets = { "Dog", "Snake" },
		title = "Animated Pets: All in One",
		allInOne = true,
	},
}

-- Folders that only hold a README for now.
PetPacks.Placeholders = { "Dragon" }

local function read(path: string): string
	return fs.readFile(path)
end

-- Fills {{KEY}} placeholders, and __KEY__ ones where a formatter would touch
-- braces (in Luau code).
local function fill(text: string, values: { [string]: string }): string
	local function value(key: string): string
		local found = values[key]
		assert(found ~= nil, "no value for placeholder " .. key)
		return found
	end
	text = string.gsub(text, "{{([%w_]+)}}", value)
	text = string.gsub(text, "__([%u_]+)__", value)
	return text
end

local function moduleScript(name: string, source: string)
	local module = Instance.new("ModuleScript")
	module.Name = name
	module.Source = source
	return module
end

local function quoted(names: { string }): string
	local parts = {}
	for _, name in names do
		table.insert(parts, '"' .. name .. '"')
	end
	return table.concat(parts, ", ")
end

local function allPetNames(): { string }
	local names = {}
	for name in PetPacks.Pets do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

local function trim(text: string): string
	return (string.gsub(string.gsub(text, "^%s+", ""), "%s+$", ""))
end

local function attributeExamples(names: { string }): string
	local rows = {
		{ '"' .. names[1] .. '"', "that player gets the " .. PetPacks.Pets[names[1]].lower },
	}
	if #names > 1 then
		table.insert(rows, { '"' .. names[1] .. "," .. names[2] .. '"', "several pets, comma separated" })
	end
	table.insert(rows, { '""', "no pet" })
	table.insert(rows, { "nil", "back to Config.Pets" })
	local width = 0
	for _, row in rows do
		width = math.max(width, #row[1])
	end
	-- The template line already starts with "--   ".
	local lines = {}
	for _, row in rows do
		local call = 'player:SetAttribute("Pet", ' .. row[1] .. ")"
		table.insert(lines, call .. string.rep(" ", width + 3 - #row[1]) .. row[2])
	end
	return table.concat(lines, "\n--   ")
end

-- Header, one section per pet and the footer, a blank line between each
-- (the formatter trims the files' own blank edges).
function PetPacks.configSource(pack): string
	local names = pack.pets
	local blocks = {
		trim(fill(read("packs/config/Header.luau"), {
			PET_NAMES = quoted(names),
			PETS = quoted(names),
			ATTRIBUTE_EXAMPLES = attributeExamples(names),
		})),
	}
	for _, name in names do
		table.insert(blocks, trim(read("packs/config/" .. name .. ".luau")))
	end
	table.insert(blocks, trim(read("packs/config/Footer.luau")))
	return table.concat(blocks, "\n\n") .. "\n"
end

function PetPacks.clientSource(pack): string
	return fill(read("packs/Client.luau"), { FOLDER = pack.folder, CLIENT = pack.folder .. "Client" })
end

local function definitionOf(name: string)
	return Shared.require("Pets." .. PetPacks.Pets[name].model).Definition
end

-- The look of a pet as a Model the client can recolor (see PetKit.build).
function PetPacks.templateModel(name: string)
	local definition = definitionOf(name)
	local model = Instance.new("Model")
	model.Name = name
	local first
	for _, def in definition.parts do
		local part = Instance.new("Part")
		part.Name = def.name
		part.Size = def.size
		part.CFrame = def.cframe
		part.Color = def.color
		part.Material = Enum.Material.Plastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		if def.shape then
			part.Shape = def.shape
		end
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Parent = model
		first = first or part
	end
	model.PrimaryPart = first
	return model
end

function PetPacks.moduleNames(pack): { string }
	local names = table.clone(COMMON)
	for _, pet in pack.pets do
		for _, module in PetPacks.Pets[pet].modules do
			table.insert(names, module)
		end
	end
	table.sort(names)
	return names
end

-- ReplicatedStorage > <folder>: Config, Models and Modules.
function PetPacks.packFolder(pack)
	local folder = Instance.new("Folder")
	folder.Name = pack.folder
	moduleScript("Config", PetPacks.configSource(pack)).Parent = folder

	local models = Instance.new("Folder")
	models.Name = "Models"
	models.Parent = folder
	for _, pet in pack.pets do
		PetPacks.templateModel(pet).Parent = models
	end

	local modules = Instance.new("Folder")
	modules.Name = "Modules"
	modules.Parent = folder
	for _, name in PetPacks.moduleNames(pack) do
		moduleScript(name, read(SOURCE .. "/" .. name .. ".luau")).Parent = modules
	end
	return folder
end

function PetPacks.clientScript(pack)
	local script = Instance.new("LocalScript")
	script.Name = pack.folder .. "Client"
	script.Source = PetPacks.clientSource(pack)
	return script
end

-- A baseplate with the pack installed, for the tests.
function PetPacks.demoPlace(pack)
	local game = Instance.new("DataModel")
	local workspace = game:GetService("Workspace")
	local baseplate = Instance.new("Part")
	baseplate.Name = "Baseplate"
	baseplate.Size = Vector3.new(512, 16, 512)
	baseplate.CFrame = CFrame.new(0, -8, 0)
	baseplate.Anchored = true
	baseplate.Color = Color3.fromRGB(99, 95, 98)
	baseplate.Parent = workspace
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnLocation"
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(0, 0.5, 0)
	spawn.Anchored = true
	spawn.Parent = workspace

	PetPacks.packFolder(pack).Parent = game:GetService("ReplicatedStorage")
	local starterPlayer = game:GetService("StarterPlayer")
	local scripts = Instance.new("StarterPlayerScripts")
	scripts.Name = "StarterPlayerScripts"
	scripts.Parent = starterPlayer
	PetPacks.clientScript(pack).Parent = scripts
	return game
end

-- README ------------------------------------------------------------------------

local function bonesList(name: string): string
	local lines = {}
	for _, bone in definitionOf(name).bones do
		table.insert(lines, "`" .. bone.name .. "`")
	end
	return table.concat(lines, ", ")
end

-- Rows of { name, class?, note? } in aligned columns (utf8.len: the tree
-- characters are several bytes each).
local function columns(rows: { { string } }): string
	local nameWidth, classWidth = 0, 0
	for _, row in rows do
		nameWidth = math.max(nameWidth, utf8.len(row[1]) :: number)
		classWidth = math.max(classWidth, if row[2] then #row[2] else 0)
	end
	local lines = {}
	for _, row in rows do
		local line = row[1]
		if row[2] or row[3] then
			line ..= string.rep(" ", nameWidth + 2 - (utf8.len(row[1]) :: number))
			line ..= if row[2] then row[2] else ""
		end
		if row[3] then
			line ..= string.rep(" ", classWidth + 2 - (if row[2] then #row[2] else 0)) .. row[3]
		end
		table.insert(lines, (string.gsub(line, "%s+$", "")))
	end
	return table.concat(lines, "\n")
end

local function filesTree(pack): string
	local client = pack.folder .. "Client"
	return columns({
		{ pack.dir .. "/" },
		{ "├── README.md", nil, "you are here" },
		{ "├── ReplicatedStorage/" },
		{ "│   └── " .. pack.folder .. ".rbxm", nil, "drag onto ReplicatedStorage" },
		{ "└── StarterPlayer/" },
		{ "    └── StarterPlayerScripts/" },
		{ "        └── " .. client .. ".rbxm", nil, "drag onto StarterPlayer > StarterPlayerScripts" },
	})
end

local function explorerTree(pack): string
	local rows = {
		{ "ReplicatedStorage" },
		{ "└── " .. pack.folder, "(Folder)" },
		{ "    ├── Config", "(ModuleScript)", "all the settings" },
		{ "    ├── Models", "(Folder)", if #pack.pets > 1 then "the look of each pet" else nil },
	}
	for index, pet in pack.pets do
		local branch = if index == #pack.pets then "└── " else "├── "
		local note = if #pack.pets == 1 then "the look of the " .. PetPacks.Pets[pet].lower else nil
		table.insert(rows, { "    │   " .. branch .. pet, "(Model)", note })
	end
	table.insert(rows, { "    └── Modules", "(Folder)", "the code, you don't need to touch it" })
	local names = PetPacks.moduleNames(pack)
	for index, name in names do
		table.insert(
			rows,
			{ "        " .. (if index == #names then "└── " else "├── ") .. name, "(ModuleScript)" }
		)
	end
	table.insert(rows, { "StarterPlayer" })
	table.insert(rows, { "└── StarterPlayerScripts" })
	table.insert(rows, { "    └── " .. pack.folder .. "Client", "(LocalScript)", "starts the pets" })
	return columns(rows)
end

function PetPacks.readme(pack): string
	if pack.allInOne then
		return PetPacks.allInOneReadme(pack)
	end
	local name = pack.pets[1]
	local pet = PetPacks.Pets[name]
	return fill(read("packs/readme/Pet.md"), {
		TITLE = pack.title,
		INTRO = pack.intro,
		NAME = name,
		LOWER = pet.lower,
		FOLDER = pack.folder,
		CLIENT = pack.folder .. "Client",
		FILES_TREE = filesTree(pack),
		EXPLORER_TREE = explorerTree(pack),
		PET_DOC = (string.gsub(read("packs/pets/" .. name .. ".md"), "%s+$", "")),
		CONFIG = (string.gsub(PetPacks.configSource(pack), "%s+$", "")),
		SOUND_WORD = pet.soundWord,
		REACT = pet.react,
		REACTS = pet.reacts,
		BODY_PART = pet.bodyPart,
		BONES = bonesList(name),
		SOUND_CREDIT = pet.soundCredit,
		TEXT_EXAMPLE = pet.textExample,
		PART_COUNT = tostring(#definitionOf(name).parts),
	})
end

function PetPacks.allInOneReadme(pack): string
	local docs, bones, credits, packs = {}, {}, {}, {}
	for _, name in pack.pets do
		local pet = PetPacks.Pets[name]
		table.insert(docs, (string.gsub(read("packs/pets/" .. name .. ".md"), "%s+$", "")))
		table.insert(bones, "- **" .. name .. "**: " .. bonesList(name))
		table.insert(credits, "- " .. name .. ": " .. pet.soundCredit)
		table.insert(packs, "`" .. name .. "`")
	end
	local reactions = {}
	for _, name in pack.pets do
		local pet = PetPacks.Pets[name]
		table.insert(reactions, "the " .. pet.lower .. " " .. pet.reacts)
	end
	local sentence = if #reactions > 1
		then table.concat(reactions, ", ", 1, #reactions - 1) .. " and " .. reactions[#reactions]
		else reactions[1]
	sentence = string.upper(string.sub(sentence, 1, 1)) .. string.sub(sentence, 2) .. "."
	return fill(read("packs/readme/AllInOne.md"), {
		REACT_SENTENCE = sentence,
		TITLE = pack.title,
		FOLDER = pack.folder,
		CLIENT = pack.folder .. "Client",
		PET_LIST = table.concat(packs, ", "),
		FILES_TREE = filesTree(pack),
		EXPLORER_TREE = explorerTree(pack),
		PET_DOCS = table.concat(docs, "\n\n"),
		CONFIG = (string.gsub(PetPacks.configSource(pack), "%s+$", "")),
		BONES = table.concat(bones, "\n"),
		SOUND_CREDITS = table.concat(credits, "\n"),
	})
end

-- Build -------------------------------------------------------------------------

local function writeFile(path: string, data: string)
	local dir = string.match(path, "^(.*)/[^/]*$")
	if dir and not fs.isDir(dir) then
		fs.writeDir(dir)
	end
	fs.writeFile(path, data)
end

local function checkScripts(root)
	local list = if root:IsA("LuaSourceContainer") then { root } else {}
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			table.insert(list, descendant)
		end
	end
	for _, script in list do
		assert(#script.Source > 0, script:GetFullName() .. " is empty")
		local ok, err = pcall(luau.compile, script.Source)
		assert(ok, script:GetFullName() .. " does not compile: " .. tostring(err))
		assert(
			not string.find(script.Source, "{{", 1, true),
			script:GetFullName() .. " has an unfilled {{placeholder}}"
		)
		assert(
			not string.find(script.Source, "__%u[%u_]*__"),
			script:GetFullName() .. " has an unfilled __PLACEHOLDER__"
		)
	end
	return #list
end

-- Builds every pack. Returns a summary per pack.
function PetPacks.build(options: { out: string, places: string? })
	local out = options.out
	if fs.isDir(out) then
		fs.removeDir(out)
	end
	fs.writeDir(out)
	local summary = {}
	for _, pack in PetPacks.Packs do
		local dir = out .. "/" .. pack.dir
		local folder = PetPacks.packFolder(pack)
		local client = PetPacks.clientScript(pack)
		local scripts = checkScripts(folder) + checkScripts(client)
		-- The Config must really list the pack's pets (a formatter once turned
		-- the placeholder into nested tables that still compiled).
		local config = luau.load(PetPacks.configSource(pack), { environment = { Vector3 = Vector3 } })()
		assert(#config.Pets == #pack.pets, pack.dir .. ": Config.Pets does not list the pack's pets")
		for index, name in pack.pets do
			assert(config.Pets[index] == name, pack.dir .. ": Config.Pets[" .. index .. "] is not " .. name)
			assert(type(config[name]) == "table", pack.dir .. ": Config." .. name .. " is missing")
		end
		writeFile(dir .. "/ReplicatedStorage/" .. pack.folder .. ".rbxm", roblox.serializeModel({ folder }, false))
		writeFile(
			dir .. "/StarterPlayer/StarterPlayerScripts/" .. client.Name .. ".rbxm",
			roblox.serializeModel({ client }, false)
		)
		local readme = PetPacks.readme(pack)
		assert(not string.find(readme, "{{", 1, true), pack.dir .. " README has an unfilled {{placeholder}}")
		writeFile(dir .. "/README.md", readme)
		if options.places then
			writeFile(
				options.places .. "/" .. pack.folder .. ".rbxl",
				roblox.serializePlace(PetPacks.demoPlace(pack), false)
			)
		end
		table.insert(summary, { pack = pack, scripts = scripts })
	end
	for _, name in PetPacks.Placeholders do
		writeFile(out .. "/" .. name .. "/README.md", read("packs/readme/" .. name .. ".md"))
	end
	return summary
end

-- Reads the built files back and checks they hold what Studio needs.
function PetPacks.verify(out: string)
	for _, pack in PetPacks.Packs do
		local dir = out .. "/" .. pack.dir
		local folder = roblox.deserializeModel(fs.readFile(dir .. "/ReplicatedStorage/" .. pack.folder .. ".rbxm"))
		assert(
			#folder == 1 and folder[1].ClassName == "Folder" and folder[1].Name == pack.folder,
			pack.dir .. ": bad folder"
		)
		local root = folder[1]
		assert(root:FindFirstChild("Config") and root.Config.ClassName == "ModuleScript", pack.dir .. ": no Config")
		for _, name in PetPacks.moduleNames(pack) do
			local module = root.Modules:FindFirstChild(name)
			assert(module and module.ClassName == "ModuleScript", pack.dir .. ": missing module " .. name)
			assert(module.Source == read(SOURCE .. "/" .. name .. ".luau"), pack.dir .. ": stale module " .. name)
		end
		for _, pet in pack.pets do
			local model = root.Models:FindFirstChild(pet)
			assert(model and model.ClassName == "Model", pack.dir .. ": missing model " .. pet)
			assert(#model:GetChildren() == #definitionOf(pet).parts, pack.dir .. ": wrong part count in " .. pet)
		end
		local client = roblox.deserializeModel(
			fs.readFile(dir .. "/StarterPlayer/StarterPlayerScripts/" .. pack.folder .. "Client.rbxm")
		)
		assert(#client == 1 and client[1].ClassName == "LocalScript", pack.dir .. ": bad client script")
		assert(fs.isFile(dir .. "/README.md"), pack.dir .. ": no README")
	end
	return true
end

return PetPacks
