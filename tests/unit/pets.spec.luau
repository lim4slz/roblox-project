--[[
	Dog pet: rig data, procedural animation, follow logic and the client
	script running in the headless runtime.
]]

local roblox = require("@lune/roblox")
local Shared = require("../harness/Shared")

local CFrame, Vector3 = roblox.CFrame, roblox.Vector3

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	local DogModel = Shared.require("Pets.DogModel")
	local DogAnimation = Shared.require("Pets.DogAnimation")
	local PetFollow = Shared.require("Pets.PetFollow")
	local PetRig = Shared.require("Pets.PetRig")

	local parts = DogModel.Definition.parts
	local function partIndex(name)
		for index, def in parts do
			if def.name == name then
				return index
			end
		end
		error("no part " .. name)
	end

	local function corners(cframe, size)
		local result = {}
		local half = size / 2
		for _, x in { -1, 1 } do
			for _, y in { -1, 1 } do
				for _, z in { -1, 1 } do
					table.insert(result, cframe * Vector3.new(half.X * x, half.Y * y, half.Z * z))
				end
			end
		end
		return result
	end

	-- Lowest point of the four paws for a solved pose (0 = standing on the ground).
	local function lowestPaw(cframes)
		local lowest = math.huge
		for index, def in parts do
			if string.sub(def.name, 1, 3) == "Paw" then
				for _, corner in corners(cframes[index], def.size) do
					lowest = math.min(lowest, corner.Y)
				end
			end
		end
		return lowest
	end

	local function frontZ(cframes, name)
		local index = partIndex(name)
		local front = math.huge
		for _, corner in corners(cframes[index], parts[index].size) do
			front = math.min(front, corner.Z)
		end
		return front
	end

	local function stepFor(anim, seconds, speed)
		local barks = 0
		for _ = 1, math.floor(seconds * 60 + 0.5) do
			barks += anim:step(1 / 60, speed)
		end
		return barks
	end

	describe("Dog model", function()
		it("keeps the 28 original parts plus 4 hidden ones, each on a known bone", function()
			expect(#parts).toBe(32)
			local rig = PetRig.new(DogModel.Definition)
			local names = {}
			for _, def in parts do
				expect(names[def.name]).toBeNil()
				names[def.name] = true
			end
			-- With no pose every part sits exactly where the model puts it.
			local cframes = rig:solve(CFrame.identity, {}, {})
			for index, def in parts do
				expect((cframes[index].Position - def.cframe.Position).Magnitude).toBeLessThan(1e-4)
				expect(cframes[index].LookVector:Dot(def.cframe.LookVector)).toBeGreaterThan(0.9999)
			end
			expect(lowestPaw(cframes)).toBeCloseTo(0, 0.01)
			expect(function()
				PetRig.new({ bones = { { name = "Leg", parent = "Body", pivot = CFrame.identity } }, parts = {} })
			end).toThrow("must come after its parent")
		end)

		it("hides the mouth, tongue and eyelids inside the head until they are animated", function()
			local rig = PetRig.new(DogModel.Definition)
			local rest = rig:solve(CFrame.identity, {}, {})
			local face = frontZ(rest, "Snout")
			expect(frontZ(rest, "MouthOpen")).toBeGreaterThan(frontZ(rest, "HeadLower"))
			expect(frontZ(rest, "Tongue")).toBeGreaterThan(frontZ(rest, "HeadLower"))
			expect(frontZ(rest, "LidL")).toBeGreaterThan(frontZ(rest, "HeadUpper"))

			local open = rig:solve(CFrame.identity, {
				Jaw = CFrame.new(DogModel.JawOpenOffset),
				Lids = CFrame.new(DogModel.BlinkOffset),
			}, {})
			expect(frontZ(open, "MouthOpen")).toBeLessThan(face)
			expect(frontZ(open, "Tongue")).toBeLessThan(frontZ(open, "MouthOpen"))
			expect(frontZ(open, "LidL")).toBeLessThan(frontZ(open, "EyeL"))
			expect(frontZ(open, "LidR")).toBeLessThan(frontZ(open, "EyeR"))
		end)
	end)

	describe("Dog animation", function()
		it("idles, walks and runs depending on speed", function()
			local anim = DogAnimation.new(1)
			stepFor(anim, 1, 0)
			expect(anim:gait()).toBe("Idle")
			stepFor(anim, 1, 10)
			expect(anim:gait()).toBe("Walk")
			stepFor(anim, 1, 16)
			expect(anim:gait()).toBe("Walk")
			stepFor(anim, 1, 26)
			expect(anim:gait()).toBe("Run")
			stepFor(anim, 1, 0)
			expect(anim:gait()).toBe("Idle")
		end)

		it("woofs on its own at random intervals, in bursts of one to three barks", function()
			local function barkTimes(seed)
				local anim = DogAnimation.new(seed)
				local times = {}
				for frame = 1, 120 * 60 do
					for _ = 1, anim:step(1 / 60, if frame % 1200 < 600 then 0 else 12) do
						table.insert(times, frame / 60)
					end
				end
				return times
			end
			local times = barkTimes(42)
			expect(times).toEqual(barkTimes(42)) -- deterministic for a seed
			expect(times).never.toEqual(barkTimes(43))
			expect(times[1]).toBeGreaterThanOrEqual(1.5)
			expect(times[1]).toBeLessThanOrEqual(3.1)

			local bursts, size, largest = 1, 1, 1
			for index = 2, #times do
				local gap = times[index] - times[index - 1]
				if gap < 0.4 then
					-- 0.3 s apart, +-0.05 s of jitter, measured in 1/60 s frames.
					expect(gap).toBeGreaterThanOrEqual(0.23)
					size += 1
				else
					expect(gap).toBeGreaterThanOrEqual(3.5)
					expect(gap).toBeLessThanOrEqual(8 + DogAnimation.BarkLength + 0.1)
					bursts += 1
					size = 1
				end
				largest = math.max(largest, size)
			end
			expect(bursts).toBeGreaterThanOrEqual(12)
			expect(largest).toBeLessThanOrEqual(3)
		end)

		it("barks with a hop, a head snap, an open mouth and a happy squint", function()
			local anim = DogAnimation.new(5)
			stepFor(anim, 0.5, 0)
			anim:woof(1)
			expect(anim:step(1 / 60, 0)).toBe(1)
			expect(anim:isBarking()).toBe(true)
			stepFor(anim, 0.15, 0)
			local pose = anim:pose()
			expect(pose.Body.Position.Y).toBeGreaterThan(0.15)
			expect(math.deg(math.asin(pose.Head.LookVector.Y))).toBeGreaterThan(15)
			expect(pose.Jaw.Position).toEqual(DogModel.JawOpenOffset)
			expect(pose.Lids.Position).toEqual(DogModel.BlinkOffset)

			stepFor(anim, 0.6, 0)
			expect(anim:isBarking()).toBe(false)
			pose = anim:pose()
			expect(pose.Jaw.Position.Magnitude).toBe(0)
		end)

		it("keeps the paws on the ground (no sinking) in every gait, barking or not", function()
			local rig = PetRig.new(DogModel.Definition)
			for _, speed in { 0, 8, 16, 22, 28 } do
				local anim = DogAnimation.new(speed + 1)
				stepFor(anim, 1, speed)
				local lowest, highest = math.huge, -math.huge
				for _ = 1, 600 do
					anim:step(1 / 60, speed)
					local paw = lowestPaw(rig:solve(CFrame.identity, anim:pose(), {}))
					lowest = math.min(lowest, paw)
					if not anim:isBarking() then
						highest = math.max(highest, paw)
					end
				end
				expect(lowest).toBeGreaterThan(-0.06)
				-- Standing and walking stay close to the ground; running bounds.
				expect(highest).toBeLessThan(if speed < 20 then 0.15 else 0.5)
			end
		end)

		it("pants with the tongue out only while running, and blinks now and then", function()
			local anim = DogAnimation.new(9)
			stepFor(anim, 1, 26)
			expect(anim:pose().Jaw.Position).toEqual(DogModel.JawOpenOffset)

			local closedMouthFrames, blinkFrames = 0, 0
			for _ = 1, 600 do
				anim:step(1 / 60, 10)
				if not anim:isBarking() then
					local pose = anim:pose()
					if pose.Jaw.Position.Magnitude == 0 then
						closedMouthFrames += 1
					end
					if pose.Lids.Position.Magnitude > 0 then
						blinkFrames += 1
					end
				end
			end
			expect(closedMouthFrames).toBeGreaterThan(300)
			expect(blinkFrames).toBeGreaterThan(0)
		end)
	end)

	describe("Pet follow", function()
		local owner = CFrame.new(0, 3, 0)

		it("trots to its spot behind its owner, stops and looks at them", function()
			local state = PetFollow.new(Vector3.new(20, 0, 20), 0)
			for _ = 1, 5 * 60 do
				PetFollow.step(state, owner, 0, 1 / 60)
			end
			local goal = PetFollow.goal(owner)
			expect((Vector3.new(goal.X, 0, goal.Z) - state.position).Magnitude).toBeLessThan(1)
			expect(state.speed).toBeLessThan(0.05)
			local toOwner = (Vector3.new(0, 0, 0) - state.position).Unit
			expect(PetFollow.cframe(state).LookVector:Dot(toOwner)).toBeGreaterThan(0.95)
			-- The spot is behind and to the right of the owner.
			expect(goal.Z).toBeGreaterThan(0)
			expect(goal.X).toBeGreaterThan(0)
		end)

		it("walks to keep up with a walking owner and runs when it has to catch up", function()
			local function cruise(ownerSpeed)
				local state = PetFollow.new(PetFollow.goal(owner), 0)
				local position = owner.Position
				for _ = 1, 6 * 60 do
					position += Vector3.new(0, 0, -ownerSpeed / 60)
					PetFollow.step(state, CFrame.new(position), 0, 1 / 60)
				end
				return state.speed, (state.position - Vector3.new(position.X, 0, position.Z)).Magnitude
			end
			local walkSpeed, walkLag = cruise(16)
			expect(walkSpeed).toBeCloseTo(16, 0.2)
			expect(walkSpeed).toBeLessThan(17.5) -- still the walk gait
			expect(walkLag).toBeLessThan(10)
			local runSpeed = cruise(28)
			expect(runSpeed).toBeCloseTo(28, 0.2)

			local anim = DogAnimation.new(2)
			stepFor(anim, 1, runSpeed)
			expect(anim:gait()).toBe("Run")
		end)

		it("snaps next to its owner after a teleport and follows the ground", function()
			local state = PetFollow.new(PetFollow.goal(owner), 0)
			local far = CFrame.new(500, 40, -300)
			PetFollow.step(state, far, 37, 1 / 60)
			local goal = PetFollow.goal(far)
			expect((state.position - Vector3.new(goal.X, 37, goal.Z)).Magnitude).toBeLessThan(1e-3)
			expect(state.speed).toBe(0)

			for _ = 1, 60 do
				PetFollow.step(state, far, 38.5, 1 / 60) -- a small step up is smoothed
			end
			expect(state.position.Y).toBeCloseTo(38.5, 0.01)
			PetFollow.step(state, far, 20, 1 / 60) -- a big drop snaps
			expect(state.position.Y).toBe(20)
		end)
	end)

	describe("Dog pet on the client", function()
		local function dogsSeenBy(client)
			return client:run(function()
				local folder = workspace:FindFirstChild("Pets")
				return if folder then #folder:GetChildren() else 0
			end)
		end

		it("gives every character a dog that follows it and woofs with a bubble and a bark", function()
			local world = t.newWorld()
			local server = world:createServer()
			server:start()
			local alice = server:addPlayer({ userId = 101, name = "Alice", runClient = true })
			world:advance(1)

			local dog = alice:run(function()
				local model = workspace.Pets:FindFirstChild("Dog")
				local anchored, colliding = 0, 0
				for _, part in model:GetChildren() do
					if part:IsA("BasePart") then
						anchored += if part.Anchored then 1 else 0
						colliding += if part.CanCollide or part.CanQuery or part.CanTouch then 1 else 0
					end
				end
				return { parts = #model:GetChildren(), anchored = anchored, colliding = colliding }
			end)
			expect(dog.parts).toBe(32)
			expect(dog.anchored).toBe(32)
			expect(dog.colliding).toBe(0)

			-- Walk Alice 40 studs; the dog keeps up.
			local start = alice:position()
			local character = alice:character()
			for frame = 1, 75 do
				local position = start + Vector3.new(0, 0, -16 * frame / 30)
				alice:run(function()
					character:PivotTo(CFrame.new(position))
				end)
				world:step(1 / 30)
			end
			local body = alice:run(function()
				return workspace.Pets.Dog.Body.Position
			end)
			expect((body - alice:position()).Magnitude).toBeLessThan(12)

			-- Within a few seconds it barks: a sound and a WOOF bubble.
			local bubbles, texts = 0, {}
			for _ = 1, 8 * 30 do
				world:step(1 / 30)
				alice:run(function()
					for _, gui in workspace.Pets.Dog:GetChildren() do
						if gui:IsA("BillboardGui") then
							bubbles = math.max(bubbles, 1)
							texts[gui.Text.Text] = true
						end
					end
				end)
			end
			expect(bubbles).toBe(1)
			local barks = 0
			for _, sound in world.soundsPlayed do
				if sound.ctx == alice.ctx.id and string.match(sound.soundId, "^rbxassetid://%d+$") then
					barks += 1
					expect(sound.speed).toBeGreaterThanOrEqual(1.05)
				end
			end
			expect(barks).toBeGreaterThan(0)
			for text in texts do
				expect(text).toMatch("^[Ww][Oo][Oo][Ff]!+$")
			end
			world:assertHealthy()
		end)

		it("waits for a streamed-in character's root before showing its dog", function()
			local world = t.newWorld()
			local server = world:createServer()
			local alice = server:addPlayer({ userId = 121, name = "Alice" })
			local DogPet = alice:require("StarterPlayer.StarterPlayerScripts.Client.Pets.DogPet")
			alice:run(function()
				local folder = Instance.new("Folder")
				folder.Parent = workspace
				local character = Instance.new("Model")
				local dog = DogPet.new(character, folder, RaycastParams.new(), 1)
				dog:update(1 / 30)
				expect(dog.model.Parent).toBeNil()

				local root = Instance.new("Part")
				root.Name = "HumanoidRootPart"
				root.Size = Vector3.new(2, 2, 1)
				root.CFrame = CFrame.new(50, 3, 50)
				root.Parent = character
				dog:update(1 / 30)
				expect(dog.model.Parent).toBe(folder)
				local body = dog.model:FindFirstChild("Body") :: BasePart
				expect((body.Position - Vector3.new(50, 3, 50)).Magnitude).toBeLessThan(6)

				dog:woof(1)
				dog:update(1 / 30)
				expect(dog.model:FindFirstChild("WoofBubble")).never.toBeNil()
				dog:destroy()
				expect(folder:FindFirstChild("Dog")).toBeNil()
			end)
			world:assertHealthy()
		end)

		it("renders the other players' dogs too and cleans up on respawn and leave", function()
			local world = t.newWorld()
			local server = world:createServer()
			server:start()
			local alice = server:addPlayer({ userId = 111, name = "Alice", runClient = true })
			local bob = server:addPlayer({ userId = 112, name = "Bob", runClient = true })
			world:advance(1)
			expect(dogsSeenBy(alice)).toBe(2)
			expect(dogsSeenBy(bob)).toBe(2)

			world:runIn(server.serverCtx, function()
				game:GetService("Players"):FindFirstChild("Alice"):LoadCharacter()
			end)
			world:advance(0.5)
			expect(dogsSeenBy(bob)).toBe(2)

			server:removePlayer(alice)
			world:advance(0.5)
			expect(dogsSeenBy(bob)).toBe(1)
			world:assertHealthy()
		end)
	end)
end
