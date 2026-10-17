--!strict
-- Convenience lookups over Config.Teams, with the colours converted to Color3.

local Config = require(script.Parent.Config)

export type TeamInfo = {
	Name: string,
	DisplayName: string,
	BrickColor: BrickColor,
	Color: Color3,
	LightColor: Color3,
	DarkColor: Color3,
	Index: number,
}

local TeamInfo = {}

local byName: { [string]: TeamInfo } = {}
local ordered: { TeamInfo } = {}

local function toColor(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

for index, definition in Config.Teams do
	local info: TeamInfo = {
		Name = definition.Name,
		DisplayName = definition.DisplayName,
		BrickColor = BrickColor.new(definition.BrickColor :: any),
		Color = toColor(definition.Color),
		LightColor = toColor(definition.LightColor),
		DarkColor = toColor(definition.DarkColor),
		Index = index,
	}
	byName[info.Name] = info
	table.insert(ordered, info)
end

function TeamInfo.all(): { TeamInfo }
	return ordered
end

function TeamInfo.get(teamName: string?): TeamInfo?
	if not teamName then
		return nil
	end
	return byName[teamName]
end

-- The single opposing team in a two-team match.
function TeamInfo.opponentOf(teamName: string): TeamInfo?
	for _, info in ordered do
		if info.Name ~= teamName then
			return info
		end
	end
	return nil
end

function TeamInfo.ofPlayer(player: Player): TeamInfo?
	local team = player.Team
	if not team then
		return nil
	end
	return byName[team.Name]
end

-- Neutral grey for "no team" (lobby, draws, bomb rain).
TeamInfo.NeutralColor = Color3.fromRGB(226, 232, 240)

function TeamInfo.colorOf(teamName: string?): Color3
	local info = TeamInfo.get(teamName)
	return if info then info.Color else TeamInfo.NeutralColor
end

return TeamInfo
