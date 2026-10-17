--!nonstrict
-- The game's UI toolkit: a tiny declarative `new` helper plus the handful of
-- styled building blocks every screen is made from (panels, pills, buttons,
-- bars). Keeping the look in one file is what makes the HUD, lobby, results and
-- admin panel feel like one game.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local SoundPlayer = require(script.Parent.SoundPlayer)

local UIKit = {}

UIKit.Theme = {
	Font = Enum.Font.FredokaOne,
	Ink = Color3.fromRGB(15, 23, 42),
	InkSoft = Color3.fromRGB(30, 41, 59),
	PanelTransparency = 0.12,
	Text = Color3.fromRGB(255, 255, 255),
	TextMuted = Color3.fromRGB(203, 213, 225),
	Accent = Color3.fromRGB(250, 204, 21), -- sunny yellow
	Teal = Color3.fromRGB(45, 212, 191),
	Danger = Color3.fromRGB(248, 113, 113),
	Success = Color3.fromRGB(74, 222, 128),
	Storm = Color3.fromRGB(168, 85, 247),
	Outline = Color3.fromRGB(255, 255, 255),
	Corner = UDim.new(0, 14),
}

local Theme = UIKit.Theme

-- Design resolution; everything is laid out for this and scaled to fit.
local DESIGN_SIZE = Vector2.new(1280, 720)

----------------------------------------------------------------------------
-- Core helpers
----------------------------------------------------------------------------

-- new("Frame", { Size = ..., Children = { ... } })
function UIKit.new(className: string, props: { [string]: any }?): any
	local instance = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Children" then
				for _, child in value do
					child.Parent = instance
				end
			elseif key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end
	-- Parent last so property changes don't replicate/render one by one.
	if parent then
		instance.Parent = parent
	end
	return instance
end

function UIKit.corner(radius: (UDim | number)?): UICorner
	local value = radius or Theme.Corner
	if typeof(value) == "number" then
		value = UDim.new(0, value)
	end
	return UIKit.new("UICorner", { CornerRadius = value })
end

function UIKit.stroke(color: Color3?, thickness: number?, transparency: number?): UIStroke
	return UIKit.new("UIStroke", {
		Color = color or Theme.Outline,
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

-- Dark outline around text so it stays readable over a bright 3D world.
function UIKit.textStroke(thickness: number?, transparency: number?): UIStroke
	return UIKit.new("UIStroke", {
		Color = Theme.Ink,
		Thickness = thickness or 2,
		Transparency = transparency or 0.2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	})
end

function UIKit.padding(top: number, right: number?, bottom: number?, left: number?): UIPadding
	return UIKit.new("UIPadding", {
		PaddingTop = UDim.new(0, top),
		PaddingRight = UDim.new(0, right or top),
		PaddingBottom = UDim.new(0, bottom or top),
		PaddingLeft = UDim.new(0, left or right or top),
	})
end

function UIKit.list(
	direction: Enum.FillDirection?,
	gap: number?,
	horizontal: Enum.HorizontalAlignment?,
	vertical: Enum.VerticalAlignment?
): UIListLayout
	return UIKit.new("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap or 6),
		HorizontalAlignment = horizontal or Enum.HorizontalAlignment.Center,
		VerticalAlignment = vertical or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

function UIKit.gradient(top: Color3, bottom: Color3, rotation: number?): UIGradient
	return UIKit.new("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = rotation or 90,
	})
end

function UIKit.tween(
	instance: Instance,
	duration: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
): Tween
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		goal
	)
	tween:Play()
	return tween
end

----------------------------------------------------------------------------
-- Screens
----------------------------------------------------------------------------

local function fitScale(): number
	local camera = workspace.CurrentCamera
	if not camera then
		return 1
	end
	local viewport = camera.ViewportSize
	local fit = math.min(viewport.X / DESIGN_SIZE.X, viewport.Y / DESIGN_SIZE.Y)
	return math.clamp(fit, 0.5, 1.35)
end

-- A ScreenGui that scales its contents to fit any screen, phone to monitor.
-- Children are laid out in "design pixels" (1280x720) and scaled down/up.
function UIKit.screen(name: string, displayOrder: number?): ScreenGui
	local screen = UIKit.new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = displayOrder or 0,
	})
	local scale = UIKit.new("UIScale", { Name = "AutoScale", Parent = screen })

	local function refresh()
		scale.Scale = fitScale()
	end
	refresh()
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(refresh)
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(refresh)
	end

	local player = Players.LocalPlayer
	if player then
		screen.Parent = player:WaitForChild("PlayerGui")
	end
	return screen
