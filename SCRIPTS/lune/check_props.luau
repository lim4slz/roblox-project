-- Confere no banco de reflexão do Roblox (rbx-dom) se cada propriedade escrita pelo runtime existe e é gravável.
--   python3 SCRIPTS/tools/props_used.py && lune run SCRIPTS/lune/check_props.luau

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local db = roblox.getReflectionDatabase()
local pairs_ = serde.decode("json", fs.readFile(process.cwd .. "/_cache/props_used.json"))

local function find(className: string, prop: string)
	local c = db:GetClass(className)
	while c do
		local p = c.Properties[prop]
		if p then
			return p, c.Name
		end
		c = c.Superclass and db:GetClass(c.Superclass) or nil
	end
	return nil
end

local bad = 0
for _, pair in pairs_ do
	local cls, prop = pair[1], pair[2]
	local p, owner = find(cls, prop)
	if p == nil then
		print(`NÃO EXISTE: {cls}.{prop}`)
		bad += 1
	else
		local tags = {}
		for _, t in p.Tags do
			tags[t] = true
		end
		if tags.ReadOnly or tags.NotScriptable then
			print(`NÃO GRAVÁVEL: {cls}.{prop} ({owner})`)
			bad += 1
		end
	end
end
print(`{#pairs_} propriedades conferidas, {bad} problemas (reflection {db.Version})`)
if bad > 0 then
	process.exit(1)
end
