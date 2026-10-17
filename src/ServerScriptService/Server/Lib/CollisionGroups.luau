--!strict
-- Collision rules. Bombs and flying debris pass through characters so a throw
-- never shoves your own team-mate and falling bricks can't fling anyone into
-- orbit; both still bounce off the ground, walls and each other.

local PhysicsService = game:GetService("PhysicsService")

local CollisionGroups = {
	Players = "Players",
	Bombs = "Bombs",
	Debris = "Debris",
	Effects = "Effects",
}

local NON_COLLIDING_PAIRS = {
	{ "Players", "Bombs" },
	{ "Players", "Debris" },
	{ "Bombs", "Debris" },
	{ "Bombs", "Bombs" },
	{ "Effects", "Players" },
	{ "Effects", "Bombs" },
	{ "Effects", "Debris" },
	{ "Effects", "Effects" },
}

function CollisionGroups.setup()
	for _, name in { "Players", "Bombs", "Debris", "Effects" } do
		if not PhysicsService:IsCollisionGroupRegistered(name) then
			PhysicsService:RegisterCollisionGroup(name)
		end
	end
	for _, pair in NON_COLLIDING_PAIRS do
		PhysicsService:CollisionGroupSetCollidable(pair[1], pair[2], false)
	end
end

-- Puts every part of a character (including accessories added later) into the
-- Players group.
function CollisionGroups.assignCharacter(character: Model)
	local function assign(instance: Instance)
		if instance:IsA("BasePart") then
			instance.CollisionGroup = CollisionGroups.Players
		end
	end
	for _, descendant in character:GetDescendants() do
		assign(descendant)
	end
	character.DescendantAdded:Connect(assign)
end

return CollisionGroups
