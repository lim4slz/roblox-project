--!nonstrict
-- Test runner. From the repository root:
--   lune run map/build.luau && rojo build -o build/DoomspireBrickbattle.rbxl && lune run tests/run.luau

local process = require("@lune/process")

local Expect = require("./lib/Expect")
local ModuleLoader = require("./lib/ModuleLoader")

require("./BrickGraph.spec")(Expect, ModuleLoader)
require("./TowerIntegrity.spec")(Expect, ModuleLoader)
require("./Shared.spec")(Expect, ModuleLoader)
require("./Place.spec")(Expect, ModuleLoader)

local results = Expect.results()
print(string.format("\n%d passed, %d failed", results.passed, results.failed))
process.exit(if results.failed > 0 then 1 else 0)
