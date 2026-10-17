--!nonstrict
-- Unit tests for the support graph that decides which bricks fall.

return function(Expect, ModuleLoader)
	local BrickGraph = ModuleLoader.load("src/ServerScriptService/Server/Lib/BrickGraph")

	local function box(x0, y0, z0, x1, y1, z1, grounded)
		return {
			min = { x = x0, y = y0, z = z0 },
			max = { x = x1, y = y1, z = z1 },
			grounded = grounded == true,
		}
	end

	Expect.describe("BrickGraph", function()
		Expect.it("keeps a stack standing while its base exists", function()
			local graph = BrickGraph.new({
				box(0, 0, 0, 4, 2, 2, true),
				box(0, 2, 0, 4, 4, 2),
				box(0, 4, 0, 4, 6, 2),
			})
			Expect.equal(#graph:findUnsupported(), 0)
			graph:remove(1)
			Expect.equal(#graph:findUnsupported(), 2, "everything above the base falls")
		end)

		Expect.it("does not connect bricks that only touch at an edge", function()
			local graph = BrickGraph.new({
				box(0, 0, 0, 2, 2, 2, true),
				box(2, 2, 0, 4, 4, 2), -- diagonal neighbour
			})
			Expect.equal(#graph:findUnsupported(), 1)
		end)

		Expect.it("lets a bridge hang from either side", function()
			local graph = BrickGraph.new({
				box(0, 0, 0, 2, 4, 2, true),
				box(0, 4, 0, 8, 6, 2), -- span across both pillars
				box(6, 0, 0, 8, 4, 2, true),
			})
			graph:remove(1)
			Expect.equal(#graph:findUnsupported(), 0, "the other pillar still holds the span")
			graph:remove(3)
			Expect.equal(#graph:findUnsupported(), 1)
		end)

		Expect.it("splits falling bricks into separate chunks", function()
			local graph = BrickGraph.new({
				box(0, 0, 0, 2, 2, 2),
				box(0, 2, 0, 2, 4, 2),
				box(10, 0, 0, 12, 2, 2),
			})
			local chunks = graph:components(graph:findUnsupported())
			Expect.equal(#chunks, 2)
		end)

		Expect.it("tolerates tiny floating-point gaps", function()
			local graph = BrickGraph.new({
				box(0, 0, 0, 4, 2, 2, true),
				box(0, 2.03, 0, 4, 4, 2),
			})
			Expect.equal(#graph:findUnsupported(), 0)
		end)

		Expect.it("never lets a non-conducting part act as a spine", function()
			local ladder = box(4, 0, 0, 5, 8, 1)
			ladder.conducts = false
			local graph = BrickGraph.new({
				box(0, 0, 0, 4, 2, 1, true),
				box(0, 2, 0, 4, 4, 1),
				box(0, 4, 0, 4, 6, 1),
				ladder,
			})
			graph:remove(2)
			local falling = graph:findUnsupported()
			Expect.equal(#falling, 1, "only the top brick falls; the ladder hangs on")
			Expect.equal(falling[1], 3)
		end)

		Expect.it("reports removals only once", function()
			local graph = BrickGraph.new({ box(0, 0, 0, 1, 1, 1, true) })
			Expect.equal(graph:remove(1), true)
			Expect.equal(graph:remove(1), false)
			Expect.equal(graph.aliveCount, 0)
		end)
	end)
end
