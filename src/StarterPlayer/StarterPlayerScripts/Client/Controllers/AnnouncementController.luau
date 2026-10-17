--!strict
-- Big centre-screen moments: the Get Ready "versus" splash with its ten
-- second countdown, "BATTLE BEGINS!", storm warnings, the Final Showdown,
-- fallen towers and random events.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Format = require(ReplicatedStorage.Shared.Format)
local GameState = require(ReplicatedStorage.Shared.GameState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SoundPlayer = require(ReplicatedStorage.Shared.SoundPlayer)
local TeamInfo = require(ReplicatedStorage.Shared.TeamInfo)
local UIKit = require(ReplicatedStorage.Shared.UIKit)
local Variants = require(ReplicatedStorage.Shared.Variants)

local AnnouncementController = {}

local Theme = UIKit.Theme
local player = Players.LocalPlayer

local screen: ScreenGui
local banner: CanvasGroup
local titleLabel: TextLabel
local subtitleLabel: TextLabel
local splash: CanvasGroup
local splashCountdown: TextLabel
local splashMode: TextLabel
local splashModeDescription: TextLabel
local splashTeamLine: TextLabel
local rosterLabels: { [string]: TextLabel } = {}

local bannerToken = 0

----------------------------------------------------------------------------
-- Banner
----------------------------------------------------------------------------

function AnnouncementController.show(title: string, subtitle: string?, color: Color3?, duration: number?)
	bannerToken += 1
	local token = bannerToken
	titleLabel.Text = title
	titleLabel.TextColor3 = color or Theme.Text
	subtitleLabel.Text = subtitle or ""
	banner.Visible = true
	banner.GroupTransparency = 1
	UIKit.tween(banner, 0.15, { GroupTransparency = 0 })
	UIKit.pop(titleLabel, 0.35)
	task.delay(duration or 2.6, function()
		if bannerToken == token then
			UIKit.tween(banner, 0.4, { GroupTransparency = 1 })
			task.wait(0.45)
			if bannerToken == token then
				banner.Visible = false
			end
		end
	end)
end

----------------------------------------------------------------------------
-- Get Ready splash
----------------------------------------------------------------------------

local function createRosterColumn(info: TeamInfo.TeamInfo, layoutOrder: number): Frame
	local column = UIKit.panel({
		Name = info.Name .. "Roster",
		Size = UDim2.fromOffset(300, 220),
		StrokeColor = info.Color,
		StrokeTransparency = 0,
		StrokeThickness = 3,
		LayoutOrder = layoutOrder,
	})
	UIKit.gradient(info.Color:Lerp(Theme.Ink, 0.55), Theme.Ink, 90).Parent = column
	UIKit.label({
		Text = string.upper(info.DisplayName),
		TextSize = 32,
		TextColor3 = info.LightColor,
		Size = UDim2.new(1, 0, 0, 44),
		Position = UDim2.fromOffset(0, 8),
		Parent = column,
	})
	rosterLabels[info.Name] = UIKit.label({
		Name = "Names",
		Text = "",
		TextSize = 18,
		TextColor3 = Theme.Text,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, -24, 1, -64),
		Position = UDim2.fromOffset(12, 58),
		Parent = column,
	})
	return column
end

local function buildSplash()
	splash = UIKit.new("CanvasGroup", {
		Name = "GetReady",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(820, 420),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = screen,
	})
	splashMode = UIKit.label({
		Name = "Mode",
		Text = "CLASSIC",
		TextSize = 28,
		TextColor3 = Theme.Accent,
		Size = UDim2.new(1, 0, 0, 34),
		Parent = splash,
	})
	splashModeDescription = UIKit.label({
		Name = "ModeDescription",
		Text = "",
		TextSize = 18,
		TextColor3 = Theme.TextMuted,
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.fromOffset(0, 34),
		Parent = splash,
	})

	local row = UIKit.new("Frame", {
		Size = UDim2.new(1, 0, 0, 230),
		Position = UDim2.fromOffset(0, 70),
		BackgroundTransparency = 1,
		Parent = splash,
	})
	UIKit.list(Enum.FillDirection.Horizontal, 20, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center).Parent =
		row
	local teams = TeamInfo.all()
	createRosterColumn(teams[1], 1).Parent = row
	UIKit.label({
		Text = "VS",
		TextSize = 64,
		TextColor3 = Theme.Accent,
		Size = UDim2.fromOffset(120, 100),
		LayoutOrder = 2,
		StrokeThickness = 4,
		Parent = row,
	})
	createRosterColumn(teams[2], 3).Parent = row

	splashTeamLine = UIKit.label({
		Name = "TeamLine",
		Text = "GET READY",
		TextSize = 26,
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.fromOffset(0, 310),
		Parent = splash,
	})
	splashCountdown = UIKit.label({
		Name = "Countdown",
		Text = "10",
		TextSize = 72,
		TextColor3 = Theme.Accent,
		Size = UDim2.new(1, 0, 0, 76),
		Position = UDim2.fromOffset(0, 340),
		StrokeThickness = 4,
		Parent = splash,
	})
end

-- Rosters straight from the Teams, for when we missed the server's snapshot.
local function localRosters(): { [string]: { string } }
	local rosters = {}
	for _, other in Players:GetPlayers() do
		if other.Team and other:GetAttribute("InMatch") then
			local list = rosters[other.Team.Name] or {}
			table.insert(list, other.DisplayName)
			rosters[other.Team.Name] = list
		end
	end
	return rosters
end

