--[[
	PetPacks
	Builds the folders that go to the client:

	  Work꞉ pet animation/
	    Dog/          README.txt + ReplicatedStorage/DogPet.rbxm
	                  + StarterPlayer/StarterPlayerScripts/DogPetClient.rbxm
	    Snake/ ...    (one folder per pet)
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
			.. "experience. It has 2.8 seconds of silence at the start, that's why SoundStart is 2.8 by default.",
	},
	Bunny = {
		modules = { "BunnyAnimation", "BunnyModel", "BunnyPet" },
		model = "BunnyModel",
		lower = "bunny",
		react = "do a binky",
		reacts = "does a binky",
		soundWord = "squeak",
		bodyPart = "Body",
		textExample = '"Boing!", "Hippity hop!"',
		soundCredit = 'The default squeak is "Squeeze Toy Squeaky Rubber With Noisemaker Hits 9" by Pro Sound '
			.. "Effects, licensed by Roblox for every experience.",
	},
	Crab = {
		modules = { "CrabAnimation", "CrabModel", "CrabPet" },
		model = "CrabModel",
		lower = "crab",
		react = "snap",
		reacts = "snaps",
		soundWord = "snap",
		bodyPart = "Shell",
		textExample = '"PINCH!", "Clickety clack!"',
		soundCredit = 'The default snap is "Crab Claw Smaller Snaps Plasticky 3" by Pro Sound Effects, licensed by '
			.. "Roblox for every experience. Its three clicks match the three snaps of the animation, so with a sound"
			.. " of your own the clicks may not line up with the claws.",
	},
	Dragon = {
		modules = { "DragonAnimation", "DragonModel", "DragonPet" },
		model = "DragonModel",
		lower = "dragon",
		react = "breathe fire",
		reacts = "breathes fire",
		soundWord = "whoosh",
		bodyPart = "Body",
		textExample = '"BURN!", "Hot hot hot!"',
		soundCredit = 'The default whoosh is "Fire Whoosh 4" by Pro Sound Effects, licensed by Roblox for every '
			.. "experience. It builds up slowly, that's why SoundStart is 1.3 by default.",
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
		dir = "Bunny",
		folder = "BunnyPet",
		pets = { "Bunny" },
		title = "Animated Bunny Pet",
		intro = "A cartoon bunny that hops after each player: it twitches its nose, flicks its ears, makes longer "
			.. "hops to catch up and jumps for joy (a binky) with a pop-up bubble and a squeak.",
	},
	{
		dir = "Crab",
		folder = "CrabPet",
		pets = { "Crab" },
		title = "Animated Crab Pet",
		intro = "A cartoon crab that scuttles sideways after each player: its eyes look around on their stalks, it"
			.. ' blinks, pinches the air and throws its claws up to "SNAP!" with a pop-up bubble and claw clicks.',
	},
	{
		dir = "Dragon",
		folder = "DragonPet",
		pets = { "Dragon" },
		title = "Animated Dragon Pet",
		intro = "A cartoon dragon that flies after each player: it flaps its wings, lands and folds them when its"
			.. " owner stands still, takes off again when they move and breathes a stream of fire with a pop-up"
			.. " bubble and a whoosh.",
	},
	{
		dir = "All in One",
		folder = "AllPets",
		pets = { "Dog", "Snake", "Bunny", "Crab", "Dragon" },
		title = "Animated Pets: All in One",
		allInOne = true,
	},
}

-- Folders that only hold a README for now (packs/readme/<Name>.txt), for a
-- pet whose model has not arrived yet.
PetPacks.Placeholders = {} :: { string }

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
		part.Material = def.material or Enum.Material.Plastic
		part.Transparency = def.transparency or 0
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

-- README (plain text) ------------------------------------------------------------

local WIDTH = 78

-- Wraps `text` into lines of at most WIDTH characters: the first line starts
-- with `first`, the others with `rest` (default: the same).
local function wrap(text: string, first: string, rest: string?): string
	local lines = {}
	local line = first
	local fresh = true
	for word in string.gmatch(text, "%S+") do
		if not fresh and #line + 1 + #word > WIDTH then
			table.insert(lines, line)
			line = (rest or first) .. word
		else
			line = if fresh then line .. word else line .. " " .. word
		end
		fresh = false
	end
	table.insert(lines, line)
	return table.concat(lines, "\n")
