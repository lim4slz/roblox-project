--!strict
-- Everything players see while waiting: the "match starting soon" card with
-- countdown and next mode, the list of players, a toggle to sit the next
-- match out, a music toggle, the big status board in the world, and the
-- little reward for finishing the parkour course.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local GameState = require(ReplicatedStorage.Shared.GameState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SoundPlayer = require(ReplicatedStorage.Shared.SoundPlayer)
local TeamInfo = require(ReplicatedStorage.Shared.TeamInfo)
local UIKit = require(ReplicatedStorage.Shared.UIKit)
local Variants = require(ReplicatedStorage.Shared.Variants)
local MusicController = require(script.Parent.MusicController)
local NotificationController = require(script.Parent.NotificationController)
local VfxController = require(script.Parent.VfxController)

local LobbyController = {}

local Theme = UIKit.Theme
local player = Players.LocalPlayer

local PARKOUR_COOLDOWN = 8

local root: Frame
local statusLabel: TextLabel
local countdownBar: UIKit.Bar
local modeLabel: TextLabel
local modeDescription: TextLabel
local lastWinnerLabel: TextLabel
local playerListTitle: TextLabel
local playerListBody: TextLabel
local spectateButton: TextButton
local musicButton: TextButton

local boardStatus: TextLabel?
local boardDetail: TextLabel?

local function inLobbyPhase(): boolean
	local phase = GameState.phase()
	return phase == GameState.Phase.Waiting or phase == GameState.Phase.Intermission
end

local function lobbyStatus(): (string, number?)
	local phase = GameState.phase()
	if phase == GameState.Phase.Intermission then
		local timeLeft = GameState.phaseTimeLeft()
		return "MATCH STARTS IN " .. Format.clock(timeLeft), timeLeft / Config.Match.LobbyCountdown
	end
	local count = GameState.get(GameState.Key.PlayersInLobby)
	local needed = GameState.get(GameState.Key.PlayersNeeded)
	return string.format(
		"WAITING FOR PLAYERS  %d/%d",
		if typeof(count) == "number" then count else #Players:GetPlayers(),
		if typeof(needed) == "number" then needed else Config.Match.MinPlayers
	),
		nil
end

local function buildPanel()
	local screen = UIKit.screen("Lobby", 4)
	local inset = UIKit.topInset()

	root = UIKit.new("Frame", {
		Name = "Root",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = screen,
	})

	local card = UIKit.panel({
		Name = "StatusCard",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, inset + 8),
		Size = UDim2.fromOffset(460, 178),
		StrokeColor = Theme.Accent,
		StrokeTransparency = 0.15,
		Parent = root,
	})
	UIKit.label({
		Text = "DOOMSPIRE BRICKBATTLE",
		TextSize = 16,
		TextColor3 = Theme.Accent,
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromOffset(0, 8),
		Parent = card,
	})
	statusLabel = UIKit.label({
		Name = "Status",
		Text = "",
		TextSize = 28,
		Size = UDim2.new(1, -20, 0, 32),
		Position = UDim2.fromOffset(10, 28),
		Parent = card,
	})
	countdownBar = UIKit.bar({
		Size = UDim2.new(1, -40, 0, 8),
		Position = UDim2.fromOffset(20, 64),
		Color = Theme.Accent,
		Parent = card,
	})
	modeLabel = UIKit.label({
		Name = "Mode",
		Text = "",
		TextSize = 18,
		TextColor3 = Theme.Teal,
		Size = UDim2.new(1, -20, 0, 22),
		Position = UDim2.fromOffset(10, 78),
		Parent = card,
	})
	modeDescription = UIKit.label({
		Name = "ModeDescription",
		Text = "",
		TextSize = 14,
		TextColor3 = Theme.TextMuted,
		Size = UDim2.new(1, -20, 0, 18),
		Position = UDim2.fromOffset(10, 102),
		Parent = card,
	})
	lastWinnerLabel = UIKit.label({
		Name = "LastWinner",
		Text = "",
		TextSize = 15,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, inset + 192),
		Size = UDim2.fromOffset(460, 20),
		Parent = root,
	})

	-- Left: who's here.
	local listPanel = UIKit.panel({
		Name = "Players",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 0),
		Size = UDim2.fromOffset(220, 260),
		Parent = root,
	})
	playerListTitle = UIKit.label({
		Text = "PLAYERS",
		TextSize = 18,
		TextColor3 = Theme.Accent,
		Size = UDim2.new(1, -20, 0, 26),
		Position = UDim2.fromOffset(10, 6),
		Parent = listPanel,
	})
	playerListBody = UIKit.label({
		Text = "",
		TextSize = 15,
		RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, -24, 1, -42),
		Position = UDim2.fromOffset(12, 36),
		Parent = listPanel,
	})

	-- Preferences live inside the card so they never sit under the mobile
	-- thumbstick or jump button.
	local buttons = UIKit.new("Frame", {
		Position = UDim2.fromOffset(10, 128),
		Size = UDim2.new(1, -20, 0, 40),
		BackgroundTransparency = 1,
		Parent = card,
	})
	UIKit.list(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center).Parent = buttons
	spectateButton = UIKit.button({
		Text = "PLAYING NEXT MATCH",
		Size = UDim2.fromOffset(250, 38),
		TextSize = 15,
		Color = Theme.Success,
		LayoutOrder = 1,
		Parent = buttons,
	}, function()
		local wants = not player:GetAttribute("WantsToSpectate")
		Remotes.get("SetSpectatePreference"):FireServer(wants)
	end)
	musicButton = UIKit.button({
		Text = "MUSIC: ON",
		Size = UDim2.fromOffset(170, 38),
		TextSize = 15,
		Color = Theme.Teal,
		LayoutOrder = 2,
		Parent = buttons,
	}, function()
		MusicController.setMuted(not MusicController.isMuted())
	end)
