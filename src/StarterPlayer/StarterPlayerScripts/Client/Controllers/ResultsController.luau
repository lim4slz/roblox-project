--!strict
-- End-of-match screen: who won and why, your own result, the MVP, and both
-- team scoreboards side by side. Fades out as everyone returns to the lobby.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Format = require(ReplicatedStorage.Shared.Format)
local GameState = require(ReplicatedStorage.Shared.GameState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TeamInfo = require(ReplicatedStorage.Shared.TeamInfo)
local UIKit = require(ReplicatedStorage.Shared.UIKit)

local ResultsController = {}

local Theme = UIKit.Theme
local player = Players.LocalPlayer

local MAX_ROWS = 6

local screen: ScreenGui
local overlay: CanvasGroup
local card: Frame
local footer: TextLabel

local function clearCard()
	for _, child in card:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- One scoreboard column; called once per team so both look identical.
local function createTeamColumn(team: { [string]: any }, winner: string, layoutOrder: number): Frame
	local info = TeamInfo.get(team.name)
	local color = if info then info.Color else Theme.TextMuted
	local won = team.name == winner

	local column = UIKit.panel({
		Name = team.name .. "Column",
		Size = UDim2.fromOffset(380, 300),
		StrokeColor = color,
		StrokeTransparency = if won then 0 else 0.5,
		StrokeThickness = if won then 3 else 2,
		LayoutOrder = layoutOrder,
	})
	UIKit.gradient(color:Lerp(Theme.Ink, 0.6), Theme.Ink, 90).Parent = column

	UIKit.label({
		Text = string.upper(if info then info.DisplayName else team.name) .. (if won then "  ★" else ""),
		TextSize = 24,
		TextColor3 = if info then info.LightColor else Theme.Text,
		Size = UDim2.new(1, -20, 0, 30),
		Position = UDim2.fromOffset(10, 8),
		Parent = column,
	})
	UIKit.label({
		Text = string.format(
			"Tower %s   ·   %d KOs   ·   %s pts",
			Format.percent(team.towerHealth or 0),
			team.kos or 0,
			Format.thousands(team.score or 0)
		),
		TextSize = 15,
		TextColor3 = Theme.TextMuted,
		Size = UDim2.new(1, -20, 0, 20),
		Position = UDim2.fromOffset(10, 38),
		Parent = column,
	})

	local header = UIKit.label({
		Text = "PLAYER                          PTS     KO    AST   BRICKS",
		TextSize = 12,
		TextColor3 = Theme.TextMuted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -24, 0, 16),
		Position = UDim2.fromOffset(12, 66),
		Stroke = false,
		Parent = column,
	})
	header.Font = Enum.Font.GothamBold

	local list = UIKit.new("Frame", {
		Size = UDim2.new(1, -20, 1, -92),
		Position = UDim2.fromOffset(10, 86),
		BackgroundTransparency = 1,
		Parent = column,
	})
	UIKit.list(Enum.FillDirection.Vertical, 4).Parent = list

	local roster = team.players or {}
	if #roster == 0 then
		UIKit.label({
			Text = "No players",
			TextSize = 16,
			TextColor3 = Theme.TextMuted,
			Size = UDim2.new(1, 0, 0, 30),
			Parent = list,
		})
	end
	for index = 1, math.min(#roster, MAX_ROWS) do
		local stats = roster[index]
		local isMe = stats.UserId == player.UserId
		local row = UIKit.new("Frame", {
			Size = UDim2.new(1, 0, 0, 28),
			BackgroundColor3 = if isMe then Theme.Accent else Theme.InkSoft,
			BackgroundTransparency = if isMe then 0.75 else 0.5,
			LayoutOrder = index,
			Parent = list,
		})
		UIKit.corner(8).Parent = row
		local function cell(text: string, x: number, width: number, alignment: Enum.TextXAlignment)
			UIKit.label({
				Text = text,
				TextSize = 15,
				TextXAlignment = alignment,
				Size = UDim2.new(0, width, 1, 0),
				Position = UDim2.fromOffset(x, 0),
				Parent = row,
			})
		end
		cell(stats.Name, 8, 150, Enum.TextXAlignment.Left)
		cell(Format.thousands(stats.Score), 160, 56, Enum.TextXAlignment.Right)
		cell(tostring(stats.KOs), 222, 36, Enum.TextXAlignment.Right)
		cell(tostring(stats.Assists), 262, 40, Enum.TextXAlignment.Right)
		cell(tostring(stats.Bricks), 306, 46, Enum.TextXAlignment.Right)
	end
	return column
end

local function show(results: { [string]: any })
	clearCard()
	local winner = results.winner or "Draw"
	local winnerInfo = TeamInfo.get(winner)
	local myTeam = if player.Team then player.Team.Name else nil

	local title = if winnerInfo then string.upper(winnerInfo.DisplayName) .. " WINS!" else "IT'S A DRAW!"
	local personal, personalColor
	if not myTeam or not player:GetAttribute("InMatch") then
		personal, personalColor = "Thanks for watching!", Theme.TextMuted
	elseif winner == "Draw" then
		personal, personalColor = "Nobody lost today.", Theme.Text
	elseif winner == myTeam then
		personal, personalColor = "YOU WON!", Theme.Success
	else
		personal, personalColor = "YOU LOST - GET THEM NEXT TIME!", Theme.Danger
	end

	UIKit.label({
		Text = title,
		TextSize = 60,
		TextColor3 = if winnerInfo then winnerInfo.LightColor else Theme.Accent,
		Size = UDim2.new(1, 0, 0, 66),
		StrokeThickness = 4,
		LayoutOrder = 1,
		Parent = card,
	})
	UIKit.label({
		Text = personal,
		TextSize = 28,
		TextColor3 = personalColor,
		Size = UDim2.new(1, 0, 0, 34),
		LayoutOrder = 2,
		Parent = card,
	})
	UIKit.label({
		Text = string.format(
			"%s   ·   %s mode   ·   %s",
			results.reason or "",
			results.variant or "Classic",
			Format.clock(results.duration or 0)
		),
		TextSize = 16,
		TextColor3 = Theme.TextMuted,
		Size = UDim2.new(1, 0, 0, 22),
		LayoutOrder = 3,
		Parent = card,
	})

	local mvp = results.mvp
	if mvp then
		local pill = UIKit.pill({
			Text = string.format(
				"MVP   %s   ·   %s pts   ·   %d KOs",
				mvp.Name,
				Format.thousands(mvp.Score),
				mvp.KOs
			),
			Size = UDim2.fromOffset(460, 36),
			StrokeColor = Theme.Accent,
			TextColor3 = Theme.Accent,
			LayoutOrder = 4,
		})
		pill.Parent = card
	end

	local columns = UIKit.new("Frame", {
		Size = UDim2.new(1, 0, 0, 300),
		BackgroundTransparency = 1,
		LayoutOrder = 5,
		Parent = card,
	})
	UIKit.list(Enum.FillDirection.Horizontal, 20, Enum.HorizontalAlignment.Center).Parent = columns
	for index, team in results.teams or {} do
		createTeamColumn(team, winner, index).Parent = columns
	end

	overlay.Visible = true
	overlay.GroupTransparency = 1
	UIKit.tween(overlay, 0.4, { GroupTransparency = 0 })
	UIKit.pop(card, 0.08)
end

local function hide()
	if not overlay.Visible then
		return
	end
	UIKit.tween(overlay, 0.4, { GroupTransparency = 1 })
	task.delay(0.42, function()
		if GameState.phase() ~= GameState.Phase.Results then
			overlay.Visible = false
		end
	end)
end

function ResultsController.init()
	screen = UIKit.screen("Results", 40)
	overlay = UIKit.new("CanvasGroup", {
		Name = "Overlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Visible = false,
		Parent = screen,
	})
	card = UIKit.new("Frame", {
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.48),
		Size = UDim2.fromOffset(820, 560),
		BackgroundTransparency = 1,
		Parent = overlay,
	})
	UIKit.list(Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Center).Parent = card
	footer = UIKit.label({
		Name = "Footer",
		Text = "",
		TextSize = 18,
		TextColor3 = Theme.TextMuted,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(600, 24),
		Parent = overlay,
	})
end

function ResultsController.start()
	Remotes.get("MatchResults").OnClientEvent:Connect(show)
	GameState.changed(GameState.Key.Phase):Connect(function()
		if GameState.phase() ~= GameState.Phase.Results then
			hide()
		end
	end)
	RunService.Heartbeat:Connect(function()
		if overlay.Visible then
			footer.Text = string.format("Back to the lobby in %d...", math.ceil(GameState.phaseTimeLeft()))
		end
	end)
end

return ResultsController
