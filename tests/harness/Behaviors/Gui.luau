--[[
	GUI behaviors: approximate absolute layout (enough for code that reads
	AbsoluteSize / TextBounds), button input events and text boxes.
	Layout constraints are not simulated.
]]

local roblox = require("@lune/roblox")
local Instances = require("../Instances")
local Reflection = require("../Reflection")

local Vector2 = roblox.Vector2
local states = Instances.state

local function viewportFor(st, ctx)
	local camera = ctx and ctx.camera
	if camera and states(camera) then
		return states(camera).extra.viewport or Vector2.new(1280, 720)
	end
	return Vector2.new(1280, 720)
end

local absoluteSize

local function parentAbsolute(st, ctx)
	local parent = st.parent and states(st.parent)
	if not parent then
		return viewportFor(st, ctx)
	end
	return absoluteSize(parent, ctx)
end

absoluteSize = function(st, ctx)
	local className = st.className
	if className == "ScreenGui" or className == "PlayerGui" or className == "StarterGui" then
		return viewportFor(st, ctx)
	elseif className == "BillboardGui" then
		local size = Instances.getProp(st, "Size", ctx)
		return Vector2.new(size.X.Offset + size.X.Scale * 100, size.Y.Offset + size.Y.Scale * 100)
	elseif className == "SurfaceGui" then
		local canvas = Instances.getProp(st, "CanvasSize", ctx)
		return canvas or Vector2.new(800, 600)
	end
	if not Reflection.isA(className, "GuiObject") then
		return parentAbsolute(st, ctx)
	end
	local size = Instances.getProp(st, "Size", ctx)
	local parentSize = parentAbsolute(st, ctx)
	return Vector2.new(
		parentSize.X * size.X.Scale + size.X.Offset,
		parentSize.Y * size.Y.Scale + size.Y.Offset
	)
end

local function absolutePosition(st, ctx)
	if not Reflection.isA(st.className, "GuiObject") then
		return Vector2.zero
	end
	local parent = st.parent and states(st.parent)
	local origin = if parent then absolutePosition(parent, ctx) else Vector2.zero
	local parentSize = parentAbsolute(st, ctx)
	local position = Instances.getProp(st, "Position", ctx)
	local anchor = Instances.getProp(st, "AnchorPoint", ctx) or Vector2.zero
	local size = absoluteSize(st, ctx)
	return origin
		+ Vector2.new(
			parentSize.X * position.X.Scale + position.X.Offset - anchor.X * size.X,
			parentSize.Y * position.Y.Scale + position.Y.Offset - anchor.Y * size.Y
		)
end

Instances.define("GuiBase2d", {
	props = {
		AbsoluteSize = {
			get = function(_, st, ctx)
				return absoluteSize(st, ctx)
			end,
			readOnly = true,
		},
		AbsolutePosition = {
			get = function(_, st, ctx)
				return absolutePosition(st, ctx)
			end,
			readOnly = true,
		},
		AbsoluteRotation = {
			get = function()
				return 0
			end,
			readOnly = true,
		},
	},
})

Instances.define("GuiObject", {
	events = {
		InputBegan = true,
		InputEnded = true,
		InputChanged = true,
		MouseEnter = true,
		MouseLeave = true,
		MouseMoved = true,
	},
	methods = {
		TweenSize = function(self, size)
			self.Size = size
			return true
		end,
		TweenPosition = function(self, position)
			self.Position = position
			return true
		end,
	},
})

Instances.define("GuiButton", {
	events = {
		Activated = true,
		MouseButton1Click = true,
		MouseButton1Down = true,
		MouseButton1Up = true,
		MouseButton2Click = true,
	},
})

local function textBounds(st, ctx)
	local text = Instances.getProp(st, "Text", ctx) or ""
	local size = Instances.getProp(st, "TextSize", ctx) or 14
	local lines = 1
	for _ in string.gmatch(text, "\n") do
		lines += 1
	end
	local longest = 0
	for line in string.gmatch(text .. "\n", "(.-)\n") do
		longest = math.max(longest, utf8.len(line) or #line)
	end
	return Vector2.new(longest * size * 0.55, lines * size * 1.2)
end

for _, className in { "TextLabel", "TextButton", "TextBox" } do
	Instances.define(className, {
		props = {
			TextBounds = {
				get = function(_, st, ctx)
					return textBounds(st, ctx)
				end,
				readOnly = true,
			},
			TextFits = {
				get = function(_, st, ctx)
					local bounds = textBounds(st, ctx)
					local size = absoluteSize(st, ctx)
					return bounds.X <= size.X and bounds.Y <= size.Y
				end,
				readOnly = true,
			},
		},
	})
end

Instances.define("TextBox", {
	methods = {
		CaptureFocus = function(self)
			local st = states(self)
			st.extra.focused = true
			Instances.fire(st, "Focused", nil)
		end,
		ReleaseFocus = function(self, submitted)
			local st = states(self)
			if st.extra.focused then
				st.extra.focused = false
				Instances.fire(st, "FocusLost", nil, submitted == true, nil)
			end
		end,
		IsFocused = function(self)
			return states(self).extra.focused == true
		end,
	},
	events = { Focused = true, FocusLost = true, ReturnPressedFromOnScreenKeyboard = true },
})

Instances.define("ScrollingFrame", {
	props = {
		AbsoluteCanvasSize = {
			get = function(_, st, ctx)
				local canvas = Instances.getProp(st, "CanvasSize", ctx)
				local size = absoluteSize(st, ctx)
				return Vector2.new(size.X * canvas.X.Scale + canvas.X.Offset, size.Y * canvas.Y.Scale + canvas.Y.Offset)
			end,
			readOnly = true,
		},
		AbsoluteWindowSize = {
			get = function(_, st, ctx)
				return absoluteSize(st, ctx)
			end,
			readOnly = true,
		},
	},
})

local function contentSize(st, ctx)
	local parent = st.parent and states(st.parent)
	if not parent then
		return Vector2.zero
	end
	local direction = Instances.getProp(st, "FillDirection", ctx)
	local vertical = direction == nil or tostring(direction) == "Enum.FillDirection.Vertical"
	local padding = 0
	local paddingProp = Instances.getProp(st, "Padding", ctx)
	if typeof(paddingProp) == "UDim" then
		padding = paddingProp.Offset
	end
	local total, cross = 0, 0
	local count = 0
	for _, child in Instances.children(parent, ctx) do
		local childState = states(child)
		if Reflection.isA(childState.className, "GuiObject") and Instances.getProp(childState, "Visible", ctx) ~= false then
			local size = absoluteSize(childState, ctx)
			count += 1
			if vertical then
				total += size.Y
				cross = math.max(cross, size.X)
			else
				total += size.X
				cross = math.max(cross, size.Y)
			end
		end
	end
	total += math.max(0, count - 1) * padding
	return if vertical then Vector2.new(cross, total) else Vector2.new(total, cross)
end

for _, className in { "UIListLayout", "UIGridLayout", "UIPageLayout", "UITableLayout" } do
	Instances.define(className, {
		props = {
			AbsoluteContentSize = {
				get = function(_, st, ctx)
					return contentSize(st, ctx)
				end,
				readOnly = true,
			},
		},
	})
end

Instances.define("UIGridLayout", {
	props = {
		AbsoluteCellSize = {
			get = function(_, st, ctx)
				local cell = Instances.getProp(st, "CellSize", ctx)
				return Vector2.new(cell.X.Offset, cell.Y.Offset)
			end,
			readOnly = true,
		},
	},
})

return { absoluteSize = absoluteSize }
