--[[
	Builds the client folders ("Work꞉ pet animation", see PetPacks.luau),
	checks them and zips them into "Work pet animation.zip".

	  lune run scripts/build_pet_packs

	Run it from the repository root after changing the pets, the Config or the
	README templates in packs/, and commit the folder and the zip.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")

local PetPacks = require("./PetPacks")

local ZIP = "Work pet animation.zip"

-- Deterministic zip: same files in, same bytes out (no timestamps), names in UTF-8.
local ZIP_SCRIPT = [[
import os, sys, zipfile
folder, target = sys.argv[1], sys.argv[2]
paths = []
for root, dirs, files in os.walk(folder):
    dirs.sort()
    for name in sorted(files):
        paths.append(os.path.join(root, name))
with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
    for path in paths:
        info = zipfile.ZipInfo(path, date_time=(2026, 1, 1, 0, 0, 0))
        info.external_attr = 0o644 << 16
        info.compress_type = zipfile.ZIP_DEFLATED
        with open(path, "rb") as source:
            archive.writestr(info, source.read())
print(len(paths), "files")
]]

local function run(command: string, args: { string })
	local result = process.exec(command, args)
	if not result.ok then
		print(result.stdout)
		print(result.stderr)
		error(command .. " failed")
	end
	return result.stdout
end

if not fs.isDir("build") then
	fs.writeDir("build")
end
-- The model definitions are read through the test runtime, from the built place.
run("rojo", { "build", "default.project.json", "--output", "build/test.rbxl" })

local out = PetPacks.FolderName
local summary = PetPacks.build({ out = out, places = "build/packs" })
PetPacks.verify(out)
for _, entry in summary do
	print(
		string.format(
			"%-12s %-10s %d scripts, pets: %s",
			entry.pack.dir,
			entry.pack.folder,
			entry.scripts,
			table.concat(entry.pack.pets, ", ")
		)
	)
end
for _, name in PetPacks.Placeholders do
	print(string.format("%-12s placeholder", name))
end

if fs.isFile(ZIP) then
	fs.removeFile(ZIP)
end
local zipped = run("python3", { "-I", "-c", ZIP_SCRIPT, out, ZIP })
print(ZIP .. ": " .. string.gsub(zipped, "%s+$", ""))
