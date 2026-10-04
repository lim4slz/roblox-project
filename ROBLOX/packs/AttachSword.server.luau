-- Coloca a EmberBlade na mão direita de todo personagem R15.
-- A animação mexe na junta EmberBladeGrip, então o nome da peça e do Motor6D não pode mudar.

local Players = game:GetService("Players")

local template = script:WaitForChild("EmberBlade") :: BasePart

local function attach(character: Model)
	local hand = character:WaitForChild("RightHand", 10) :: BasePart?
	if hand == nil or character:FindFirstChild("EmberBlade") then
		return
	end
	local blade = template:Clone()
	local grip = blade:FindFirstChild("EmberBladeGrip") :: Motor6D
	blade.CFrame = hand.CFrame * grip.C0 * grip.C1:Inverse()
	grip.Part0 = hand
	blade.Parent = character
end

local function watch(player: Player)
	player.CharacterAdded:Connect(attach)
	if player.Character then
		task.spawn(attach, player.Character)
	end
end

Players.PlayerAdded:Connect(watch)
for _, player in Players:GetPlayers() do
	watch(player)
end