end

local function heading(text: string, underline: string): string
	return text .. "\n" .. string.rep(underline, #text)
end

-- Code shown in a README: indented four spaces, tabs as four spaces.
local function codeBlock(source: string): string
	local lines = {}
	for line in string.gmatch(trim(source) .. "\n", "(.-)\n") do
		line = string.gsub(line, "\t", "    ")
		table.insert(lines, if line == "" then "" else "    " .. line)
	end
	return table.concat(lines, "\n")
end

-- Bones that only move parts hidden at rest (eyelids, mouths, flames) are
-- left out: an accessory on them would hide or fly off with them.
local function bonesList(name: string): string
	local names = {}
	for _, bone in definitionOf(name).bones do
		local hidden = string.match(bone.name, "^Lids?[LR]?$")
			or bone.name == "Mouth"
			or string.match(bone.name, "^Fire%d+$")
		if not hidden then
			table.insert(names, bone.name)
		end
	end
	return table.concat(names, ", ")
end

-- "Dog, Snake and Crab"
local function spoken(names: { string }): string
	if #names == 1 then
		return names[1]
	end
	return table.concat(names, ", ", 1, #names - 1) .. " and " .. names[#names]
end

-- Rows of { name, class?, note? } in aligned columns.
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
			line ..= string.rep(" ", nameWidth + 3 - (utf8.len(row[1]) :: number))
			line ..= if row[2] then row[2] else ""
		end
		if row[3] then
			line ..= string.rep(" ", if row[2] then classWidth + 3 - #row[2] else classWidth + 3) .. row[3]
		end
		table.insert(lines, (string.gsub(line, "%s+$", "")))
	end
	return table.concat(lines, "\n")
end

local function filesTree(pack): string
	return columns({
		{ "  " .. pack.dir .. "/" },
		{ "    README.txt", nil, "this file" },
		{ "    ReplicatedStorage/" },
		{ "      " .. pack.folder .. ".rbxm", nil, "drag onto ReplicatedStorage" },
		{ "    StarterPlayer/" },
		{ "      StarterPlayerScripts/" },
		{ "        " .. pack.folder .. "Client.rbxm", nil, "drag onto StarterPlayerScripts" },
	})
end

local function explorerTree(pack): string
	local rows = {
		{ "  ReplicatedStorage" },
		{ "    " .. pack.folder, "(Folder)" },
		{ "      Config", "(ModuleScript)", "all the settings" },
		{ "      Models", "(Folder)", if #pack.pets > 1 then "what each pet looks like" else nil },
	}
	for _, pet in pack.pets do
		local note = if #pack.pets == 1 then "what the " .. PetPacks.Pets[pet].lower .. " looks like" else nil
		table.insert(rows, { "        " .. pet, "(Model)", note })
	end
	table.insert(rows, { "      Modules", "(Folder)", "the code, no need to touch it" })
	for _, name in PetPacks.moduleNames(pack) do
		table.insert(rows, { "        " .. name, "(ModuleScript)" })
	end
	table.insert(rows, { "  StarterPlayer" })
	table.insert(rows, { "    StarterPlayerScripts" })
	table.insert(rows, { "      " .. pack.folder .. "Client", "(LocalScript)", "starts the pets" })
	return columns(rows)
end

local function petDoc(name: string): string
	return trim(read("packs/pets/" .. name .. ".txt"))
end

function PetPacks.readme(pack): string
	if pack.allInOne then
		return PetPacks.allInOneReadme(pack)
	end
	local name = pack.pets[1]
	local pet = PetPacks.Pets[name]
	local upper = string.upper(pet.lower)
	return fill(read("packs/readme/Pet.txt"), {
		TITLE_BLOCK = heading(string.upper(pack.title), "="),
		INTRO = wrap(pack.intro, ""),
		NAME = name,
		LOWER = pet.lower,
		FOLDER = pack.folder,
		CLIENT = pack.folder .. "Client",
		FILES_TREE = filesTree(pack),
		EXPLORER_TREE = explorerTree(pack),
		PET_DOC = petDoc(name),
		CONFIG = codeBlock(PetPacks.configSource(pack)),
		HEADING_ONLY = heading("ONLY SOME PLAYERS GET THE " .. upper .. " (GAME PASS, VIP, ADMINS...)", "-"),
		HEADING_REACT = heading(
			"MAKE THE " .. upper .. " " .. string.upper(pet.react) .. " FROM YOUR OWN SCRIPTS",
			"-"
		),
		SOUND_WORD = pet.soundWord,
		REACT = pet.react,
		REACTS = pet.reacts,
		BODY_PART = pet.bodyPart,
		BONES = wrap(bonesList(name), "  "),
		SOUND_CREDIT = wrap(pet.soundCredit, ""),
		TEXT_EXAMPLE = pet.textExample,
		PART_COUNT = tostring(#definitionOf(name).parts),
	})
end

function PetPacks.allInOneReadme(pack): string
	local docs, bones, credits, reactions = {}, {}, {}, {}
	local fewest, most = math.huge, 0
	for _, name in pack.pets do
		local pet = PetPacks.Pets[name]
		local parts = #definitionOf(name).parts
		fewest, most = math.min(fewest, parts), math.max(most, parts)
		table.insert(docs, petDoc(name))
		table.insert(bones, wrap(name .. ": " .. bonesList(name), "  ", "    "))
		table.insert(credits, wrap(name .. ": " .. pet.soundCredit, "  - ", "    "))
		table.insert(reactions, "the " .. pet.lower .. " " .. pet.reacts)
	end
	local sentence = spoken(reactions)
	sentence = string.upper(string.sub(sentence, 1, 1)) .. string.sub(sentence, 2) .. "."
	return fill(read("packs/readme/AllInOne.txt"), {
		TITLE_BLOCK = heading(string.upper(pack.title), "="),
		REACT_PARAGRAPH = wrap(
			sentence
				.. " PetSpawner.react(player) works for any player, not just the local one, and only on the device"
				.. " that calls it. PetSpawner.getPets(player) gives you that player's pets; each one has a model"
				.. " (the Model in workspace.AnimatedPets). Set Every = false on a pet if it should only react when"
				.. " you say so.",
			""
		),
		FOLDER = pack.folder,
		CLIENT = pack.folder .. "Client",
		INTRO = wrap(
			"Every animated pet in one install: "
				.. spoken(pack.pets)
				.. ". Out of the box every player gets all of them, and the Config lets you choose who gets which.",
			""
		),
		OUTPUT_HINT = wrap(
			"Open View > Output. Messages starting with [Pets] tell you what's wrong, like a misspelled name in"
				.. " Config.Pets. The names are "
				.. spoken(pack.pets)
				.. ", with capital letters.",
			"  - ",
			"    "
		),
		FILES_TREE = filesTree(pack),
		EXPLORER_TREE = explorerTree(pack),
		PET_DOCS = table.concat(docs, "\n\n\n"),
		CONFIG = codeBlock(PetPacks.configSource(pack)),
		BONES = table.concat(bones, "\n"),
		SOUND_CREDITS = table.concat(credits, "\n"),
		PART_RANGE = if fewest == most then tostring(most) else fewest .. " to " .. most,
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
		writeFile(dir .. "/README.txt", readme)
		if options.places then
			writeFile(
				options.places .. "/" .. pack.folder .. ".rbxl",
				roblox.serializePlace(PetPacks.demoPlace(pack), false)
			)
		end
		table.insert(summary, { pack = pack, scripts = scripts })
	end
	for _, name in PetPacks.Placeholders do
		writeFile(out .. "/" .. name .. "/README.txt", read("packs/readme/" .. name .. ".txt"))
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
		assert(fs.isFile(dir .. "/README.txt"), pack.dir .. ": no README")
	end
	return true
end

return PetPacks
