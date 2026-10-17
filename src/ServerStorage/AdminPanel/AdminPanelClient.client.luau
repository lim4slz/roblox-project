--!strict
-- The admin panel UI. This script lives in ServerStorage and is only ever
-- cloned into an admin's PlayerGui, so regular players never receive it.
-- Every button just sends a command name; the server re-checks the UserId
-- and does the actual work.
--
-- Toggle with the ADMIN button (top left) or F2.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Format = require(ReplicatedStorage.Shared.Format)
local GameState = require(ReplicatedStorage.Shared.GameState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TeamInfo = require(ReplicatedStorage.Shared.TeamInfo)
local UIKit = require(ReplicatedStorage.Shared.UIKit)
local Variants = require(ReplicatedStorage.Shared.Variants)

local Theme = UIKit.Theme
local player = Players.LocalPlayer
local screen = script.Parent :: ScreenGui

local TOGGLE_KEY = Enum.KeyCode.F2
local PANEL_SIZE = Vector2.new(580, 450)

local commandRemote = Remotes.get("AdminCommand")

local function send(command: string, args: { [string]: any }?)
	commandRemote:FireServer(command, args or {})
end

----------------------------------------------------------------------------
-- Window
----------------------------------------------------------------------------

-- Scale like every other screen in the game.
local scale = UIKit.new("UIScale", { Parent = screen })
local function rescale()
	local viewport = workspace.CurrentCamera.ViewportSize
	scale.Scale = math.clamp(math.min(viewport.X / 1280, viewport.Y / 720), 0.55, 1.2)
end
rescale()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

local inset = UIKit.topInset()

local window = UIKit.panel({
	Name = "Window",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(PANEL_SIZE.X, PANEL_SIZE.Y),
	StrokeColor = Theme.Accent,
	StrokeTransparency = 0,
	StrokeThickness = 3,
	BackgroundTransparency = 0.05,
	Visible = false,
	Parent = screen,
})

local header = UIKit.new("Frame", {
	Name = "Header",
	Size = UDim2.new(1, 0, 0, 48),
	BackgroundColor3 = Theme.Accent,
	Parent = window,
})
UIKit.corner().Parent = header
UIKit.label({
	Text = "★  ADMIN PANEL",
	TextSize = 24,
	TextColor3 = Theme.Ink,
	Stroke = false,
	TextXAlignment = Enum.TextXAlignment.Left,
	Size = UDim2.new(1, -70, 1, 0),
	Position = UDim2.fromOffset(16, 0),
	Parent = header,
})

local function setOpen(open: boolean)
	window.Visible = open
	if open then
		UIKit.pop(window, 0.05)
	end
end

UIKit.button({
	Text = "X",
	Size = UDim2.fromOffset(36, 36),
	Position = UDim2.new(1, -44, 0, 6),
	Color = Theme.Danger,
	TextColor3 = Color3.new(1, 1, 1),
	Parent = header,
}, function()
	setOpen(false)
end)

-- Drag the window around by its header.
do
	local dragging = false
	local dragStart = Vector2.zero
	local startPosition = window.Position
	header.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			dragStart = Vector2.new(input.Position.X, input.Position.Y)
			startPosition = window.Position
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if
			dragging
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			local delta = (Vector2.new(input.Position.X, input.Position.Y) - dragStart) / scale.Scale
			window.Position = UDim2.new(
				startPosition.X.Scale,
				startPosition.X.Offset + delta.X,
				startPosition.Y.Scale,
				startPosition.Y.Offset + delta.Y
			)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = false
		end
	end)
end

----------------------------------------------------------------------------
-- Tabs
----------------------------------------------------------------------------

local tabBar = UIKit.new("Frame", {
	Name = "Tabs",
	Size = UDim2.new(1, -24, 0, 40),
	Position = UDim2.fromOffset(12, 56),
	BackgroundTransparency = 1,
	Parent = window,
})
UIKit.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left).Parent = tabBar

