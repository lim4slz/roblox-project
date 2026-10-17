--!strict
-- Small text helpers for the UI.

local Format = {}

-- 125.4 -> "2:06" (rounds up so a timer never shows 0:00 while time remains)
function Format.clock(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

function Format.percent(fraction: number): string
	return string.format("%d%%", math.floor(math.clamp(fraction, 0, 1) * 100 + 0.5))
end

-- 1234567 -> "1,234,567"
function Format.thousands(value: number): string
	local text = tostring(math.floor(value))
	local formatted, count = text:reverse():gsub("(%d%d%d)", "%1,")
	formatted = formatted:reverse()
	if count > 0 and formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return formatted
end

function Format.plural(count: number, singular: string, pluralForm: string?): string
	if count == 1 then
		return string.format("%d %s", count, singular)
	end
	return string.format("%d %s", count, pluralForm or singular .. "s")
end

return Format
