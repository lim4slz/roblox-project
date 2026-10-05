--!strict
--[[
	Format
	Human-friendly formatting for numbers and durations shown in the UI.
]]

local Format = {}

--- 1234567 -> "1,234,567"
function Format.commas(value: number): string
	local negative = value < 0
	local digits = tostring(math.floor(math.abs(value)))
	local formatted = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return (if negative then "-" else "") .. formatted
end

local SHORT_UNITS: { { threshold: number, suffix: string } } = {
	{ threshold = 1e9, suffix = "B" },
	{ threshold = 1e6, suffix = "M" },
	{ threshold = 1e3, suffix = "K" },
}

--- 15300 -> "15.3K", 2500000 -> "2.5M"; values below 10,000 keep full precision with commas.
function Format.short(value: number): string
	local absolute = math.abs(value)
	if absolute < 10000 then
		return Format.commas(value)
	end
	for _, unit in SHORT_UNITS do
		if absolute >= unit.threshold then
			local scaled = math.floor(value / unit.threshold * 10) / 10
			local text = string.format("%.1f", scaled):gsub("%.0$", "")
			return text .. unit.suffix
		end
	end
	return Format.commas(value)
end

--- 65 -> "1:05", 3725 -> "1:02:05"
function Format.clock(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	local hours = total // 3600
	local minutes = (total % 3600) // 60
	local secs = total % 60
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, secs)
	end
	return string.format("%d:%02d", minutes, secs)
end

--- 3725 -> "1h 2m", 125 -> "2m 5s", 40 -> "40s"
function Format.duration(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	local hours = total // 3600
	local minutes = (total % 3600) // 60
	local secs = total % 60
	if hours > 0 then
		return string.format("%dh %dm", hours, minutes)
	elseif minutes > 0 then
		return string.format("%dm %ds", minutes, secs)
	end
	return string.format("%ds", secs)
end

--- "x2" style multiplier label, e.g. Format.count("Apple", 3) -> "3x Apple"
function Format.count(name: string, amount: number): string
	return string.format("%sx %s", Format.commas(amount), name)
end

return Format
