--!nonstrict
-- Generates the map and asset models with Lune:
--
--   lune run map/build.luau
--
-- Writes assets/Arena.rbxm, assets/Lobby.rbxm, assets/Tools.rbxm and
-- assets/GameAudio.rbxm, which default.project.json pulls into the place.
-- Re-run it after changing anything under map/ or Shared/Config.luau.

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Builder = require("./lib/Builder")
local Arena = require("./lib/Arena")
local Lobby = require("./lib/Lobby")
local Tools = require("./lib/Tools")
local Audio = require("./lib/Audio")
local Config = require("../src/ReplicatedStorage/Shared/Config")

local OUTPUT = "assets"

local function toColor(rgb)
	return Builder.rgb(rgb[1], rgb[2], rgb[3])
end

local teams = {}
for _, team in Config.Teams do
	table.insert(teams, {
		Name = team.Name,
		Color = toColor(team.Color),
		LightColor = toColor(team.LightColor),
		DarkColor = toColor(team.DarkColor),
		BrickColor = team.BrickColor,
	})
end

local function countParts(root): number
	local count = 0
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") then
			count += 1
		end
	end
	return count
end

local function write(name: string, instance)
	local path = OUTPUT .. "/" .. name .. ".rbxm"
	fs.writeFile(path, roblox.serializeModel({ instance }))
	print(string.format("  %-22s %5d parts", path, countParts(instance)))
end

if not fs.isDir(OUTPUT) then
	fs.writeDir(OUTPUT)
end

print("Building map assets...")
local arena, brickCounts = Arena.build(teams)
write("Arena", arena)
for teamName, count in brickCounts do
	print(string.format("    %s tower: %d bricks", teamName, count))
end
write("Lobby", Lobby.build())
write("Tools", Tools.build())
local audio, soundCount = Audio.build()
write("GameAudio", audio)
print(string.format("    %d sounds", soundCount))
print("Done.")
process.exit(0)
