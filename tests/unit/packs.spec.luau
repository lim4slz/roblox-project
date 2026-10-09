--[[
	The client packs ("Work꞉ pet animation"): built from the game's modules,
	installed in a demo place exactly like the README says, and played.
]]

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local PetPacks = require("../../scripts/PetPacks")

local Color3 = roblox.Color3

local OUT = "build/packs-test/out"
local PLACES = "build/packs-test/places"

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	local built = false
	local function build()
		if not built then
			PetPacks.build({ out = OUT, places = PLACES })
			PetPacks.verify(OUT)
			built = true
		end
	end

	local function petsSeenBy(client)
		return client:run(function()
			local seen = {}
			local folder = workspace:FindFirstChild("AnimatedPets")
			for _, pet in if folder then folder:GetChildren() else {} do
				table.insert(seen, pet.Name)
			end
			table.sort(seen)
			return table.concat(seen, ",")
		end)
	end

	describe("Client packs", function()
		it("builds one folder per pet plus All in One, mirroring the Explorer, with a README", function()
			build()
			for _, pack in PetPacks.Packs do
				local dir = OUT .. "/" .. pack.dir
				expect(fs.isFile(dir .. "/README.txt")).toBe(true)
				expect(fs.isFile(dir .. "/ReplicatedStorage/" .. pack.folder .. ".rbxm")).toBe(true)
				expect(fs.isFile(dir .. "/StarterPlayer/StarterPlayerScripts/" .. pack.folder .. "Client.rbxm")).toBe(
					true
				)
				local entries = fs.readDir(dir)
				table.sort(entries)
				expect(table.concat(entries, ",")).toBe("README.txt,ReplicatedStorage,StarterPlayer")
			end
			for _, name in PetPacks.Placeholders do
				expect(fs.isFile(OUT .. "/" .. name .. "/README.txt")).toBe(true)
			end
			-- Every pet has a single pet pack, and All in One has them all.
			local single, all = {}, nil
			for _, pack in PetPacks.Packs do
				if pack.allInOne then
					all = pack
				else
					single[pack.pets[1]] = true
				end
			end
			for name in PetPacks.Pets do
				expect(single[name]).toBe(true)
				expect(table.find(all.pets, name)).never.toBeNil()
			end
		end)

		it("documents every setting of the Config in the README, in English", function()
			build()
			for _, pack in PetPacks.Packs do
				local readme = fs.readFile(OUT .. "/" .. pack.dir .. "/README.txt")
				-- The whole Config is in it, as an indented block.
				for line in string.gmatch(PetPacks.configSource(pack), "[^\n]+") do
					local shown = "    " .. string.gsub(line, "\t", "    ")
					expect(string.find(readme, shown, 1, true)).never.toBeNil()
				end
				for _, key in { "Pets", "GiveTo", "Attribute", "ShowOtherPlayersPets" } do
					expect(string.find(readme, "\n  Config." .. key .. "\n", 1, true)).never.toBeNil()
				end
				for _, key in { "Scale", "Spot", "Sound", "SoundStart", "Volume", "Texts", "Every" } do
					expect(string.find(readme, "\n  " .. key .. "\n", 1, true)).never.toBeNil()
				end
				expect(string.find(readme, "[ãõçáéíóúâêôà]")).toBeNil()
				-- The scripts point to the README by its real name.
				for _, source in { PetPacks.configSource(pack), PetPacks.clientSource(pack) } do
					expect(string.find(source, "README.txt", 1, true)).never.toBeNil()
					expect(string.find(source, "README.md", 1, true)).toBeNil()
				end
			end
		end)

		it("writes the READMEs as plain text a person would write, not markdown", function()
			build()
			local files = {}
			for _, pack in PetPacks.Packs do
				table.insert(files, OUT .. "/" .. pack.dir .. "/README.txt")
			end
			for _, name in PetPacks.Placeholders do
				table.insert(files, OUT .. "/" .. name .. "/README.txt")
			end
			for _, path in files do
				local readme = fs.readFile(path)
				for _, markdown in { "```", "**", "`", "|---", "](", "\n#" } do
					expect(string.find(readme, markdown, 1, true)).toBeNil()
				end
				-- Headings are underlined with = or - of the same length.
				local headings = 0
				for title, rule in string.gmatch(readme, "\n?([^\n]+)\n([=%-]+)\n") do
					if #rule > 3 then
						expect(#rule).toBe(#title)
						headings += 1
					end
				end
				expect(headings).toBeGreaterThan(0)
				-- Prose is wrapped; only code (indented four spaces) may run long.
				for line in string.gmatch(readme, "[^\n]+") do
					if string.sub(line, 1, 4) ~= "    " then
						expect(utf8.len(line)).toBeLessThanOrEqual(79)
					end
				end
			end
		end)

		for _, pack in PetPacks.Packs do
			it(
				pack.dir .. ": installed as the README says, every player gets " .. table.concat(pack.pets, " and "),
				function()
					build()
					local world = t.newWorld({ place = PLACES .. "/" .. pack.folder .. ".rbxl" })
					local server = world:createServer()
					server:start()
					local alice = server:addPlayer({ userId = 401, name = "Alice", runClient = true })
					local bob = server:addPlayer({ userId = 402, name = "Bob", runClient = true })
					world:advance(1)
					local expected = {}
					for _, pet in pack.pets do
						table.insert(expected, pet)
						table.insert(expected, pet)
					end
					table.sort(expected)
					expect(petsSeenBy(alice)).toBe(table.concat(expected, ","))
					expect(petsSeenBy(bob)).toBe(table.concat(expected, ","))

					-- The Config's defaults are the pets' own defaults.
					local config = alice:require("ReplicatedStorage." .. pack.folder .. ".Config")
					for _, pet in pack.pets do
						local defaults =
							alice:require("ReplicatedStorage." .. pack.folder .. ".Modules." .. pet .. "Pet").Defaults
						local settings = config[pet]
						expect(settings.Scale).toBe(1)
						expect(settings.Spot).toEqual(defaults.spot)
						expect(settings.Sound).toBe(defaults.sound)
						expect(settings.SoundStart).toBe(defaults.soundStart)
						expect(settings.Volume).toBe(defaults.volume)
						expect(settings.Texts).toEqual(defaults.texts)
						expect(settings.Every).toEqual(defaults.every)
					end
					world:assertHealthy()
				end
			)
		end

		it("uses the look of the models in Models (recolor in Studio)", function()
			build()
			local pack = PetPacks.Packs[1]
			local pet = pack.pets[1]
			local part = PetPacks.Pets[pet].bodyPart
			local world = t.newWorld({ place = PLACES .. "/" .. pack.folder .. ".rbxl" })
			local server = world:createServer()
			world:runIn(server.serverCtx, function()
				local model = game:GetService("ReplicatedStorage")[pack.folder].Models[pet]
				model[part].Color = Color3.fromRGB(20, 120, 255)
				model[part].Material = Enum.Material.Neon
			end)
			server:start()
			local alice = server:addPlayer({ userId = 411, name = "Alice", runClient = true })
			world:advance(1)
			local look = alice:run(function()
				local built = workspace.AnimatedPets[pet][part]
				return { color = built.Color, material = built.Material }
			end)
			expect(look.color).toEqual(Color3.fromRGB(20, 120, 255))
			expect(look.material).toBe(roblox.Enum.Material.Neon)
			world:assertHealthy()
		end)

		it("tells the developer what to do when the ReplicatedStorage file is missing", function()
			build()
			local pack = PetPacks.Packs[1]
			local world = t.newWorld({ place = PLACES .. "/" .. pack.folder .. ".rbxl" })
			local server = world:createServer()
			world:runIn(server.serverCtx, function()
				game:GetService("ReplicatedStorage")[pack.folder]:Destroy()
			end)
			server:start()
			local alice = server:addPlayer({ userId = 421, name = "Alice", runClient = true })
			world:advance(12)
			expect(petsSeenBy(alice)).toBe("")
			local warned = false
			for _, entry in world.logs do
				if
					entry.level == "warn"
					and string.find(entry.message, pack.folder .. " is missing from ReplicatedStorage", 1, true)
				then
					warned = true
				end
			end
			expect(warned).toBe(true)
			world:assertHealthy()
		end)
	end)
end
