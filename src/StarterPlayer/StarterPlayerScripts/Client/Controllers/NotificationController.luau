--!strict
-- Small, quick feedback: toasts on the right ("+5 bricks", "Mega Bomb ready")
-- and a compact kill feed under the score.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SoundPlayer = require(ReplicatedStorage.Shared.SoundPlayer)
local TeamInfo = require(ReplicatedStorage.Shared.TeamInfo)
local UIKit = require(ReplicatedStorage.Shared.UIKit)

local NotificationController = {}

local Theme = UIKit.Theme

local MAX_TOASTS = 4
local TOAST_LIFETIME = 3.5
local MAX_FEED = 4
local FEED_LIFETIME = 6

local STYLES: { [string]: { color: Color3, sound: string? } } = {
	info = { color = Theme.Teal, sound = "Pop" },
	success = { color = Theme.Success, sound = "Pop" },
	warning = { color = Theme.Danger, sound = "Notify" },
	powerup = { color = Theme.Accent, sound = "PowerUp" },
	knockout = { color = Theme.Accent, sound = "Knockout" },
	score = { color = Theme.Teal, sound = nil },
}

-- Verbs for the kill feed, keyed by how the knockout happened.
local HOW_TEXT: { [string]: string } = {
	Bomb = "bombed",
	Mega = "MEGA-bombed",
	Rocket = "rocketed",
	Sword = "sliced",
	Rain = "was flattened by bomb rain",
	Storm = "was caught in the storm",
	Fall = "fell off the map",
	Self = "blew themselves up",
}

local toastList: Frame
local feedList: Frame

local function trim(container: Frame, maxCount: number)
	local children = {}
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			table.insert(children, child)
		end
	end
	table.sort(children, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	while #children > maxCount do
		local oldest = table.remove(children, 1)
		if oldest then
			oldest:Destroy()
		end
	end
end

local order = 0
local function nextOrder(): number
	order += 1
	return order
end

function NotificationController.toast(text: string, style: string?)
	local styleInfo = STYLES[style or "info"] or STYLES.info
	local toast = UIKit.panel({
		Name = "Toast",
		Size = UDim2.fromOffset(330, 40),
		StrokeColor = styleInfo.color,
		StrokeTransparency = 0.1,
		LayoutOrder = nextOrder(),
		Parent = toastList,
	})
	local accent = UIKit.new("Frame", {
		Size = UDim2.new(0, 6, 1, -12),
		Position = UDim2.fromOffset(8, 6),
		BackgroundColor3 = styleInfo.color,
		BorderSizePixel = 0,
		Parent = toast,
	})
	UIKit.corner(UDim.new(1, 0)).Parent = accent
	UIKit.label({
		Text = text,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -30, 1, 0),
		Position = UDim2.fromOffset(22, 0),
		Parent = toast,
	})
	trim(toastList, MAX_TOASTS)
	UIKit.pop(toast, 0.1)
	if styleInfo.sound then
		SoundPlayer.play(styleInfo.sound)
	end
	task.delay(TOAST_LIFETIME, function()
		if toast.Parent then
			UIKit.fade(toast, false, 0.3)
			task.wait(0.35)
			toast:Destroy()
		end
	end)
end

local function addFeedEntry(
	killerName: string?,
	victimName: string,
	how: string,
	killerTeam: string?,
	victimTeam: string?
)
	local entry = UIKit.panel({
		Name = "FeedEntry",
		Size = UDim2.fromOffset(330, 30),
		BackgroundTransparency = 0.35,
		StrokeTransparency = 0.9,
		LayoutOrder = nextOrder(),
		Parent = feedList,
	})
	local function hex(color: Color3): string
		return color:ToHex()
	end
	local victim = string.format(
		'<font color="#%s">%s</font>',
		hex(TeamInfo.colorOf(victimTeam):Lerp(Color3.new(1, 1, 1), 0.3)),
		victimName
	)
	local text
	if killerName then
		local killer = string.format(
			'<font color="#%s">%s</font>',
			hex(TeamInfo.colorOf(killerTeam):Lerp(Color3.new(1, 1, 1), 0.3)),
			killerName
		)
		text = string.format("%s %s %s", killer, HOW_TEXT[how] or "knocked out", victim)
	else
		text = string.format("%s %s", victim, HOW_TEXT[how] or "was knocked out")
	end
	UIKit.label({
		Text = text,
		RichText = true,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.fromOffset(8, 0),
		Parent = entry,
	})
	trim(feedList, MAX_FEED)
	task.delay(FEED_LIFETIME, function()
		if entry.Parent then
			UIKit.fade(entry, false, 0.4)
			task.wait(0.45)
			entry:Destroy()
		end
	end)
end

function NotificationController.init()
	local screen = UIKit.screen("Notifications", 20)
	local inset = UIKit.topInset()

	toastList = UIKit.new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.55, 0),
		Size = UDim2.fromOffset(330, 200),
		BackgroundTransparency = 1,
		Parent = screen,
	})
	UIKit.list(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Bottom).Parent =
		toastList

	feedList = UIKit.new("Frame", {
		Name = "KillFeed",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, inset + 56),
		Size = UDim2.fromOffset(330, 140),
		BackgroundTransparency = 1,
		Parent = screen,
	})
	UIKit.list(Enum.FillDirection.Vertical, 4, Enum.HorizontalAlignment.Right).Parent = feedList
end

function NotificationController.start()
	Remotes.get("Toast").OnClientEvent:Connect(NotificationController.toast)
	Remotes.get("KillFeed").OnClientEvent:Connect(addFeedEntry)
end

return NotificationController
