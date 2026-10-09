# {{TITLE}}

{{INTRO}}

- Works in any Roblox game: R15 or R6 avatars, with or without StreamingEnabled.
- Two files to drag into Studio. No server script, no RemoteEvents, nothing to publish.
- Every player sees every player's {{LOWER}}. Each device animates the pets on its own, so there is
  zero network traffic.
- Purely cosmetic: the parts are anchored and never collide, so the {{LOWER}} can't push players,
  block doors or be used to climb.

---

## What's in this folder

The folders here have the same names as the places in Roblox Studio's **Explorer** where each file goes:

```
{{FILES_TREE}}
```

---

## Install (2 minutes)

1. Open your game in Roblox Studio. If you don't see the Explorer, open it with **View > Explorer**.
2. Drag **`ReplicatedStorage/{{FOLDER}}.rbxm`** from your computer and drop it on **ReplicatedStorage** in the Explorer.
   - Other way: right click **ReplicatedStorage** > **Insert from File...** and pick the file.
3. Drag **`StarterPlayer/StarterPlayerScripts/{{CLIENT}}.rbxm`** and drop it on **StarterPlayerScripts**
   (it's inside **StarterPlayer**, click the arrow next to StarterPlayer to see it).
4. Press **Play**. The {{LOWER}} appears next to your character and follows you around.

If a file lands in the wrong place (for example in Workspace), just drag it in the Explorer to the right one.
When everything is in place, your Explorer looks like this:

```
{{EXPLORER_TREE}}
```

> `.rbxm` files don't open with a double click. Open Roblox Studio first, then drag them into the Studio window.

---

{{PET_DOC}}

---

## Settings

Open **ReplicatedStorage > {{FOLDER}} > Config** (double click it). Change the values, save, press Play.
This is the whole file with the default values:

```lua
{{CONFIG}}
```

What each setting does:

| Setting | What it does |
|---|---|
| `Config.Pets` | The pets every player gets. |
| `Config.GiveTo` | `"Everyone"`: everybody gets `Config.Pets`. `"Attribute"`: only players you choose get a pet (see the recipes below). |
| `Config.Attribute` | Name of the player attribute that picks a player's pets (default `"Pet"`). |
| `Config.ShowOtherPlayersPets` | `false` = each player only sees their own pet. Good for servers with many players or slow devices. |
| `Scale` | Size of the {{LOWER}}. `2` = twice as big, `0.5` = half. Its speed, steps and bubble grow with it. |
| `Spot` | Where it walks next to its owner, in studs: `X` to the right (negative = left), `Z` behind (negative = in front). |
| `Sound` | Sound id of the {{SOUND_WORD}}. `""` = no sound. |
| `SoundStart` | Second of the sound file where the {{SOUND_WORD}} starts (for sounds with silence at the beginning). |
| `Volume` | Volume of the {{SOUND_WORD}}, `0` to `10`. |
| `Texts` | Words that pop up over its head when it {{REACTS}}. One is picked at random. `{}` = no bubble. |
| `Every` | `{ min, max }` seconds between the times it {{REACTS}} on its own. `false` = only when your scripts ask for it. |

---

## Recipes

### Give the {{LOWER}} only to some players (game pass, VIP, admins...)

1. In **Config**, set `Config.GiveTo = "Attribute"`.
2. Add a **Script** (a normal server Script) to **ServerScriptService** and paste this. Change the game pass id:

```lua
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local GAME_PASS_ID = 123456789 -- your game pass id

local function check(player)
	local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, GAME_PASS_ID)
	if ok and owns then
		player:SetAttribute("Pet", "{{NAME}}")
	end
end

Players.PlayerAdded:Connect(check)
for _, player in Players:GetPlayers() do
	check(player)
end

-- Bought it during the game: give it right away.
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if purchased and passId == GAME_PASS_ID then
		player:SetAttribute("Pet", "{{NAME}}")
	end
end)
```

The same idea works for anything: a group rank, a badge, a level, an admin list. Whenever a server script sets
the `Pet` attribute, that player's pets change on every screen right away.

### Let players hide or show their pet

From a server Script (for example when a button or a chat command is used):

```lua
player:SetAttribute("Pet", "")      -- hide this player's pet
player:SetAttribute("Pet", nil)     -- back to the default pets from Config
```

### Make the {{LOWER}} {{REACT}} from your own scripts

From any **LocalScript**:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local PetSpawner = require(ReplicatedStorage:WaitForChild("{{FOLDER}}"):WaitForChild("Modules"):WaitForChild("PetSpawner"))

-- The local player's pets {{REACT}} right now:
PetSpawner.react(Players.LocalPlayer)

-- Only the {{LOWER}}, even if the player has more pets:
PetSpawner.react(Players.LocalPlayer, "{{NAME}}")
```

`PetSpawner.react(player)` works for any player, not only the local one, and only on the device that calls it.
`PetSpawner.getPets(player)` returns that player's pets; each one has a `model` (the Model in
`workspace.AnimatedPets`). Set `Every = false` in Config if it should only {{REACT}} when you say so.

### Make it bigger or smaller

In **Config**, change `Scale` inside `Config.{{NAME}}`: `2` is twice as big, `0.5` is half.
Don't resize the model in **Models** for this, use `Scale`.

### Change its colors and materials

1. Open **ReplicatedStorage > {{FOLDER}} > Models > {{NAME}}**.
2. Click a part (for example `{{BODY_PART}}`) and change **Color**, **Material**, **Transparency** or **Reflectance** in
   the Properties window.
3. Press Play.

Tip: it's easier to edit when you can see it. Drag the **{{NAME}}** model into **Workspace**, edit it, then drag it back
into **Models**. Keep the name `{{NAME}}` and keep the part names.

Anything you put inside a part also comes along: a **Decal**, a **Texture**, **Sparkles**, **Fire**, a
**ParticleEmitter**, a **PointLight**... For example, drop a `PointLight` into `{{BODY_PART}}` and the {{LOWER}} glows.

The size and position of the original parts come from the animation, so moving or resizing them in the model
does nothing. To change the size, use `Scale`.

### Add a hat, a collar or any accessory

1. Drag the **{{NAME}}** model into **Workspace** so you can see it.
2. Add a **Part** or a **MeshPart** (or a whole Model made of parts) **inside** the {{NAME}} model and place it where it
   should be, for example on top of the head.
3. Drag the {{NAME}} model back into **Models** and press Play.

The accessory moves with the closest body part. To choose the body part yourself, select the accessory and
add an **Attribute** named `Bone` (type string) with one of these values:

{{BONES}}

Accessories keep their own size and position, and they are anchored and don't collide, like the rest of the {{LOWER}}.

### Use your own sound

1. Find or upload a sound and copy its id (Creator Store or Creator Hub > Development Items > Audio).
2. In **Config**, set `Sound = "rbxassetid://YOUR_ID"` and `SoundStart = 0`.

Roblox only plays sounds your game is allowed to use: your own uploads, sounds of the group that owns the game,
and public sounds from the Creator Store. {{SOUND_CREDIT}}

### Change the words in the bubble

In **Config**, edit `Texts`, for example `Texts = { {{TEXT_EXAMPLE}} }`. `Texts = {}` turns the bubble off.

---

## Troubleshooting

**No {{LOWER}} appears**
- Check that **{{FOLDER}}** is in **ReplicatedStorage** and **{{CLIENT}}** is in **StarterPlayer > StarterPlayerScripts**
  (not in StarterPlayer itself, not in Workspace).
- Open **View > Output**. Messages starting with `[Pets]` tell you what's wrong, for example a misspelled pet name in
  `Config.Pets`.
- With `GiveTo = "Attribute"`, only players with the `Pet` attribute get pets.

**Output says "[Pets] {{FOLDER}} is missing from ReplicatedStorage"**
- The {{FOLDER}} folder is missing or was renamed. Put `{{FOLDER}}.rbxm` in ReplicatedStorage and keep its name.

**No sound**
- The sound isn't available to your game (see "Use your own sound"), or `Volume` is `0`, or `Sound` is `""`.
- In Studio, check that the game's sound isn't muted (the speaker icon at the top).

**My color changes don't show**
- The model must be in **{{FOLDER}} > Models**, named exactly `{{NAME}}`, and the parts must keep their names.

**Too many pets for my server**
- Set `ShowOtherPlayersPets = false`: each player then only animates their own pet.

---

## Good to know

- Each {{LOWER}} is about {{PART_COUNT}} parts, all moved with a single `workspace:BulkMoveTo` per frame, so it is light even
  with a full server.
- The pets live in a folder called `AnimatedPets` in Workspace, created on each player's device. They are not on the
  server, so server scripts can't see them (that's on purpose).
- The {{LOWER}} finds the ground with a raycast under it, so it walks up ramps and stairs (and on top of terrain
  water). Where there is no floor under it, it stays at its owner's feet height.
- When its owner teleports or respawns far away, the {{LOWER}} jumps straight to its spot next to them.