local pages: { [string]: ScrollingFrame } = {}
local tabButtons: { [string]: TextButton } = {}

local function selectTab(name: string)
	for tabName, page in pages do
		page.Visible = tabName == name
		tabButtons[tabName].BackgroundColor3 = if tabName == name then Theme.Accent else Theme.TextMuted
	end
end

local function createPage(name: string, order: number): ScrollingFrame
	local page = UIKit.new("ScrollingFrame", {
		Name = name,
		Size = UDim2.new(1, -24, 1, -168),
		Position = UDim2.fromOffset(12, 104),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Visible = false,
		Parent = window,
	})
	UIKit.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(170, 46),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = page,
	})
	pages[name] = page
	tabButtons[name] = UIKit.button({
		Text = string.upper(name),
		Size = UDim2.fromOffset(120, 36),
		TextSize = 16,
		LayoutOrder = order,
		Parent = tabBar,
	}, function()
		selectTab(name)
	end)
	return page
end

local buttonOrder = 0
local function addButton(page: ScrollingFrame, text: string, color: Color3?, onClick: () -> ()): TextButton
	buttonOrder += 1
	return UIKit.button({
		Text = text,
		TextSize = 16,
		Color = color or Theme.Teal,
		LayoutOrder = buttonOrder,
		Parent = page,
	}, onClick)
end

local function addCommand(page: ScrollingFrame, text: string, command: string, args: { [string]: any }?, color: Color3?)
	return addButton(page, text, color, function()
		send(command, args)
	end)
end

local blue, red = TeamInfo.all()[1], TeamInfo.all()[2]

-- MATCH
local matchPage = createPage("Match", 1)
addCommand(matchPage, "Start Match", "StartMatch", nil, Theme.Success)
addCommand(matchPage, "End Round", "EndRound", nil, Theme.Danger)
addCommand(matchPage, blue.Name .. " Wins", "EndRound", { winner = blue.Name }, blue.Color)
addCommand(matchPage, red.Name .. " Wins", "EndRound", { winner = red.Name }, red.Color)
addCommand(matchPage, "+60 Seconds", "AddTime")
addCommand(matchPage, "Final Showdown", "Showdown", nil, Theme.Danger)
addCommand(matchPage, "Shrink Storm Now", "AdvanceStorm", nil, Theme.Storm)
addCommand(matchPage, "Rebuild Towers", "ResetTowers")
addCommand(matchPage, "Collapse " .. blue.Name .. " Tower", "CollapseTower", { team = blue.Name }, blue.Color)
addCommand(matchPage, "Collapse " .. red.Name .. " Tower", "CollapseTower", { team = red.Name }, red.Color)

-- FUN
local funPage = createPage("Fun", 2)
addCommand(funPage, "Bomb Rain", "TriggerEvent", { event = "BombRain" }, Theme.Danger)
addCommand(funPage, "Low Gravity", "TriggerEvent", { event = "LowGravity" })
addCommand(funPage, "Speed Rush", "TriggerEvent", { event = "SpeedRush" })
addCommand(funPage, "Mega Madness", "TriggerEvent", { event = "MegaMadness" })
addCommand(funPage, "Supply Drop", "TriggerEvent", { event = "SupplyDrop" })
addCommand(funPage, "Random Event", "TriggerEvent", { event = "Random" }, Theme.Accent)
addCommand(funPage, "Toggle Fireworks", "ToggleFireworks", nil, Theme.Accent)
addCommand(funPage, "Give Everyone Bombs", "BombsForAll", nil, Theme.Accent)
addCommand(funPage, "Spawn Bomb for Everyone", "BombDrop", nil, Theme.Danger)
addCommand(funPage, "Heal Everyone", "HealAll", nil, Theme.Success)

-- PLAYERS
local playersPage = createPage("Players", 3)
local targetIndex = 0 -- 0 = me, 1 = everyone, 2+ = specific players
local targetButton: TextButton

