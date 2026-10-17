--!nonstrict
-- Loads the generated towers and checks that the collapse rules behave on the
-- real geometry: a fresh tower stands, a sapped base drops everything, and a
-- single bomb at the door doesn't bring the whole thing down.

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local Vector3 = roblox.Vector3

return function(Expect, ModuleLoader)
	local BrickGraph = ModuleLoader.load("src/ServerScriptService/Server/Lib/BrickGraph")
	local Config = ModuleLoader.load("src/ReplicatedStorage/Shared/Config")

	local arena = roblox.deserializeModel(fs.readFile("assets/Arena.rbxm"))[1]
	local towers = arena:FindFirstChild("Towers")

	-- Mirrors BrickStructure.new: Bricks count toward health, Decor doesn't.
	local function loadTower(model)
		local parts, structural, boxes = {}, {}, {}
		for folderName, isStructural in { Bricks = true, Decor = false } do
			local folder = model:FindFirstChild(folderName)
			for _, part in folder:GetDescendants() do
				if part:IsA("BasePart") then
					table.insert(parts, part)
					table.insert(structural, isStructural)
					table.insert(
						boxes,
						BrickGraph.boxFromCFrame(
							part.CFrame,
							part.Size,
							part:GetAttribute("Grounded") == true,
							part:GetAttribute("Supports") ~= false
						)
					)
				end
			end
		end
		return parts, structural, BrickGraph.new(boxes)
	end

	local function structuralCount(structural)
		local count = 0
		for _, flag in structural do
			if flag then
				count += 1
			end
		end
		return count
	end

	Expect.describe("Generated towers", function()
		Expect.it("exist for every team in Config", function()
			for _, team in Config.Teams do
				local model = towers:FindFirstChild(team.Name .. "Tower")
				Expect.truthy(model, "missing tower for " .. team.Name)
				Expect.equal(model:GetAttribute("Team"), team.Name)
			end
		end)

		for _, model in towers:GetChildren() do
			Expect.describe(model.Name, function()
				local parts, structural, graph = loadTower(model)

				Expect.it("has hundreds of bricks", function()
					Expect.truthy(
						structuralCount(structural) > 400,
						"only " .. structuralCount(structural) .. " bricks"
					)
				end)

				Expect.it("stands on its own when untouched", function()
					local unsupported = graph:findUnsupported()
					if #unsupported > 0 then
						local names = {}
						for index = 1, math.min(5, #unsupported) do
							table.insert(names, parts[unsupported[index]].Name)
						end
						error(#unsupported .. " floating parts, e.g. " .. table.concat(names, ", "))
					end
				end)

				Expect.it("survives one bomb at the door", function()
					local _, structuralFlags, fresh = loadTower(model)
					local sum, count = Vector3.zero, 0
					for _, part in parts do
						sum += part.CFrame.Position
						count += 1
					end
					local center = sum / count
					-- The door is on the side facing the arena centre.
					local doorSide = if center.X < 0 then 1 else -1
					local blast = Vector3.new(center.X + 12 * doorSide, 1, center.Z)
					local removed = 0
					for index, part in parts do
						if (part.CFrame.Position - blast).Magnitude <= Config.Bomb.BrickRadius + 1 then
							if fresh:remove(index) and structuralFlags[index] then
								removed += 1
							end
						end
					end
					Expect.truthy(removed > 5, "the blast should knock some bricks out")
					local falling = fresh:findUnsupported()
					Expect.truthy(#falling < 20, #falling .. " parts fell from a single door blast")
				end)

				Expect.it("collapses completely when the base is cut", function()
					local _, structuralFlags, fresh = loadTower(model)
					for index, part in parts do
						if part.CFrame.Position.Y < 4 and structuralFlags[index] then
							fresh:remove(index)
						end
					end
					local falling = fresh:findUnsupported()
					Expect.equal(#falling, fresh.aliveCount, "everything above the cut falls")
				end)

				Expect.it("drops the top half when the middle is cut", function()
					local _, structuralFlags, fresh = loadTower(model)
					local above = 0
					for index, part in parts do
						local y = part.CFrame.Position.Y
						if y > 20 and y < 22 and structuralFlags[index] then
							fresh:remove(index)
						end
					end
					for index, part in parts do
						if fresh:isAlive(index) and part.CFrame.Position.Y > 22 then
							above += 1
						end
					end
					local falling = fresh:findUnsupported()
					-- The ladder is the only thing reaching through the cut.
					Expect.truthy(#falling >= above - 1, string.format("%d fell, %d above the cut", #falling, above))
				end)
			end)
		end
	end)
end
