--[[
	Shared pet pieces: building pets from a template model (recolors and
	accessories), uniform scale, and PetSpawner's Config (who gets which pet,
	per-pet settings, the react API) running on real clients.
]]

local roblox = require("@lune/roblox")
local Datatypes = require("../harness/Datatypes")
local Shared = require("../harness/Shared")
local Geo = require("./PetGeometry")

local CFrame, Vector3 = Datatypes.CFrame, roblox.Vector3

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	local DogModel = Shared.require("Pets.DogModel")
	local PetRig = Shared.require("Pets.PetRig")

	describe("PetRig scale", function()
		it("scales the whole rig about its origin, poses included", function()
			local parts = DogModel.Definition.parts
			local normal = PetRig.new(DogModel.Definition)
			local big = PetRig.new(DogModel.Definition, 2.5)
			local pose = {
				Body = CFrame.new(0, 0.2, 0) * CFrame.Angles(0.1, 0.2, 0),
				Head = CFrame.Angles(0.3, 0, 0),
				Jaw = CFrame.new(DogModel.JawOpenOffset),
			}
			local root = CFrame.new(10, 2, -4) * CFrame.Angles(0, 1, 0)
			local a = normal:solve(CFrame.identity, pose, {})
			local b = big:solve(CFrame.identity, pose, {})
			local c = big:solve(root, pose, {})
			for index in parts do
				expect((b[index].Position - a[index].Position * 2.5).Magnitude).toBeLessThan(1e-4)
				expect(b[index].LookVector:Dot(a[index].LookVector)).toBeGreaterThan(0.9999)
				expect((c[index].Position - root * b[index].Position).Magnitude).toBeLessThan(1e-4)
			end
			-- Scaled about the ground point under the pet: still standing on the ground.
			expect(Geo.lowest(parts, big:solve(CFrame.identity, {}, {}), function(name)
				return string.sub(name, 1, 3) == "Paw"
			end, 2.5)).toBeCloseTo(0, 0.01)
			expect(function()
				PetRig.new(DogModel.Definition, 0)
			end).toThrow("scale must be positive")
		end)

		it("places pinned bones exactly where it is told and their children with them", function()
			local rig = PetRig.new(DogModel.Definition)
			local pin = CFrame.new(5, 6, 7) * CFrame.Angles(0, 0.5, 0)
			rig:solve(CFrame.new(100, 0, 0), {}, {}, { Head = pin })
			expect(rig:boneCFrame("Head")).toEqual(pin)
			local headDef, earDef
			for _, bone in DogModel.Definition.bones do
				if bone.name == "Head" then
					headDef = bone
				elseif bone.name == "EarL" then
					earDef = bone
				end
			end
			local expected = pin * headDef.pivot:Inverse() * earDef.pivot
			expect((rig:boneCFrame("EarL").Position - expected.Position).Magnitude).toBeLessThan(1e-4)
		end)
	end)

	describe("PetKit.build", function()
		it("dresses the pet like its template and attaches accessories to the closest bone", function()
			local result = Shared.run(function()
				local PetKit = require(game:GetService("ReplicatedStorage").Shared.Pets.PetKit)
				local SharedDogModel = require(game:GetService("ReplicatedStorage").Shared.Pets.DogModel)
				local SharedPetRig = require(game:GetService("ReplicatedStorage").Shared.Pets.PetRig)

				-- The template sits somewhere in the world, built from the definition.
				local where = CFrame.new(40, 10, -30) * CFrame.Angles(0, math.rad(30), 0)
				local template = Instance.new("Model")
				template.Name = "Dog"
				for _, def in SharedDogModel.Definition.parts do
					local part = Instance.new("Part")
					part.Name = def.name
					part.Size = def.size
					part.CFrame = where * def.cframe
					part.Color = def.color
					part.Parent = template
				end
				local body = template:FindFirstChild("Body") :: Part
				body.Color = Color3.fromRGB(10, 20, 30)
				body.Material = Enum.Material.Neon
				local sparkles = Instance.new("Sparkles")
				sparkles.Parent = body
				-- A hat on the head (no Bone attribute) and a bow on the tail.
				local hat = Instance.new("Part")
				hat.Name = "Hat"
				hat.Size = Vector3.new(0.6, 0.5, 0.6)
				hat.CFrame = where * CFrame.new(-0.02, 3.45, -1.15)
				hat.Parent = template
				local bow = Instance.new("Part")
				bow.Name = "Bow"
				bow.Size = Vector3.new(0.3, 0.3, 0.1)
				bow.CFrame = where * CFrame.new(0, 2.3, 1.3)
				bow:SetAttribute("Bone", "Tail")
				bow.Parent = template
				-- A typo in the Bone attribute: a warning, and the closest bone instead.
				local badge = Instance.new("Part")
				badge.Name = "Badge"
				badge.Size = Vector3.new(0.2, 0.2, 0.05)
				badge.CFrame = where * CFrame.new(0.85, 1.7, 0.2)
				badge:SetAttribute("Bone", "Wing")
				badge.Parent = template

				local model, parts, definition = PetKit.build("Dog", SharedDogModel.Definition, template, 2)
				local rig = SharedPetRig.new(definition, 2)
				local pose = { Head = CFrame.Angles(0, math.rad(60), 0) }
				local cframes = rig:solve(CFrame.identity, pose, {})
				local byName = {}
				for index, part in parts do
					byName[part.Name] = { part = part, cframe = cframes[index], def = definition.parts[index] }
				end
				local headTop = byName.HeadTop
				local hatEntry = byName.Hat
				return {
					count = #parts,
					children = #model:GetChildren(),
					bodyColor = byName.Body.part.Color,
					bodyMaterial = byName.Body.part.Material,
					bodySparkles = byName.Body.part:FindFirstChild("Sparkles") ~= nil,
					bodySize = byName.Body.part.Size,
					hatBone = hatEntry.def.bone,
					bowBone = byName.Bow.def.bone,
					badgeBone = byName.Badge.def.bone,
					hatSize = hatEntry.part.Size,
					anchored = hatEntry.part.Anchored and not hatEntry.part.CanCollide,
					-- The hat stays on top of the head when the head turns.
					hatAboveHead = (hatEntry.cframe.Position - headTop.cframe.Position).Magnitude,
					restHatAboveHead = (Vector3.new(-0.02, 3.45, -1.15) - Vector3.new(-0.018, 3.162, -1.137)).Magnitude
						* 2,
					primary = model.PrimaryPart == byName.Body.part,
				}
			end)
			expect(result.count).toBe(#DogModel.Definition.parts + 3)
			expect(result.badgeBone).toBe("Body")
			local warned = false
			for _, entry in Shared.world().logs do
				if
					entry.level == "warn"
					and string.find(entry.message, 'has Bone "Wing", but Dog has no such bone', 1, true)
				then
					warned = true
				end
			end
			expect(warned).toBe(true)
			expect(result.children).toBe(result.count)
			expect(result.bodyColor).toEqual(roblox.Color3.fromRGB(10, 20, 30))
			expect(result.bodyMaterial).toBe(roblox.Enum.Material.Neon)
			expect(result.bodySparkles).toBe(true)
			expect(result.bodySize).toEqual(Vector3.new(1.558, 0.971, 2.405) * 2)
			expect(result.hatBone).toBe("Head")
			expect(result.bowBone).toBe("Tail")
			expect(result.hatSize).toEqual(Vector3.new(1.2, 1, 1.2))
			expect(result.anchored).toBe(true)
			expect(result.hatAboveHead).toBeCloseTo(result.restHatAboveHead, 1e-3)
			expect(result.primary).toBe(true)
		end)

		it("builds plain blocks (and wedges) from the definition when there is no template", function()
			local result = Shared.run(function()
				local Pets = game:GetService("ReplicatedStorage").Shared.Pets
				local PetKit = require(Pets.PetKit)
				local SnakeModel = require(Pets.SnakeModel)
				local _, parts = PetKit.build("Snake", SnakeModel.Definition, nil, 1)
				local wedges, flags = 0, 0
				for _, part in parts do
					wedges += if (part :: Part).Shape == Enum.PartType.Wedge then 1 else 0
					flags += if part.Anchored
							and not part.CanCollide
							and not part.CanQuery
							and not part.CanTouch
						then 1
						else 0
				end
				return { count = #parts, wedges = wedges, flags = flags }
			end)
			expect(result.count).toBe(25)
			expect(result.wedges).toBe(4) -- the tongue's fork and the fangs
			expect(result.flags).toBe(25)
		end)
	end)

	describe("PetSpawner", function()
		-- A world where clients run the spawner with `config` instead of the game's own.
		local function setup(config, names)
			local world = t.newWorld()
			local server = world:createServer()
			local clients = {}
			for index, name in names do
				clients[index] = server:addPlayer({ userId = 300 + index, name = name })
			end
			world:advance(0.5)
			for _, client in clients do
				local PetSpawner = client:require("ReplicatedStorage.Shared.Pets.PetSpawner")
				client:run(function()
					PetSpawner.start(config)
				end)
			end
			world:advance(0.5)
			return world, server, clients
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

		local function setAttribute(world, server, name, value)
			world:runIn(server.serverCtx, function()
				game:GetService("Players"):FindFirstChild(name):SetAttribute("Pet", value)
			end)
			world:advance(0.2)
		end

		it("gives the Config's pets to everyone, and a player's Pet attribute overrides them", function()
			local world, server, clients = setup({ Pets = { "Dog", "Snake" } }, { "Alice", "Bob" })
			local alice = clients[1]
			expect(petsSeenBy(alice)).toBe("Dog,Dog,Snake,Snake")
			setAttribute(world, server, "Bob", "Snake")
			expect(petsSeenBy(alice)).toBe("Dog,Snake,Snake")
			setAttribute(world, server, "Bob", "")
			expect(petsSeenBy(alice)).toBe("Dog,Snake")
			setAttribute(world, server, "Bob", nil)
			expect(petsSeenBy(alice)).toBe("Dog,Dog,Snake,Snake")
			world:assertHealthy()
		end)

		it("in Attribute mode only players with the Pet attribute get pets", function()
			local world, server, clients = setup({ Pets = { "Dog" }, GiveTo = "Attribute" }, { "Alice", "Bob" })
			local bob = clients[2]
			expect(petsSeenBy(bob)).toBe("")
			setAttribute(world, server, "Alice", " Dog , Snake ")
			expect(petsSeenBy(bob)).toBe("Dog,Snake")
			-- Respawning rebuilds them.
			world:runIn(server.serverCtx, function()
				game:GetService("Players"):FindFirstChild("Alice"):LoadCharacter()
			end)
			world:advance(0.5)
			expect(petsSeenBy(bob)).toBe("Dog,Snake")
			world:assertHealthy()
		end)

		it("can show each player only their own pets", function()
			local world, _, clients = setup({ Pets = { "Dog" }, ShowOtherPlayersPets = false }, { "Alice", "Bob" })
			expect(petsSeenBy(clients[1])).toBe("Dog")
			expect(petsSeenBy(clients[2])).toBe("Dog")
			world:assertHealthy()
		end)

		it("warns once about a pet name it does not know and keeps going", function()
			local world, _, clients = setup({ Pets = { "Dog", "Unicorn" } }, { "Alice" })
			expect(petsSeenBy(clients[1])).toBe("Dog")
			local warnings = 0
			for _, entry in world.logs do
				if entry.level == "warn" and string.find(entry.message, 'no pet called "Unicorn"', 1, true) then
					warnings += 1
				end
			end
			expect(warnings).toBe(1)
			world:assertHealthy()
		end)

		it("explains Config mistakes in the output and keeps the pets working", function()
			local world, _, clients = setup({
				Pets = { "Dog" },
				GiveTo = "attribute",
				Dog = { Scale = -2, Every = { 8, 3 }, Texts = "WOOF", Spot = 5, Volume = "loud" },
			}, { "Alice" })
			world:advance(5)
			expect(petsSeenBy(clients[1])).toBe("Dog")
			local size = clients[1]:run(function()
				return workspace.AnimatedPets.Dog.Body.Size
			end)
			expect(size).toEqual(Vector3.new(1.558, 0.971, 2.405))
			local messages = {}
			for _, entry in world.logs do
				if entry.level == "warn" then
					table.insert(messages, entry.message)
				end
			end
			local all = table.concat(messages, "\n")
			for _, expected in
				{
					'Config.GiveTo should be "Everyone" or "Attribute"',
					"Config.Dog.Scale should be a number above 0",
					"Config.Dog.Texts should be a list of words",
					"Config.Dog.Spot should be a Vector3",
					"Config.Dog.Volume should be a number from 0 to 10",
				}
			do
				expect(string.find(all, expected, 1, true)).never.toBeNil()
			end
			-- { 8, 3 } is read as { 3, 8 }: no warning, no error.
			expect(string.find(all, "Config.Dog.Every", 1, true)).toBeNil()
			world:assertHealthy()
		end)

		it("applies per-pet settings and lets other scripts make a pet react", function()
			local world, _, clients = setup({
				Pets = { "Dog" },
				Dog = { Scale = 2, Texts = { "ARF!" }, Every = false, Sound = "", Spot = Vector3.new(-3, 0, 2) },
			}, { "Alice" })
			local alice = clients[1]
			world:advance(10)
			local before = alice:run(function()
				local dog = workspace.AnimatedPets.Dog
				local bubbles = 0
				for _, child in dog:GetChildren() do
					bubbles += if child:IsA("BillboardGui") then 1 else 0
				end
				return { size = dog.Body.Size, bubbles = bubbles, sound = dog.HeadTop:FindFirstChildOfClass("Sound") }
			end)
			expect(before.size).toEqual(Vector3.new(1.558, 0.971, 2.405) * 2)
			expect(before.bubbles).toBe(0) -- Every = false: never on its own
			expect(before.sound).toBeNil() -- Sound = "": silent

			local PetSpawner = alice:require("ReplicatedStorage.Shared.Pets.PetSpawner")
			local text = alice:run(function()
				local player = game:GetService("Players").LocalPlayer
				expect(#PetSpawner.getPets(player)).toBe(1)
				PetSpawner.react(player, "Snake") -- not this player's pet: nothing happens
				PetSpawner.react(player, "Dog", 1)
				return nil
			end)
			expect(text).toBeNil()
			world:step(1 / 30)
			world:step(1 / 30)
			local bubble = alice:run(function()
				local gui = workspace.AnimatedPets.Dog:FindFirstChild("WoofBubble")
				return gui and gui.Text.Text
			end)
			expect(bubble).toBe("ARF!")
			-- The spot is on the left: the dog ends up on Alice's left.
			local side = alice:run(function()
				local root = game:GetService("Players").LocalPlayer.Character.HumanoidRootPart
				return root.CFrame:PointToObjectSpace(workspace.AnimatedPets.Dog.Body.Position).X
			end)
			expect(side).toBeLessThan(0)

			alice:run(function()
				PetSpawner.stop()
			end)
			expect(petsSeenBy(alice)).toBe("")
			world:assertHealthy()
		end)
	end)
end
