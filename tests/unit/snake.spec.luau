--[[
	Snake pet: rig data, slithering body, hiss and tongue animation, and the
	client module running in the headless runtime.
]]

local roblox = require("@lune/roblox")
local Datatypes = require("../harness/Datatypes")
local Shared = require("../harness/Shared")
local Geo = require("./PetGeometry")

-- The harness CFrame: Lune's own lookAt faces away from its target.
local CFrame, Vector3 = Datatypes.CFrame, roblox.Vector3

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	local SnakeModel = Shared.require("Pets.SnakeModel")
	local SnakeAnimation = Shared.require("Pets.SnakeAnimation")
	local SnakePet = Shared.require("Pets.SnakePet")
	local PetRig = Shared.require("Pets.PetRig")

	local parts = SnakeModel.Definition.parts
	local NEVER = { math.huge, math.huge }

	local function restPins(rig)
		local pins = {}
		for _, bone in SnakeModel.Spine do
			pins[bone] = rig:restPivot(bone)
		end
		return pins
	end

	local function solve(rig, anim)
		local pose, pinned = anim:pose()
		return rig:solve(CFrame.identity, pose, {}, pinned)
	end

	-- Moves `root` along -Z (or along `path(distance)`) at `speed` for `seconds`.
	local function travel(anim, root, speed, seconds, path, onFrame)
		local distance = 0
		for _ = 1, math.floor(seconds * 60 + 0.5) do
			distance += speed / 60
			if path then
				root = path(distance)
			else
				root = CFrame.new(root.Position + root.LookVector * (speed / 60)) * root.Rotation
			end
			anim:step(1 / 60, root, speed)
			if onFrame then
				onFrame(root)
			end
		end
		return root
	end

	local function stepFor(anim, root, seconds, speed)
		local hisses = 0
		for _ = 1, math.floor(seconds * 60 + 0.5) do
			hisses += anim:step(1 / 60, root, speed or 0)
		end
		return hisses
	end

	local function segmentLengths()
		local lengths = {}
		for index = 2, #SnakeModel.Joints do
			lengths[index] = SnakeModel.Joints[index] - SnakeModel.Joints[index - 1]
		end
		return lengths
	end

	describe("Snake model", function()
		it("keeps the 20 original parts plus 5 hidden ones, each on a known bone", function()
			expect(#parts).toBe(25)
			local names = {}
			for _, def in parts do
				expect(names[def.name]).toBeNil()
				names[def.name] = true
			end
			local rig = PetRig.new(SnakeModel.Definition)
			local cframes = rig:solve(CFrame.identity, {}, {}, restPins(rig))
			for index, def in parts do
				expect((cframes[index].Position - def.cframe.Position).Magnitude).toBeLessThan(1e-4)
				expect(cframes[index].LookVector:Dot(def.cframe.LookVector)).toBeGreaterThan(0.9999)
			end
			-- The head and the big body segments rest on the ground; the
			-- segments touch end to end like in the art.
			expect(Geo.lowest(parts, cframes)).toBeCloseTo(0, 0.01)
			for index = 1, 9 do
				local a = parts[Geo.partIndex(parts, "Body" .. index)]
				local b = parts[Geo.partIndex(parts, "Body" .. (index + 1))]
				local gap = (b.cframe.Position.Z - b.size.Z / 2) - (a.cframe.Position.Z + a.size.Z / 2)
				expect(math.abs(gap)).toBeLessThan(0.04)
			end
			expect(SnakeModel.Length).toBeCloseTo(13.523, 0.001)
			expect(#SnakeModel.Spine).toBe(#SnakeModel.Joints - 1)
		end)

		it("hides the mouth, fangs, brows and the pulled-in tongue inside the head", function()
			local rig = PetRig.new(SnakeModel.Definition)
			local pins = restPins(rig)
			local rest = rig:solve(CFrame.identity, {}, {}, pins)
			local face = Geo.frontZ(parts, rest, "Face")
			-- At rest (the art) the tongue sticks out.
			expect(Geo.frontZ(parts, rest, "ForkL")).toBeLessThan(face - 1)
			for _, name in { "Mouth", "FangL", "FangR" } do
				expect(Geo.frontZ(parts, rest, name)).toBeGreaterThan(face)
			end
			expect(Geo.inside(parts, rest, "BrowL", "Head", 0.001)).toBe(true)
			expect(Geo.inside(parts, rest, "BrowR", "Head", 0.001)).toBe(true)

			local tucked = rig:solve(CFrame.identity, { Tongue = CFrame.new(SnakeModel.TongueInOffset) }, {}, pins)
			for _, name in { "Tongue", "ForkL", "ForkR" } do
				expect(Geo.frontZ(parts, tucked, name)).toBeGreaterThan(face)
				for _, corner in Geo.cornersIn(parts, tucked, name, "Head") do
					expect(math.abs(corner.X)).toBeLessThan(0.613)
					expect(math.abs(corner.Y)).toBeLessThan(0.443)
					expect(corner.Z).toBeLessThan(0.75)
				end
			end

			local open = rig:solve(CFrame.identity, {
				Mouth = CFrame.new(SnakeModel.MouthOpenOffset),
				BrowL = CFrame.new(-SnakeModel.BrowOut, 0, 0),
				BrowR = CFrame.new(SnakeModel.BrowOut, 0, 0),
			}, {}, pins)
			expect(Geo.frontZ(parts, open, "Mouth")).toBeLessThan(face)
			expect(Geo.frontZ(parts, open, "FangL")).toBeLessThan(Geo.frontZ(parts, open, "Mouth"))
			-- The brows slide out over the top of the eyes.
			local browR = open[Geo.partIndex(parts, "BrowR")].Position
			local eyeR = parts[Geo.partIndex(parts, "EyeR")]
			expect(browR.X).toBeGreaterThan(eyeR.cframe.Position.X + eyeR.size.X / 2)
			local browL = open[Geo.partIndex(parts, "BrowL")].Position
			local eyeL = parts[Geo.partIndex(parts, "EyeL")]
			expect(browL.X).toBeLessThan(eyeL.cframe.Position.X - eyeL.size.X / 2)
		end)
	end)

	describe("Snake slither", function()
		local function circle(radius)
			-- Counter-clockwise circle seen from above, starting at the origin facing -Z.
			return function(distance)
				local angle = distance / radius
				local position = Vector3.new(radius - radius * math.cos(angle), 0, -radius * math.sin(angle))
				local heading = Vector3.new(math.sin(angle), 0, -math.cos(angle))
				return CFrame.lookAt(position, position + heading)
			end
		end

		it("weaves its head side to side and slides the whole body through the same S-shaped path", function()
			local anim = SnakeAnimation.new(3, NEVER)
			local path = circle(40)
			anim:reset(path(0))
			local lengths = segmentLengths()
			local worstGap, worstOffTrail, lateralMax, lateralMin, crossings = 0, 0, 0, 0, 0
			local lastSide = 0
			local frame = 0
			travel(anim, path(0), 16, 4, path, function(root)
				frame += 1
				anim:pose()
				local joints = anim:joints()
				for index = 2, #joints do
					worstGap =
						math.max(worstGap, math.abs((joints[index] - joints[index - 1]).Magnitude - lengths[index]))
				end
				if frame > 90 then
					-- Joints from the middle of the body on lie on the head's trail.
					local trail = table.clone(anim:trail())
					for index = 5, #joints do
						worstOffTrail = math.max(worstOffTrail, Geo.flatDistanceToPolyline(joints[index], trail))
					end
					local lateral = (joints[1] - root.Position):Dot(root.RightVector)
					lateralMax = math.max(lateralMax, lateral)
					lateralMin = math.min(lateralMin, lateral)
					local side = if lateral > 0.1 then 1 elseif lateral < -0.1 then -1 else lastSide
					if side ~= lastSide and lastSide ~= 0 then
						crossings += 1
					end
					lastSide = side
				end
			end)
			expect(worstGap).toBeLessThan(1e-3)
			expect(worstOffTrail).toBeLessThan(0.3)
			expect(lateralMax).toBeGreaterThan(0.35)
			expect(lateralMin).toBeLessThan(-0.35)
			expect(lateralMax).toBeLessThan(1.2)
			-- 16 studs/s with a 6.5 stud wavelength: ~2.5 waves a second.
			expect(crossings).toBeGreaterThanOrEqual(8)
			expect(anim:gait()).toBe("Walk")
		end)

		it("keeps its belly on the ground while it slithers, and dashes low when it runs", function()
			local rig = PetRig.new(SnakeModel.Definition)
			for _, speed in { 8, 16, 26 } do
				local anim = SnakeAnimation.new(speed, NEVER)
				anim:reset(CFrame.identity)
				local lowest, middleHighest = math.huge, -math.huge
				travel(anim, CFrame.identity, speed, 3, nil, function()
					local cframes = solve(rig, anim)
					lowest = math.min(lowest, Geo.lowest(parts, cframes))
					middleHighest = math.max(
						middleHighest,
						Geo.lowest(parts, cframes, function(name)
							return name == "Body4" or name == "Body5" or name == "Body6"
						end)
					)
				end)
				expect(lowest).toBeGreaterThan(-0.06)
				expect(middleHighest).toBeLessThan(0.06)
				expect(anim:gait()).toBe(if speed > 20 then "Run" else "Walk")
			end
		end)

		it("follows the ground it went over, so it climbs steps one segment at a time", function()
			local spine = SnakeModel.SpineHeight
			for _, smoothing in { 18, math.huge } do
				local anim = SnakeAnimation.new(4, NEVER)
				anim:reset(CFrame.identity)
				-- A 3 stud step 6 studs ahead. PetFollow smooths the height like
				-- this; math.huge is an instant jump.
				local y = 0
				local function onStep(distance)
					local ground = if distance > 6 then 3 else 0
					y += (ground - y) * (1 - math.exp(-smoothing / 60))
					return CFrame.new(0, y, -distance)
				end
				local lowest = math.huge
				travel(anim, CFrame.identity, 16, 0.75, onStep, function()
					anim:pose()
					for _, joint in anim:joints() do
						lowest = math.min(lowest, joint.Y)
					end
				end) -- head 12 studs in, 6 past the step
				local joints = anim:joints()
				expect(joints[1].Y).toBeGreaterThan(3 + spine - 0.05)
				expect(joints[#joints].Y).toBeLessThan(spine + 0.3)
				-- Nothing sinks into the lower floor on the way up.
				expect(lowest).toBeGreaterThan(spine - 0.01)
			end
		end)

		it("lays the body out straight behind it again after a teleport", function()
			local anim = SnakeAnimation.new(6, NEVER)
			anim:reset(CFrame.identity)
			travel(anim, CFrame.identity, 16, 1)
			local far = CFrame.new(300, 20, 80) * CFrame.Angles(0, math.rad(90), 0)
			anim:step(1 / 60, far, 0)
			anim:pose()
			local joints = anim:joints()
			local tail = joints[#joints]
			local expected = far.Position - far.LookVector * SnakeModel.Length
			expect((Vector3.new(tail.X, 0, tail.Z) - Vector3.new(expected.X, 0, expected.Z)).Magnitude).toBeLessThan(
				0.6
			)
			expect(tail.Y).toBeCloseTo(20 + SnakeModel.SpineHeight, 0.05)
		end)

		it("raises its head and turns it towards its owner when it stops", function()
			local anim = SnakeAnimation.new(7, NEVER)
			anim:reset(CFrame.identity)
			-- Standing still, the follow logic turned it 40 degrees to look at its owner.
			local looking = CFrame.Angles(0, math.rad(40), 0)
			stepFor(anim, looking, 1.5)
			local _, pinned = anim:pose()
			local head = pinned.Head
			expect(head.Position.Y).toBeGreaterThan(SnakeModel.SpineHeight + 0.3)
			local look = Vector3.new(head.LookVector.X, 0, head.LookVector.Z).Unit
			local turned = math.deg(math.acos(math.clamp(look:Dot(Vector3.new(0, 0, -1)), -1, 1)))
			expect(turned).toBeGreaterThan(20)
			expect(turned).toBeLessThan(70)
			expect(anim:gait()).toBe("Idle")
		end)

		it("grows with its scale", function()
			local anim = SnakeAnimation.new(8, NEVER, 2)
			anim:reset(CFrame.identity)
			travel(anim, CFrame.identity, 16, 1)
			anim:pose()
			local joints = anim:joints()
			local lengths = segmentLengths()
			for index = 2, #joints do
				expect((joints[index] - joints[index - 1]).Magnitude).toBeCloseTo(lengths[index] * 2, 1e-3)
			end
			local rig = PetRig.new(SnakeModel.Definition, 2)
			local cframes = solve(rig, anim)
			expect(Geo.lowest(parts, cframes, nil, 2)).toBeGreaterThan(-0.1)
			expect(Geo.lowest(parts, cframes, nil, 2)).toBeLessThan(0.1)
		end)
	end)

	describe("Snake hiss and tongue", function()
		it("rears up and hisses with the mouth open, fangs out, angry brows and the tongue out", function()
			local anim = SnakeAnimation.new(5, NEVER)
			anim:reset(CFrame.identity)
			stepFor(anim, CFrame.identity, 0.5)
			anim:hiss()
			expect(anim:step(1 / 60, CFrame.identity, 0)).toBe(1)
			expect(anim:isHissing()).toBe(true)
			stepFor(anim, CFrame.identity, 0.4)
			local pose, pinned = anim:pose()
			expect(pinned.Head.Position.Y).toBeGreaterThan(SnakeModel.SpineHeight + 1.6)
			expect(math.deg(math.asin(pinned.Head.LookVector.Y))).toBeGreaterThan(10)
			expect(pose.Mouth.Position).toEqual(SnakeModel.MouthOpenOffset)
			expect(pose.BrowL.Position.X).toBeCloseTo(-SnakeModel.BrowOut, 1e-6)
			expect(pose.BrowR.Position.X).toBeCloseTo(SnakeModel.BrowOut, 1e-6)
			expect(pose.Tongue.Position.Magnitude).toBeLessThan(0.35)
			-- Calling it again while hissing does not start a second one.
			anim:hiss()
			expect(anim:step(1 / 60, CFrame.identity, 0)).toBe(0)

			stepFor(anim, CFrame.identity, 1.2)
			expect(anim:isHissing()).toBe(false)
			pose, pinned = anim:pose()
			expect(pose.Mouth.Position.Magnitude).toBe(0)
			expect(pose.BrowR.Position.Magnitude).toBe(0)
			expect(pinned.Head.Position.Y).toBeLessThan(SnakeModel.SpineHeight + 0.6)
		end)

		it("hisses on its own at random intervals, and never when told not to", function()
			local function hissTimes(seed, every)
				local anim = SnakeAnimation.new(seed, every)
				anim:reset(CFrame.identity)
				local times = {}
				for frame = 1, 90 * 60 do
					local speed = if frame % 1200 < 600 then 0 else 12
					for _ = 1, anim:step(1 / 60, CFrame.identity, speed) do
						table.insert(times, frame / 60)
					end
				end
				return times
			end
			local times = hissTimes(42)
			expect(times).toEqual(hissTimes(42))
			expect(times).never.toEqual(hissTimes(43))
			expect(times[1]).toBeGreaterThanOrEqual(2)
			expect(times[1]).toBeLessThanOrEqual(4.05)
			for index = 2, #times do
				local gap = times[index] - times[index - 1]
				expect(gap).toBeGreaterThanOrEqual(5 + SnakeAnimation.HissLength - 0.05)
				expect(gap).toBeLessThanOrEqual(10 + SnakeAnimation.HissLength + 0.05)
			end
			expect(#times).toBeGreaterThanOrEqual(7)
			expect(#hissTimes(42, NEVER)).toBe(0)
		end)

		it("flicks its tongue in and out every second or two and keeps it in the rest of the time", function()
			local anim = SnakeAnimation.new(9, NEVER)
			anim:reset(CFrame.identity)
			local flicks, tucked, frames = 0, 0, 0
			local wasOut = false
			for _ = 1, 20 * 60 do
				anim:step(1 / 60, CFrame.identity, 0)
				local pose = anim:pose()
				local extension = 1 - pose.Tongue.Position.Z / SnakeModel.TongueInOffset.Z
				local out = extension > 0.5
				if out and not wasOut then
					flicks += 1
				end
				wasOut = out
				tucked += if extension < 0.05 then 1 else 0
				frames += 1
			end
			expect(flicks).toBeGreaterThanOrEqual(6)
			expect(flicks).toBeLessThanOrEqual(26)
			expect(tucked / frames).toBeGreaterThan(0.5)
		end)
	end)

	describe("Snake pet on the client", function()
		it("gives every character a snake that slithers after it and hisses with a bubble and a hiss", function()
			local world = t.newWorld()
			local server = world:createServer()
			server:start()
			local alice = server:addPlayer({ userId = 201, name = "Alice", runClient = true })
			world:advance(1)

			local snake = alice:run(function()
				local model = workspace.AnimatedPets:FindFirstChild("Snake")
				local anchored, colliding = 0, 0
				for _, part in model:GetChildren() do
					if part:IsA("BasePart") then
						anchored += if part.Anchored then 1 else 0
						colliding += if part.CanCollide or part.CanQuery or part.CanTouch then 1 else 0
					end
				end
				return { parts = #model:GetChildren(), anchored = anchored, colliding = colliding }
			end)
			expect(snake.parts).toBe(25)
			expect(snake.anchored).toBe(25)
			expect(snake.colliding).toBe(0)

			local start = alice:position()
			local character = alice:character()
			for frame = 1, 75 do
				local position = start + Vector3.new(0, 0, -16 * frame / 30)
				alice:run(function()
					character:PivotTo(CFrame.new(position))
				end)
				world:step(1 / 30)
			end
			local head = alice:run(function()
				return workspace.AnimatedPets.Snake.Head.Position
			end)
			expect((head - alice:position()).Magnitude).toBeLessThan(12)

			local bubbles, texts, start2 = 0, {}, nil
			for _ = 1, 10 * 30 do
				world:step(1 / 30)
				alice:run(function()
					for _, gui in workspace.AnimatedPets.Snake:GetChildren() do
						if gui:IsA("BillboardGui") then
							bubbles = 1
							texts[gui.Text.Text] = true
						end
					end
					local voice = workspace.AnimatedPets.Snake.HeadTop:FindFirstChild("Hiss1")
					start2 = voice and voice.TimePosition
				end)
			end
			expect(bubbles).toBe(1)
			for text in texts do
				expect(text).toMatch("^[HhSs][Ii]?[Ss]+!$")
			end
			local hisses = 0
			for _, sound in world.soundsPlayed do
				if sound.ctx == alice.ctx.id and sound.soundId == SnakePet.Defaults.sound then
					hisses += 1
					expect(sound.speed).toBeGreaterThanOrEqual(0.9)
					expect(sound.speed).toBeLessThanOrEqual(1.15)
				end
			end
			expect(hisses).toBeGreaterThan(0)
			-- The hiss in the sound file starts 2.8 s in.
			expect(start2).toBe(2.8)
			world:assertHealthy()
		end)

		it("waits for a streamed-in character's root, then hisses on demand and cleans up", function()
			local world = t.newWorld()
			local server = world:createServer()
			local alice = server:addPlayer({ userId = 221, name = "Alice" })
			local ClientSnakePet = alice:require("ReplicatedStorage.Shared.Pets.SnakePet")
			alice:run(function()
				local folder = Instance.new("Folder")
				folder.Parent = workspace
				local character = Instance.new("Model")
				local snake = ClientSnakePet.new(character, folder, { raycastParams = RaycastParams.new(), seed = 1 })
				snake:update(1 / 30)
				expect(snake.model.Parent).toBeNil()

				local root = Instance.new("Part")
				root.Name = "HumanoidRootPart"
				root.Size = Vector3.new(2, 2, 1)
				root.CFrame = CFrame.new(50, 3, 50)
				root.Parent = character
				snake:update(1 / 30)
				expect(snake.model.Parent).toBe(folder)
				local head = snake.model:FindFirstChild("Head") :: BasePart
				expect((head.Position - Vector3.new(50, 3, 50)).Magnitude).toBeLessThan(6)

				snake:react()
				snake:update(1 / 30)
				expect(snake.model:FindFirstChild("HissBubble")).never.toBeNil()
				snake:destroy()
				expect(folder:FindFirstChild("Snake")).toBeNil()
			end)
			world:assertHealthy()
		end)
	end)
end
