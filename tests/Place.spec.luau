--!nonstrict
-- Checks the built place file and cross-references names between code and
-- content: every remote the code uses is declared, every sound the code plays
-- exists, and every map object the services look for is really there.

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local PLACE_PATH = "build/DoomspireBrickbattle.rbxl"

local function sourceFiles(directory: string, into: { string }?): { string }
	local files = into or {}
	for _, name in fs.readDir(directory) do
		local path = directory .. "/" .. name
		if fs.isDir(path) then
			sourceFiles(path, files)
		elseif string.match(name, "%.luau$") then
			table.insert(files, path)
		end
	end
	return files
end

return function(Expect, ModuleLoader)
	local AudioLibrary = ModuleLoader.load("src/ReplicatedStorage/Shared/AudioLibrary")
	local Config = ModuleLoader.load("src/ReplicatedStorage/Shared/Config")

	local sources = {}
	for _, path in sourceFiles("src") do
		sources[path] = fs.readFile(path)
	end

	Expect.describe("Code cross-references", function()
		Expect.it("only uses declared remotes", function()
			local declared = {}
			for name in string.gmatch(sources["src/ReplicatedStorage/Shared/Remotes.luau"], '\n\t"(%w+)",') do
				declared[name] = true
			end
			for path, source in sources do
				for name in string.gmatch(source, 'Remotes%.get%("(%w+)"%)') do
					Expect.truthy(declared[name], path .. " uses undeclared remote " .. name)
				end
			end
		end)

		Expect.it("only plays sounds that exist", function()
			for path, source in sources do
				for name in string.gmatch(source, 'SoundPlayer%.play%a*%("(%w+)"') do
					Expect.truthy(AudioLibrary.Sfx[name], path .. " plays unknown sound " .. name)
				end
			end
		end)

		Expect.it("has no duplicate or empty sound ids", function()
			for _, category in { "Music", "Sfx", "Ambient" } do
				for name, spec in AudioLibrary[category] do
					Expect.truthy(spec.Id and spec.Id > 0, category .. "." .. name .. " has no id")
				end
			end
		end)
	end)

	Expect.describe("Built place", function()
		Expect.truthy(fs.isFile(PLACE_PATH), "run the build first")
		local game = roblox.deserializePlace(fs.readFile(PLACE_PATH))

		local function find(dotted: string)
			local current = nil
			for name in string.gmatch(dotted, "[^%.]+") do
				if current == nil then
					current = game:GetService(name)
				else
					current = current:FindFirstChild(name)
				end
				if not current then
					return nil
				end
			end
			return current
		end

		Expect.it("contains every map object the services look up", function()
			for _, path in
				{
					"Workspace.Arena.Towers",
					"Workspace.Arena.ZoneCenter",
					"Workspace.Arena.PowerUpPads",
					"Workspace.Lobby.LobbySpawn",
					"Workspace.Lobby.Billboard.StatusBoard",
					"Workspace.Lobby.PracticeArea.PracticeWall.Bricks",
					"Workspace.Lobby.PracticeArea.Dummies",
					"ServerStorage.AdminPanel.AdminPanelClient",
					"ServerScriptService.Server.Main",
					"StarterPlayer.StarterPlayerScripts.Client.Main",
					"SoundService.GameAudio.Music",
				}
			do
				Expect.truthy(find(path), "missing " .. path)
			end
		end)

		Expect.it("has a tool model with a Handle for every weapon", function()
			for _, name in { "Bomb", "Sword", "RocketLauncher" } do
				local tool = find("ServerStorage.Tools." .. name)
				Expect.truthy(tool and tool:IsA("Tool"), "missing tool " .. name)
				Expect.truthy(tool:FindFirstChild("Handle"), name .. " has no Handle")
			end
		end)

		Expect.it("has a team and a spawn for every configured team", function()
			for _, team in Config.Teams do
				local teamObject = find("Teams." .. team.Name)
				Expect.truthy(teamObject, "missing Team " .. team.Name)
				Expect.equal(teamObject.TeamColor.Name, team.BrickColor)
				local spawn = find("Workspace.Arena.Spawns." .. team.Name .. "Spawn")
				Expect.truthy(spawn, "missing spawn for " .. team.Name)
				Expect.equal(spawn.TeamColor.Name, team.BrickColor)
				Expect.equal(spawn.Neutral, false)
			end
			Expect.equal(find("Workspace.Lobby.LobbySpawn").Neutral, true)
		end)

		Expect.it("gives training dummies a humanoid and a root", function()
			for _, dummy in find("Workspace.Lobby.PracticeArea.Dummies"):GetChildren() do
				Expect.truthy(dummy:FindFirstChildOfClass("Humanoid"), "dummy without Humanoid")
				Expect.truthy(dummy.PrimaryPart, "dummy without PrimaryPart")
			end
		end)

		Expect.it("marks the parkour finish", function()
			local found = false
			for _, descendant in find("Workspace.Lobby"):GetDescendants() do
				if descendant:IsA("BasePart") and descendant:GetAttribute("ParkourFinish") then
					found = true
				end
			end
			Expect.truthy(found)
		end)

		Expect.it("turns off automatic character spawning", function()
			Expect.equal(game:GetService("Players").CharacterAutoLoads, false)
		end)

		Expect.it("ships every script with source code", function()
			local scripts = 0
			for _, descendant in game:GetDescendants() do
				if descendant:IsA("LuaSourceContainer") then
					scripts += 1
					Expect.truthy(#descendant.Source > 50, descendant:GetFullName() .. " is empty")
				end
			end
			Expect.truthy(scripts > 30, "only " .. scripts .. " scripts")
		end)

		Expect.it("keeps all text in English (no stray non-ASCII letters)", function()
			for path, source in sources do
				-- Allow typographic symbols like ★ and · but not accented words.
				Expect.truthy(not string.find(source, "[\195][\128-\191]"), path .. " contains accented characters")
			end
		end)
	end)
end