end

-- Height of the Roblox top bar in design pixels, so our top HUD sits just
-- below it at any scale.
function UIKit.topInset(): number
	local inset = GuiService:GetGuiInset()
	return inset.Y / fitScale()
end

----------------------------------------------------------------------------
-- Building blocks
----------------------------------------------------------------------------

-- Style options our components understand that are not Instance properties.
local STYLE_KEYS = {
	CornerRadius = true,
	StrokeColor = true,
	StrokeThickness = true,
	StrokeTransparency = true,
	Stroke = true,
	Color = true,
	FromRight = true,
}

-- Merges `props` over `defaults`, dropping style-only keys.
local function instanceProps(defaults: { [string]: any }, props: { [string]: any }): { [string]: any }
	local merged = table.clone(defaults)
	for key, value in props do
		if not STYLE_KEYS[key] then
			merged[key] = value
		end
	end
	return merged
end

function UIKit.label(props: { [string]: any }): TextLabel
	local label = UIKit.new(
		"TextLabel",
		instanceProps({
			BackgroundTransparency = 1,
			Font = Theme.Font,
			TextColor3 = Theme.Text,
			TextSize = 20,
			Size = UDim2.fromScale(1, 1),
			TextWrapped = true,
		}, props)
	)
	if props.Stroke ~= false then
		UIKit.textStroke(props.StrokeThickness).Parent = label
	end
	return label
end

-- Dark rounded card with a soft white outline.
function UIKit.panel(props: { [string]: any }): Frame
	local panel = UIKit.new(
		"Frame",
		instanceProps({
			BackgroundColor3 = Theme.Ink,
			BackgroundTransparency = Theme.PanelTransparency,
			BorderSizePixel = 0,
		}, props)
	)
	UIKit.corner(props.CornerRadius).Parent = panel
	UIKit.stroke(props.StrokeColor or Theme.Outline, props.StrokeThickness or 2, props.StrokeTransparency or 0.75).Parent =
		panel
	return panel
end

-- Pill-shaped tag like "LOW GRAVITY 0:12".
function UIKit.pill(props: { [string]: any }): Frame
	local pill = UIKit.panel({
		Name = props.Name or "Pill",
		Size = props.Size or UDim2.fromOffset(200, 36),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		BackgroundColor3 = props.BackgroundColor3 or Theme.Ink,
		StrokeColor = props.StrokeColor or Theme.Teal,
		StrokeTransparency = props.StrokeTransparency or 0.1,
		CornerRadius = UDim.new(1, 0),
		LayoutOrder = props.LayoutOrder,
		Visible = props.Visible,
	})
	UIKit.label({
		Name = "Text",
		Text = props.Text or "",
		TextSize = props.TextSize or 18,
		TextColor3 = props.TextColor3 or Theme.Text,
		Size = UDim2.new(1, -20, 1, 0),
		Position = UDim2.fromOffset(10, 0),
		Parent = pill,
	})
	return pill
end

-- Chunky game button with hover/press feedback and a click sound.
function UIKit.button(props: { [string]: any }, onClick: (() -> ())?): TextButton
	local color = props.Color or Theme.Accent
	local button = UIKit.new("TextButton", {
		Name = props.Name or "Button",
		Size = props.Size or UDim2.fromOffset(180, 44),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		BackgroundColor3 = color,
		AutoButtonColor = false,
		Text = props.Text or "",
		Font = Theme.Font,
		TextSize = props.TextSize or 20,
		TextColor3 = props.TextColor3 or Theme.Ink,
		TextWrapped = true,
		Visible = props.Visible,
	})
	UIKit.corner(props.CornerRadius or UDim.new(0, 12)).Parent = button
	UIKit.stroke(Theme.Ink, 3, 0.15).Parent = button
	UIKit.gradient(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200), 90).Parent = button
	local scale = UIKit.new("UIScale", { Parent = button })

	button.MouseEnter:Connect(function()
		UIKit.tween(scale, 0.12, { Scale = 1.05 })
		SoundPlayer.play("UiHover")
	end)
	button.MouseLeave:Connect(function()
		UIKit.tween(scale, 0.12, { Scale = 1 })
	end)
	button.MouseButton1Down:Connect(function()
		UIKit.tween(scale, 0.06, { Scale = 0.95 })
	end)
	button.MouseButton1Up:Connect(function()
		UIKit.tween(scale, 0.1, { Scale = 1.05 })
	end)
	if onClick then
		button.Activated:Connect(function()
			SoundPlayer.play("UiClick")
			onClick()
		end)
	end
	if props.Parent then
		button.Parent = props.Parent
	end
	return button
