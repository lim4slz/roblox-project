--[[
	Crab pet: rig data, sideways scuttle, SNAP and idle animation, and the
	client module running in the headless runtime.
]]

local roblox = require("@lune/roblox")
local Datatypes = require("../harness/Datatypes")
local Shared = require("../harness/Shared")
local Geo = require("./PetGeometry")

local CFrame, Vector3 = Datatypes.CFrame, roblox.Vector3

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	local CrabModel = Shared.require("Pets.CrabModel")
	local CrabAnimation = Shared.require("Pets.CrabAnimation")
	local CrabPet = Shared.require("Pets.CrabPet")
	local PetRig = Shared.require("Pets.PetRig")

	local parts = CrabModel.Definition.parts
	local NEVER = { math.huge, math.huge }

	local function stepFor(anim, seconds, speed)
		local snaps = 0
		for _ = 1, math.floor(seconds * 60 + 0.5) do
			snaps += anim:step(1 / 60, speed or 0)
		end
		return snaps
	end

	local function solve(rig, anim)
		return rig:solve(CFrame.identity, anim:pose(), {})
	end

	local function isFoot(name)
		return string.sub(name, 1, 4) == "Shin"
	end

	-- Lowest point of each shin (the feet), by leg.
	local function feet(cframes)
		local result = {}
		for _, leg in { "FL", "FR", "BL", "BR" } do
			result[leg] = Geo.lowest(parts, cframes, function(name)
				return name == "Shin" .. leg
			end)
		end
		return result
	end

	-- Angle of the left pincer's outer finger: below 0 = shut, above = open.
	local function pincerOpen(pose)
		return math.deg(select(3, pose.FingerLOut:ToEulerAnglesXYZ()))
	end

	describe("Crab model", function()
		it("keeps the 26 original parts plus 5 hidden ones, each on a known bone", function()
			expect(#parts).toBe(31)
			local names = {}
			for _, def in parts do
				expect(names[def.name]).toBeNil()
				names[def.name] = true
			end
			local rig = PetRig.new(CrabModel.Definition)
			local cframes = rig:solve(CFrame.identity, {}, {})
			for index, def in parts do
				expect((cframes[index].Position - def.cframe.Position).Magnitude).toBeLessThan(1e-4)
				expect(cframes[index].LookVector:Dot(def.cframe.LookVector)).toBeGreaterThan(0.9999)
			end
			-- Standing on its four feet, like in the art.
			expect(Geo.lowest(parts, cframes)).toBeCloseTo(0, 0.01)
			expect(Geo.lowest(parts, cframes, isFoot)).toBeCloseTo(0, 0.01)
		end)

		it("hides the mouth, eyelids and eye necks until they are animated", function()
			local rig = PetRig.new(CrabModel.Definition)
			local rest = rig:solve(CFrame.identity, {}, {})
			expect(Geo.inside(parts, rest, "Mouth", "Belly", 0.001)).toBe(true)
			for _, side in { "L", "R" } do
				expect(Geo.inside(parts, rest, "Lid" .. side, "EyeRim" .. side, 0.001)).toBe(true)
				expect(Geo.inside(parts, rest, "Neck" .. side, "Shell", 0.001)).toBe(true)
			end

			local open = rig:solve(CFrame.identity, {
				Mouth = CFrame.new(CrabModel.MouthOpenOffset),
				StalkL = CFrame.new(CrabModel.EyePopOffset),
				StalkR = CFrame.new(CrabModel.EyePopOffset),
				LidL = CFrame.new(CrabModel.BlinkOffset),
				LidR = CFrame.new(CrabModel.BlinkOffset),
			}, {})
			expect(Geo.frontZ(parts, open, "Mouth")).toBeLessThan(Geo.frontZ(parts, open, "Belly"))
			local shellTop = parts[Geo.partIndex(parts, "Shell")].cframe.Position.Y
				+ parts[Geo.partIndex(parts, "Shell")].size.Y / 2
			for _, side in { "L", "R" } do
				expect(Geo.frontZ(parts, open, "Lid" .. side)).toBeLessThan(Geo.frontZ(parts, open, "EyeRim" .. side))
				-- Popped up, the neck fills the gap between the shell and the stalk
				-- (the right one ends a millimetre under its stalk, like in the art).
				local neck = open[Geo.partIndex(parts, "Neck" .. side)]
				local neckSize = parts[Geo.partIndex(parts, "Neck" .. side)].size
				local stalk = open[Geo.partIndex(parts, "Stalk" .. side)]
				local stalkSize = parts[Geo.partIndex(parts, "Stalk" .. side)].size
				expect(neck.Position.Y - neckSize.Y / 2).toBeLessThan(shellTop)
				expect(neck.Position.Y + neckSize.Y / 2).toBeGreaterThan(stalk.Position.Y - stalkSize.Y / 2 - 0.002)
			end
		end)
	end)

	describe("Crab scuttle", function()
		it("stands, scuttles and hurries depending on speed", function()
			local anim = CrabAnimation.new(1, NEVER)
			stepFor(anim, 1, 0)
			expect(anim:gait()).toBe("Idle")
			stepFor(anim, 1, 12)
			expect(anim:gait()).toBe("Walk")
			stepFor(anim, 1, 26)
			expect(anim:gait()).toBe("Run")
			stepFor(anim, 1, 0)
			expect(anim:gait()).toBe("Idle")
		end)

		it("turns its side to where it goes, either side, and faces ahead again when it stops", function()
			local sides = {}
			for seed = 1, 12 do
				local anim = CrabAnimation.new(seed, NEVER)
				stepFor(anim, 0.5, 0)
				expect(anim:sideways()).toBe(0)
				stepFor(anim, 1, 12)
				local sideways = anim:sideways()
				expect(math.abs(sideways)).toBeGreaterThan(0.99)
				sides[if sideways > 0 then 1 else -1] = true
				-- The whole crab is turned a quarter turn.
				local yaw = select(2, anim:pose().Root:ToEulerAnglesYXZ())
				expect(math.deg(math.abs(yaw))).toBeGreaterThan(89)
				stepFor(anim, 1.5, 0)
				expect(math.abs(anim:sideways())).toBeLessThan(0.01)
			end
			expect(sides[1]).toBe(true)
			expect(sides[-1]).toBe(true)
		end)

		it("keeps its feet on the ground, lifting the diagonal pairs in turn", function()
			local rig = PetRig.new(CrabModel.Definition)
			for _, speed in { 8, 16, 26 } do
				local anim = CrabAnimation.new(2, NEVER)
				stepFor(anim, 1, speed)
				local lowest, highest, together, apart = math.huge, 0, 0, 0
				for _ = 1, 3 * 60 do
					anim:step(1 / 60, speed)
					local cframes = solve(rig, anim)
					lowest = math.min(lowest, Geo.lowest(parts, cframes))
					local foot = feet(cframes)
					highest = math.max(highest, foot.FL, foot.FR)
					-- FL and BR step together; FL and FR take turns.
					if foot.FL > 0.1 then
						together += if foot.BR > 0.05 then 1 else 0
						apart += if foot.FR < 0.02 then 1 else 0
					end
				end
				expect(lowest).toBeGreaterThan(-0.01)
				expect(lowest).toBeLessThan(0.02)
				expect(highest).toBeGreaterThan(0.25)
				expect(together).toBeGreaterThan(10)
				expect(apart).toBeGreaterThan(10)
			end
		end)

		it("looks where it is going with both eyes when it scuttles", function()
			local anim = CrabAnimation.new(3, NEVER)
			stepFor(anim, 2, 12)
			local pose = anim:pose()
			local side = anim:sideways()
			for _, stalk in { "StalkL", "StalkR" } do
				local yaw = select(2, pose[stalk]:ToEulerAnglesXYZ())
				-- Right side first: the eyes turn right (negative yaw), and the other way round.
				expect(math.deg(yaw * -side)).toBeGreaterThan(40)
			end
		end)

		it("grows with its scale", function()
			local anim = CrabAnimation.new(4, NEVER)
			local rig = PetRig.new(CrabModel.Definition, 2)
			local low, high = math.huge, -math.huge
			anim:react()
			for _ = 1, 3 * 60 do
				anim:step(1 / 60, 12)
				local lowest = Geo.lowest(parts, solve(rig, anim), nil, 2)
				low = math.min(low, lowest)
				high = math.max(high, lowest)
			end
			expect(low).toBeGreaterThan(-0.02)
			expect(high).toBeGreaterThan(2 * 0.15) -- the SNAP hops twice as high
		end)
	end)

	describe("Crab SNAP and fidgets", function()
		it("raises its claws, snaps three times in time with the sound, pops its eyes and hops", function()
			local rig = PetRig.new(CrabModel.Definition)
			local anim = CrabAnimation.new(5, NEVER)
			stepFor(anim, 1)
			anim:react()
			-- The SNAP is reported at its first snap, when the sound's first click plays.
			local frames, reported = 0, nil
			while reported == nil do
				frames += 1
				if anim:step(1 / 120, 0) == 1 then
					reported = frames / 120
				end
				expect(frames).toBeLessThan(60)
			end
			expect(reported).toBeGreaterThanOrEqual(CrabAnimation.Windup)
			expect(reported).toBeLessThanOrEqual(CrabAnimation.Windup + 1 / 60 + 1e-9)
			expect(anim:isReacting()).toBe(true)

			local rest = rig:solve(CFrame.identity, {}, {})
			local restPincer = rest[Geo.partIndex(parts, "PincerL")].Position.Y
			local shuts, wasShut, popped, open, hopped, raised = {}, false, false, false, 0, 0
			local now = reported
			while now < CrabAnimation.SnapLength - 0.05 do
				anim:step(1 / 120, 0)
				now += 1 / 120
				local pose = anim:pose()
				local shut = pincerOpen(pose) < 0
				if shut and not wasShut then
					table.insert(shuts, now)
				end
				wasShut = shut
				popped = popped or pose.StalkL.Position == CrabModel.EyePopOffset
				open = open or pose.Mouth.Position == CrabModel.MouthOpenOffset
				hopped = math.max(hopped, pose.Root.Position.Y)
				local cframes = rig:solve(CFrame.identity, pose, {})
				raised = math.max(raised, cframes[Geo.partIndex(parts, "PincerL")].Position.Y - restPincer)
			end
			expect(#shuts).toBe(3)
			for index, at in CrabAnimation.Snaps do
				expect(math.abs(shuts[index] - (CrabAnimation.Windup + at))).toBeLessThan(0.05)
			end
			expect(popped).toBe(true)
			expect(open).toBe(true)
			expect(hopped).toBeGreaterThan(0.1)
			expect(raised).toBeGreaterThan(0.3)

			stepFor(anim, 0.2)
			expect(anim:isReacting()).toBe(false)
			local pose = anim:pose()
			expect(pose.Mouth.Position.Magnitude).toBe(0)
			expect(pose.StalkL.Position.Magnitude).toBe(0)
			expect(Geo.lowest(parts, solve(rig, anim))).toBeCloseTo(0, 0.01)
		end)

		it("snaps on its own at random intervals, and never when told not to", function()
			local function snapTimes(seed, every)
				local anim = CrabAnimation.new(seed, every)
				local times = {}
				for frame = 1, 90 * 60 do
					for _ = 1, anim:step(1 / 60, if frame % 1200 < 600 then 0 else 12) do
						table.insert(times, frame / 60)
					end
				end
				return times
			end
			local times = snapTimes(42)
			expect(times).toEqual(snapTimes(42))
			expect(times).never.toEqual(snapTimes(43))
			expect(times[1]).toBeGreaterThanOrEqual(2 + CrabAnimation.Windup)
			expect(times[1]).toBeLessThanOrEqual(4 + CrabAnimation.Windup + 0.05)
			local every = CrabAnimation.Every
			for index = 2, #times do
				local gap = times[index] - times[index - 1]
				expect(gap).toBeGreaterThanOrEqual(every[1] + CrabAnimation.SnapLength - 0.05)
				expect(gap).toBeLessThanOrEqual(every[2] + CrabAnimation.SnapLength + 0.05)
			end
			expect(#times).toBeGreaterThanOrEqual(8)
			expect(#snapTimes(42, NEVER)).toBe(0)
		end)

		it("does the SNAPs asked for back to back, at most three queued", function()
			local anim = CrabAnimation.new(6, NEVER)
			stepFor(anim, 0.5)
			anim:react(2)
			expect(stepFor(anim, 3 * CrabAnimation.SnapLength)).toBe(2)
			anim:react(10)
			expect(stepFor(anim, 10 * CrabAnimation.SnapLength)).toBe(3)
		end)

		it("looks around with each eye on its own, blinks, winks and opens a pincer now and then", function()
			local anim = CrabAnimation.new(7, NEVER)
			local apart, blinks, winks, pinches = 0, 0, 0, 0
			local wasBlinking, wasPinching = false, false
			for _ = 1, 60 * 60 do
				anim:step(1 / 60, 0)
				local pose = anim:pose()
				local yawL = select(2, pose.StalkL:ToEulerAnglesXYZ())
				local yawR = select(2, pose.StalkR:ToEulerAnglesXYZ())
				apart += if math.abs(yawL - yawR) > math.rad(15) then 1 else 0
				local left = pose.LidL.Position == CrabModel.BlinkOffset
				local right = pose.LidR.Position == CrabModel.BlinkOffset
				local blinking = left or right
				if blinking and not wasBlinking then
					blinks += 1
					winks += if left ~= right then 1 else 0
				end
				wasBlinking = blinking
				local pinching = math.max(pincerOpen(pose), -math.deg(select(3, pose.FingerROut:ToEulerAnglesXYZ())))
					> 10
				pinches += if pinching and not wasPinching then 1 else 0
				wasPinching = pinching
			end
			expect(apart).toBeGreaterThan(10 * 60) -- seconds with the eyes looking different ways
			expect(blinks).toBeGreaterThanOrEqual(12)
			expect(blinks).toBeLessThanOrEqual(30)
			expect(winks).toBeGreaterThanOrEqual(1)
			expect(winks).toBeLessThan(blinks)
			expect(pinches).toBeGreaterThanOrEqual(10)
		end)
	end)

	describe("Crab pet on the client", function()
		it("gives every character a crab that scuttles after it and snaps with a bubble and claw clicks", function()
			local world = t.newWorld()
			local server = world:createServer()
			server:start()
			local alice = server:addPlayer({ userId = 401, name = "Alice", runClient = true })
			world:advance(1)

			local crab = alice:run(function()
				local model = workspace.AnimatedPets:FindFirstChild("Crab")
				local anchored, colliding = 0, 0
				for _, part in model:GetChildren() do
					if part:IsA("BasePart") then
						anchored += if part.Anchored then 1 else 0
						colliding += if part.CanCollide or part.CanQuery or part.CanTouch then 1 else 0
					end
				end
				return { parts = #model:GetChildren(), anchored = anchored, colliding = colliding }
			end)
			expect(crab.parts).toBe(31)
			expect(crab.anchored).toBe(31)
			expect(crab.colliding).toBe(0)

			local start = alice:position()
			local character = alice:character()
			for frame = 1, 75 do
				local position = start + Vector3.new(0, 0, -16 * frame / 30)
				alice:run(function()
					character:PivotTo(CFrame.new(position))
				end)
				world:step(1 / 30)
			end
			local shell = alice:run(function()
				return workspace.AnimatedPets.Crab.Shell.Position
			end)
			expect((shell - alice:position()).Magnitude).toBeLessThan(10)

			local bubbles, texts = 0, {}
			for _ = 1, 10 * 30 do
				world:step(1 / 30)
				alice:run(function()
					for _, gui in workspace.AnimatedPets.Crab:GetChildren() do
						if gui:IsA("BillboardGui") then
							bubbles = 1
							texts[gui.Text.Text] = true
						end
					end
				end)
			end
			expect(bubbles).toBe(1)
			for text in texts do
				expect(table.find(CrabPet.Defaults.texts, text)).never.toBeNil()
			end
			local snaps = 0
			for _, sound in world.soundsPlayed do
				if sound.ctx == alice.ctx.id and sound.soundId == CrabPet.Defaults.sound then
					snaps += 1
					expect(sound.speed).toBeGreaterThanOrEqual(0.95)
					expect(sound.speed).toBeLessThanOrEqual(1.1)
				end
			end
			expect(snaps).toBeGreaterThan(0)
			world:assertHealthy()
		end)

		it("waits for a streamed-in character's root, then snaps on demand and cleans up", function()
			local world = t.newWorld()
			local server = world:createServer()
			local alice = server:addPlayer({ userId = 421, name = "Alice" })
			local ClientCrabPet = alice:require("ReplicatedStorage.Shared.Pets.CrabPet")
			alice:run(function()
				local folder = Instance.new("Folder")
				folder.Parent = workspace
				local character = Instance.new("Model")
				local crab = ClientCrabPet.new(
					character,
					folder,
					{ raycastParams = RaycastParams.new(), seed = 1, every = false }
				)
				crab:update(1 / 30)
				expect(crab.model.Parent).toBeNil()

				local root = Instance.new("Part")
				root.Name = "HumanoidRootPart"
				root.Size = Vector3.new(2, 2, 1)
				root.CFrame = CFrame.new(50, 3, 50)
				root.Parent = character
				crab:update(1 / 30)
				expect(crab.model.Parent).toBe(folder)
				local shell = crab.model:FindFirstChild("Shell") :: BasePart
				expect((shell.Position - Vector3.new(50, 3, 50)).Magnitude).toBeLessThan(7)

				crab:react()
				crab:update(1 / 30)
				-- The bubble pops with the first snap, after the claws go up.
				expect(crab.model:FindFirstChild("SnapBubble")).toBeNil()
				for _ = 1, 5 do
					crab:update(1 / 30)
				end
				expect(crab.model:FindFirstChild("SnapBubble")).never.toBeNil()
				crab:destroy()
				expect(folder:FindFirstChild("Crab")).toBeNil()
			end)
			world:assertHealthy()
		end)
	end)
end