local function targetOptions(): { { label: string, value: any } }
	local options = {
		{ label = "ME", value = "self" },
		{ label = "EVERYONE", value = "all" },
	}
	for _, other in Players:GetPlayers() do
		if other ~= player then
			table.insert(options, { label = string.upper(other.DisplayName), value = other.UserId })
		end
	end
	return options
end

local function currentTarget(): { label: string, value: any }
	local options = targetOptions()
	return options[(targetIndex % #options) + 1]
end

targetButton = addButton(playersPage, "TARGET: ME", Theme.Accent, function()
	targetIndex += 1
	targetButton.Text = "TARGET: " .. currentTarget().label
end)
for _, weapon in { { "Give Bomb", "Bomb" }, { "Give Sword", "Sword" }, { "Give Rocket Launcher", "RocketLauncher" } } do
	addButton(playersPage, weapon[1], nil, function()
		send("GiveWeapon", { tool = weapon[2], target = currentTarget().value })
	end)
end
addCommand(playersPage, "God Mode (me)", "GodMode", nil, Theme.Accent)
addCommand(playersPage, "Teleport: Arena", "TeleportArena")
addCommand(playersPage, "Teleport: Lobby", "TeleportLobby")

-- MODES
local modesPage = createPage("Modes", 4)
local modeButtons: { [string]: TextButton } = {}
for _, variant in Variants.List do
	modeButtons[variant.Id] = addButton(modesPage, variant.Name, Theme.TextMuted, function()
		send("SetNextVariant", { variant = variant.Id })
	end)
end

----------------------------------------------------------------------------
-- Footer: live status and command feedback
----------------------------------------------------------------------------

local feedbackLabel = UIKit.label({
	Name = "Feedback",
	Text = "Pick a command. Everything is checked on the server.",
	TextSize = 15,
	TextColor3 = Theme.TextMuted,
	TextXAlignment = Enum.TextXAlignment.Left,
	Size = UDim2.new(1, -24, 0, 22),
	Position = UDim2.new(0, 12, 1, -58),
	Parent = window,
})
local statusLabel = UIKit.label({
	Name = "Status",
	Text = "",
	TextSize = 14,
	TextColor3 = Theme.Teal,
	TextXAlignment = Enum.TextXAlignment.Left,
	Size = UDim2.new(1, -24, 0, 20),
	Position = UDim2.new(0, 12, 1, -32),
	Parent = window,
})

Remotes.get("AdminFeedback").OnClientEvent:Connect(function(message: string, ok: boolean)
	feedbackLabel.Text = message
	feedbackLabel.TextColor3 = if ok then Theme.Success else Theme.Danger
	UIKit.pop(feedbackLabel, 0.08)
end)

RunService.Heartbeat:Connect(function()
	if not window.Visible then
		return
	end
	local phase = GameState.phase()
	local nextVariant = Variants.get(GameState.get(GameState.Key.NextVariant))
	statusLabel.Text = string.format(
		"%s  ·  %s left  ·  %d players  ·  next mode: %s",
		string.upper(phase),
		Format.clock(GameState.phaseTimeLeft()),
		#Players:GetPlayers(),
		nextVariant.Name
	)
	for id, button in modeButtons do
		button.BackgroundColor3 = if id == nextVariant.Id then Theme.Accent else Theme.TextMuted
	end
end)

----------------------------------------------------------------------------
-- Toggle
----------------------------------------------------------------------------

local toggle = UIKit.button({
	Name = "AdminToggle",
	Text = "★ ADMIN",
	Size = UDim2.fromOffset(110, 34),
	Position = UDim2.fromOffset(16, inset + 8),
	TextSize = 16,
	Parent = screen,
}, function()
	setOpen(not window.Visible)
end)
toggle.ZIndex = 5

UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == TOGGLE_KEY then
		setOpen(not window.Visible)
	end
end)

selectTab("Match")