end

export type Bar = {
	Frame: Frame,
	Fill: Frame,
	set: (fraction: number, instant: boolean?) -> (),
	setColor: (color: Color3) -> (),
}

-- Horizontal progress bar. `fromRight` makes it drain toward the right edge,
-- which mirrors the left/right tower bars around the timer.
function UIKit.bar(props: { [string]: any }): Bar
	local frame = UIKit.new("Frame", {
		Name = props.Name or "Bar",
		Size = props.Size or UDim2.fromOffset(240, 16),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		BackgroundColor3 = Theme.InkSoft,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		LayoutOrder = props.LayoutOrder,
		Parent = props.Parent,
	})
	UIKit.corner(UDim.new(1, 0)).Parent = frame
	UIKit.stroke(Theme.Ink, 2, 0.1).Parent = frame

	local fromRight = props.FromRight == true
	local fill = UIKit.new("Frame", {
		Name = "Fill",
		AnchorPoint = if fromRight then Vector2.new(1, 0) else Vector2.zero,
		Position = if fromRight then UDim2.fromScale(1, 0) else UDim2.fromScale(0, 0),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = props.Color or Theme.Accent,
		BorderSizePixel = 0,
		Parent = frame,
	})
	UIKit.corner(UDim.new(1, 0)).Parent = fill
	UIKit.gradient(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190), 90).Parent = fill

	local bar = {} :: Bar
	bar.Frame = frame
	bar.Fill = fill
	function bar.set(fraction: number, instant: boolean?)
		local goal = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
		if instant then
			fill.Size = goal
		else
			UIKit.tween(fill, 0.35, { Size = goal })
		end
	end
	function bar.setColor(color: Color3)
		fill.BackgroundColor3 = color
	end
	return bar
end

-- Little bounce used when a value changes (score ticks, timer warnings).
function UIKit.pop(guiObject: GuiObject, strength: number?)
	local scale = guiObject:FindFirstChild("PopScale") :: UIScale?
	if not scale then
		scale = UIKit.new("UIScale", { Name = "PopScale", Parent = guiObject })
	end
	assert(scale)
	scale.Scale = 1 + (strength or 0.15)
	UIKit.tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- Fades every visual property of a subtree in or out.
function UIKit.fade(root: GuiObject, visible: boolean, duration: number?)
	local time = duration or 0.25
	local targets = { root }
	for _, descendant in root:GetDescendants() do
		table.insert(targets, descendant)
	end
	for _, item in targets do
		local original = item:GetAttribute("_baseTransparency")
		if item:IsA("TextLabel") or item:IsA("TextButton") then
			if original == nil then
				original = item.TextTransparency
				item:SetAttribute("_baseTransparency", original)
			end
			UIKit.tween(item, time, { TextTransparency = if visible then original else 1 })
		elseif item:IsA("UIStroke") then
			if original == nil then
				original = item.Transparency
				item:SetAttribute("_baseTransparency", original)
			end
			UIKit.tween(item, time, { Transparency = if visible then original else 1 })
		end
		if item:IsA("GuiObject") then
			local originalBg = item:GetAttribute("_baseBackground")
			if originalBg == nil then
				originalBg = item.BackgroundTransparency
				item:SetAttribute("_baseBackground", originalBg)
			end
			UIKit.tween(item, time, { BackgroundTransparency = if visible then originalBg else 1 })
		end
	end
end

return UIKit
