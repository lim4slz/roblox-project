-- Ponte opcional pro Qwinkle's Particles 2 (plugin pago, não vem junto).
-- Usa só a API pública documentada em qwinkleparticles2.com/guide/from-script:
-- Part_Icles:Activate() e Part_Icles:AbsoluteEmitAt(item, origin).
--
-- Como usar: crie o efeito no plugin dentro de um Model ou Part (AbsoluteEmitAt não aceita Folder),
-- dê o nome <Habilidade>_<MARKER> ou <Habilidade>_<MARKER>_<valor> (ex.: AtomicEclipse_NUKE,
-- AtomicEclipse_SHOCKWAVE_2), coloque em ReplicatedStorage.Ember.Qwinkle e ligue Config.UseQwinkle.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(script.Parent.Config)

local Bridge = {}

local module: any = nil
local ready = false

local function partIcles(): any
	if ready then
		return module
	end
	ready = true
	local m = ReplicatedStorage:FindFirstChild("Part_Icles")
	if m and m:IsA("ModuleScript") then
		local ok, result = pcall(require, m)
		if ok and result then
			module = result
			pcall(function()
				module:Activate()
			end)
		else
			warn("[Ember] Part_Icles encontrado mas não carregou:", result)
		end
	end
	return module
end

local function effectFor(abilityName: string, cue): Instance?
	local folder = script.Parent:FindFirstChild("Qwinkle")
	if folder == nil then
		return nil
	end
	local named = `{abilityName}_{cue.marker}`
	if cue.value and cue.value ~= "" then
		local specific = folder:FindFirstChild(`{named}_{cue.value}`)
		if specific then
			return specific
		end
	end
	return folder:FindFirstChild(named)
end

-- devolve true se um efeito do Qwinkle foi disparado pra esse cue
function Bridge.emit(abilityName: string, cue, origin: CFrame): boolean
	if not Config.UseQwinkle then
		return false
	end
	local item = effectFor(abilityName, cue)
	local api = partIcles()
	if item == nil or api == nil then
		return false
	end
	local ok, err = pcall(function()
		api:AbsoluteEmitAt(item, origin)
	end)
	if not ok then
		warn("[Ember] AbsoluteEmitAt falhou:", err)
	end
	return ok
end

return Bridge