local function showSplash(payload: { [string]: any })
	local variant = Variants.get(payload.variant or GameState.get(GameState.Key.Variant))
	splashMode.Text = string.upper(payload.variantName or variant.Name) .. " MODE"
	splashModeDescription.Text = payload.variantDescription or variant.Description
	local rosters = payload.rosters or localRosters()
	for teamName, label in rosterLabels do
		local names = rosters[teamName] or {}
		label.Text = if #names > 0 then table.concat(names, "\n") else "(nobody yet)"
	end
	local team = TeamInfo.get(if player.Team then player.Team.Name else nil)
	if team then
		splashTeamLine.Text = "GET READY - YOU'RE ON " .. string.upper(team.DisplayName)
		splashTeamLine.TextColor3 = team.LightColor
	else
		splashTeamLine.Text = "GET READY - YOU'RE SPECTATING"
		splashTeamLine.TextColor3 = Theme.Text
	end
	splash.Visible = true
	splash.GroupTransparency = 1
	UIKit.tween(splash, 0.3, { GroupTransparency = 0 })
end

local splashHiding = false

local function hideSplash()
	if not splash.Visible or splashHiding then
		return
	end
	splashHiding = true
	UIKit.tween(splash, 0.3, { GroupTransparency = 1 })
	task.delay(0.32, function()
		splashHiding = false
		if GameState.phase() ~= GameState.Phase.GetReady then
			splash.Visible = false
		end
	end)
end

----------------------------------------------------------------------------
-- Announcement handlers
----------------------------------------------------------------------------

local HANDLERS: { [string]: (payload: { [string]: any }) -> () } = {
	GetReady = function(payload)
		showSplash(payload)
	end,
	BattleBegins = function()
		hideSplash()
		SoundPlayer.play("BattleStart")
		AnnouncementController.show("BATTLE BEGINS!", "Destroy the enemy tower!", Theme.Accent, 2.4)
	end,
	StormWarning = function(payload)
		SoundPlayer.play("Notify")
		AnnouncementController.show(
			"THE STORM IS COMING",
			string.format("It forms in %d seconds - stay near the centre!", payload.seconds or 10),
			Color3.fromRGB(216, 180, 254)
		)
	end,
	StormShrinking = function(payload)
		SoundPlayer.play("ZoneAlarm", { maxDuration = 2.5 })
		AnnouncementController.show(
			"THE STORM IS CLOSING IN!",
			string.format("Shrink %d of %d", payload.stage or 1, payload.total or 6),
			Theme.Storm,
			2.2
		)
	end,
	Showdown = function(payload)
		SoundPlayer.play("BattleStart", { pitch = 0.8 })
		AnnouncementController.show(
			"FINAL SHOWDOWN!",
			string.format("No more respawns - %s left. Make it count!", Format.clock(payload.timeLeft or 60)),
			Theme.Danger,
			3.2
		)
	end,
	TowerDestroyed = function(payload)
		local info = TeamInfo.get(payload.team)
		local subtitle = if payload.by then `Final blow by {payload.by}!` else nil
		SoundPlayer.play("Cheer", { maxDuration = 4 })
		AnnouncementController.show(
			string.format("%s TOWER HAS FALLEN!", string.upper(payload.team or "A")),
			subtitle,
			if info then info.LightColor else Theme.Text,
			3.5
		)
	end,
	Event = function(payload)
		SoundPlayer.play("Notify")
		local duration = payload.duration or 0
		local subtitle = payload.description or ""
		if duration > 0 then
			subtitle ..= string.format("  (%ds)", duration)
		end
		AnnouncementController.show(string.upper(payload.name or "EVENT") .. "!", subtitle, Theme.Accent, 2.6)
	end,
}

function AnnouncementController.init()
	screen = UIKit.screen("Announcements", 30)

	banner = UIKit.new("CanvasGroup", {
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.33),
		Size = UDim2.fromOffset(900, 130),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = screen,
	})
	titleLabel = UIKit.label({
		Name = "Title",
		Text = "",
		TextSize = 58,
		Size = UDim2.new(1, 0, 0, 70),
		StrokeThickness = 4,
		Parent = banner,
	})
	subtitleLabel = UIKit.label({
		Name = "Subtitle",
		Text = "",
		TextSize = 22,
		TextColor3 = Theme.Text,
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.fromOffset(0, 74),
		Parent = banner,
	})

	buildSplash()
end

function AnnouncementController.start()
	Remotes.get("Announce").OnClientEvent:Connect(function(kind: string, payload: any)
		local handler = HANDLERS[kind]
		if handler then
			handler(if typeof(payload) == "table" then payload else {})
		end
	end)

	-- Countdown digits and beeps run off the replicated end time, so they stay
	-- in sync even for players who join halfway through the countdown.
	local lastSecond = -1
	local getReadySince: number? = nil
	RunService.RenderStepped:Connect(function()
		if GameState.phase() ~= GameState.Phase.GetReady then
			hideSplash()
			lastSecond = -1
			getReadySince = nil
			return
		end
		getReadySince = getReadySince or os.clock()
		if not splash.Visible and os.clock() - (getReadySince :: number) > 0.6 then
			-- Joined mid-countdown and missed the announcement.
			showSplash({})
		end
		local second = math.ceil(GameState.phaseTimeLeft())
		if second ~= lastSecond and second > 0 then
			lastSecond = second
			splashCountdown.Text = tostring(second)
			UIKit.pop(splashCountdown, 0.4)
			SoundPlayer.play("Countdown", { pitch = if second <= 3 then 1.25 else 1 })
		end
	end)
end

return AnnouncementController
