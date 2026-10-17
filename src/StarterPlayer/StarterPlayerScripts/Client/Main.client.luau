--!strict
-- Client entry point. Controllers are initialised (build their UI, create
-- sounds) and then started (hook up events and loops). Each runs in a pcall so
-- one broken screen can't take the rest of the client down with it.

local Controllers = script.Parent.Controllers

local ORDER = {
	"CameraController",
	"MusicController",
	"VfxController",
	"ZoneController",
	"WeaponController",
	"NotificationController",
	"HudController",
	"AnnouncementController",
	"ResultsController",
	"SpectateController",
	"LobbyController",
}

local loaded: { { name: string, module: any } } = {}
for _, name in ORDER do
	local ok, result = pcall(require, Controllers:WaitForChild(name))
	if ok then
		table.insert(loaded, { name = name, module = result })
	else
		warn(`[Client] Failed to load {name}: {result}`)
	end
end

for _, phase in { "init", "start" } do
	for _, entry in loaded do
		local method = entry.module[phase]
		if method then
			local ok, err = pcall(method)
			if not ok then
				warn(`[Client] {entry.name}.{phase} failed: {err}`)
			end
		end
	end
end