end

-- Big billboard in the lobby, drawn on the client so it costs the server
-- nothing to keep updated.
local function buildBoard()
	local lobby = workspace:WaitForChild("Lobby", 10)
	local board = lobby and lobby:FindFirstChild("StatusBoard", true)
	if not board or not board:IsA("BasePart") then
		return
	end
	local surface = UIKit.new("SurfaceGui", {
		Name = "BoardGui",
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 20,
		LightInfluence = 0,
		Adornee = board,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local background = UIKit.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Ink,
		Parent = surface,
	})
	UIKit.gradient(Color3.fromRGB(30, 58, 138), Theme.Ink, 90).Parent = background
	UIKit.label({
		Text = "DOOMSPIRE BRICKBATTLE",
		TextScaled = true,
		TextColor3 = Theme.Accent,
		Size = UDim2.fromScale(0.9, 0.24),
		Position = UDim2.fromScale(0.05, 0.06),
		StrokeThickness = 6,
		Parent = background,
	})
	boardStatus = UIKit.label({
		Text = "",
		TextScaled = true,
		Size = UDim2.fromScale(0.9, 0.26),
		Position = UDim2.fromScale(0.05, 0.36),
		StrokeThickness = 5,
		Parent = background,
	})
	boardDetail = UIKit.label({
		Text = "",
		TextScaled = true,
		TextColor3 = Theme.Teal,
		Size = UDim2.fromScale(0.9, 0.16),
		Position = UDim2.fromScale(0.05, 0.7),
		StrokeThickness = 4,
		Parent = background,
	})
end

local function playerListText(): (string, string)
	local names = {}
	for _, other in Players:GetPlayers() do
		local name = other.DisplayName
		if other == player then
			name = string.format('<font color="#%s">%s (you)</font>', Theme.Accent:ToHex(), name)
		end
		if other:GetAttribute("WantsToSpectate") then
			name ..= ' <font color="#94a3b8">· watching</font>'
		elseif other:GetAttribute("IsAdmin") then
			name ..= ' <font color="#facc15">★</font>'
		end
		table.insert(names, name)
	end
	return string.format("PLAYERS (%d)", #names), table.concat(names, "\n")
end

local function refresh()
	local visible = inLobbyPhase()
	root.Visible = visible

	local status, fraction = lobbyStatus()
	local variant = Variants.get(GameState.get(GameState.Key.NextVariant))
	if boardStatus and boardDetail then
		if visible then
			boardStatus.Text = status
			boardDetail.Text = "NEXT MODE: " .. string.upper(variant.Name)
		else
			boardStatus.Text = "MATCH IN PROGRESS"
			local phase = GameState.phase()
			boardDetail.Text = if phase == GameState.Phase.Battle
				then Format.clock(GameState.phaseTimeLeft()) .. " LEFT"
				else "GET READY!"
		end
	end
	if not visible then
		return
	end

	statusLabel.Text = status
	countdownBar.Frame.Visible = fraction ~= nil
	if fraction then
		countdownBar.set(fraction, true)
	end
	modeLabel.Text = "NEXT MODE: " .. string.upper(variant.Name)
	modeDescription.Text = variant.Description

	local lastWinner = GameState.get(GameState.Key.LastWinner)
	local winnerInfo = TeamInfo.get(lastWinner)
	if winnerInfo then
		lastWinnerLabel.Text = "Last match: " .. winnerInfo.DisplayName .. " won!"
		lastWinnerLabel.TextColor3 = winnerInfo.LightColor
	elseif lastWinner == "Draw" then
		lastWinnerLabel.Text = "Last match ended in a draw."
		lastWinnerLabel.TextColor3 = Theme.TextMuted
	else
		lastWinnerLabel.Text = "Practice your throws at the wall while you wait!"
		lastWinnerLabel.TextColor3 = Theme.TextMuted
	end

	local title, body = playerListText()
	playerListTitle.Text = title
	playerListBody.Text = body

	local sittingOut = player:GetAttribute("WantsToSpectate") == true
	spectateButton.Text = if sittingOut then "SITTING OUT (SPECTATE)" else "PLAYING NEXT MATCH"
	spectateButton.BackgroundColor3 = if sittingOut then Theme.TextMuted else Theme.Success
	musicButton.Text = if MusicController.isMuted() then "MUSIC: OFF" else "MUSIC: ON"
end

-- Touching the golden pad at the top of the parkour course.
local function watchParkour()
	local lastReward = 0
	local function hook(part: BasePart)
		part.Touched:Connect(function(hit)
			local character = player.Character
			if not character or not hit:IsDescendantOf(character) then
				return
			end
			if os.clock() - lastReward < PARKOUR_COOLDOWN then
				return
			end
			lastReward = os.clock()
			NotificationController.toast("Parkour complete! You reached the Sky Peak.", "success")
			SoundPlayer.play("Cheer", { volume = 0.35, maxDuration = 3 })
			VfxController.firework(part.Position + Vector3.new(0, 2, 0), Theme.Accent)
		end)
	end
	local lobby = workspace:WaitForChild("Lobby", 10)
	if not lobby then
		return
	end
	for _, descendant in lobby:GetDescendants() do
		if descendant:IsA("BasePart") and descendant:GetAttribute("ParkourFinish") then
			hook(descendant)
		end
	end
end

function LobbyController.init()
	buildPanel()
end

function LobbyController.start()
	task.spawn(buildBoard)
	task.spawn(watchParkour)
	local accumulator = 0
	RunService.Heartbeat:Connect(function(deltaTime)
		accumulator += deltaTime
		if accumulator >= 0.2 then
			accumulator = 0
			refresh()
		end
	end)
	refresh()
end

return LobbyController
