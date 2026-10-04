local Abilities = {}

for _, module in script:GetChildren() do
	if module:IsA("ModuleScript") then
		local data = require(module) :: any
		table.sort(data.Cues, function(a, b)
			return a.t < b.t
		end)
		Abilities[module.Name] = data
	end
end

return Abilities
