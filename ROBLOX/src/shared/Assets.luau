-- IDs de asset. Animações precisam ser publicadas (Animation Editor > Publish ou Asset Manager)
-- e o ID colado aqui. Enquanto estiver vazio, no Studio o KeyframeSequence de
-- ReplicatedStorage.Ember.KeyframeSequences é registrado na hora (só funciona no Studio).

local Assets = {}

Assets.Animations = {
	ANIM_01_ATOMIC_ECLIPSE = "",
}

function Assets.id(value: string?): string?
	if value == nil or value == "" then
		return nil
	end
	if string.match(value, "^%d+$") then
		return "rbxassetid://" .. value
	end
	return value
end

return Assets
