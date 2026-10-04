local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Ember = ReplicatedStorage:WaitForChild("Ember")
local Abilities = require(Ember.Abilities)
local Animations = require(Ember.Animations)
local Anchors = require(Ember.Anchors)
local Cast = require(Ember.Cast)
local Config = require(Ember.Config)
local VFX = require(Ember.VFX)
local Remote = Ember:WaitForChild("Remote") :: RemoteEvent

local player = Players.LocalPlayer
local casts: { [Model]: any } = {}
local busy = false

local function controls()
	local ok, module = pcall(function()
		return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: ModuleScript) :: any
	end)
	return if ok and module then module:GetControls() else nil
end

local function stopCast(character: Model)
	local c = casts[character]
	if c then
		casts[character] = nil
		c:stop()
	end
end

local function start(caster: Player, name: string, serverStart: number)
	local ability = Abilities[name]
	local character = caster.Character
	if ability == nil or character == nil then
		return
	end
	stopCast(character)
	Anchors.ignore({ VFX.Pool.folder() })

	if caster == player then
		local track = Animations.load(character, ability.Animation)
		local ctl = controls()
		if ctl then
			ctl:Disable()
		end
		busy = true
		if track then
			track:Play(Config.FadeIn)
		end
		casts[character] = Cast.new(character, ability, {
			track = track,
			startClock = os.clock(),
			rootMotion = true,
			onFinished = function()
				busy = false
				if ctl then
					ctl:Enable()
				end
			end,
		})
		return
	end

	local cam = Workspace.CurrentCamera
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if cam and root and (cam.CFrame.Position - root.Position).Magnitude > Config.Quality.ObserverCullDistance then
		return
	end
	local elapsed = math.max(0, Workspace:GetServerTimeNow() - serverStart)
	casts[character] = Cast.new(character, ability, { startClock = os.clock() - elapsed })
end

Remote.OnClientEvent:Connect(function(action, caster, name, serverStart)
	if action == "start" then
		start(caster, name, serverStart)
	elseif action == "stop" and caster and caster.Character then
		stopCast(caster.Character)
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or busy then
		return
	end
	for name, settings in Config.Abilities do
		if input.KeyCode == settings.key then
			Remote:FireServer("cast", name)
			break
		end
	end
end)
