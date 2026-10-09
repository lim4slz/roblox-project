# {{TITLE}}

Every animated pet in one install: {{PET_LIST}}. By default every player gets all of them; the Config picks
which pets each player gets.

- Works in any Roblox game: R15 or R6 avatars, with or without StreamingEnabled.
- Two files to drag into Studio. No server script, no RemoteEvents, nothing to publish.
- Every player sees every player's pets. Each device animates the pets on its own, so there is zero network traffic.
- Purely cosmetic: the parts are anchored and never collide, so pets can't push players, block doors or be used
  to climb.

> Use this folder **instead of** the single pet folders. Installing a single pet pack as well gives players that
> pet twice.

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
4. Press **Play**. The pets appear next to your character and follow you around.

If a file lands in the wrong place (for example in Workspace), just drag it in the Explorer to the right one.
When everything is in place, your Explorer looks like this:

```
{{EXPLORER_TREE}}
```

> `.rbxm` files don't open with a double click. Open Roblox Studio first, then drag them into the Studio window.

---

## The pets

{{PET_DOCS}}

Each pet walks on its own spot next to its owner, so they don't bump into each other (change it with `Spot`).

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
| `Config.Pets` | The pets every player gets. Remove the ones you don't want, for example `Config.Pets = { "Dog" }`. |
| `Config.GiveTo` | `"Everyone"`: everybody gets `Config.Pets`. `"Attribute"`: only players you choose get pets (see the recipes below). |
| `Config.Attribute` | Name of the player attribute that picks a player's pets (default `"Pet"`). |
| `Config.ShowOtherPlayersPets` | `false` = each player only sees their own pets. Good for servers with many players or slow devices. |
| `Scale` | Size of that pet. `2` = twice as big, `0.5` = half. Its speed, steps and bubble grow with it. |
| `Spot` | Where it walks next to its owner, in studs: `X` to the right (negative = left), `Z` behind (negative = in front). |
| `Sound` | Sound id of its call (bark, hiss...). `""` = no sound. |
| `SoundStart` | Second of the sound file where the call starts (for sounds with silence at the beginning). |
| `Volume` | Volume of its call, `0` to `10`. |
| `Texts` | Words that pop up over its head when it calls. One is picked at random. `{}` = no bubble. |
| `Every` | `{ min, max }` seconds between the times it calls on its own. `false` = only when your scripts ask for it. |

---

## Recipes

### Let each player have a different pet (shop, game pass, VIP, level...)

The `Pet` attribute on a player picks that player's pets and wins over `Config.Pets`. Set it from any server
**Script** (in ServerScriptService):

```lua
player:SetAttribute("Pet", "Dog")         -- this player gets the dog
player:SetAttribute("Pet", "Dog,Snake")   -- several pets, comma separated
player:SetAttribute("Pet", "")            -- no pet
player:SetAttribute("Pet", nil)           -- back to Config.Pets
```

The change shows on every screen right away. If only players you choose should have pets, also set
`Config.GiveTo = "Attribute"` in Config: then players without the attribute get nothing.

Example: a game pass that gives the snake. Paste in a **Script** in **ServerScriptService** and change the id:

```lua
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local GAME_PASS_ID = 123456789 -- your game pass id

local function check(player)
	local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, GAME_PASS_ID)
	if ok and owns then
		player:SetAttribute("Pet", "Snake")
	end
end

Players.PlayerAdded:Connect(check)
for _, player in Players:GetPlayers() do
	check(player)
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if purchased and passId == GAME_PASS_ID then
		player:SetAttribute("Pet", "Snake")
	end
end)
```

### Make pets react from your own scripts

From any **LocalScript**:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local PetSpawner = require(ReplicatedStorage:WaitForChild("{{FOLDER}}"):WaitForChild("Modules"):WaitForChild("PetSpawner"))

PetSpawner.react(Players.LocalPlayer)          -- all of the local player's pets react now
PetSpawner.react(Players.LocalPlayer, "Snake") -- only the snake hisses
```

{{REACT_SENTENCE}} `PetSpawner.react(player)` works for any player, not only the local one,
and only on the device that calls it. `PetSpawner.getPets(player)` returns that player's pets; each one has a
`model` (the Model in `workspace.AnimatedPets`). Set `Every = false` on a pet if it should only react when you say so.

### Make a pet bigger or smaller

In **Config**, change `Scale` inside that pet's settings (`Config.Dog`, `Config.Snake`...): `2` is twice as big,
`0.5` is half. Don't resize the models in **Models** for this, use `Scale`.

### Change colors and materials

1. Open **ReplicatedStorage > {{FOLDER}} > Models** and pick a pet.
2. Click a part and change **Color**, **Material**, **Transparency** or **Reflectance** in the Properties window.
3. Press Play.

Tip: it's easier to edit when you can see it. Drag the pet's model into **Workspace**, edit it, then drag it back
into **Models**. Keep the model's name (`Dog`, `Snake`...) and the part names.

Anything you put inside a part also comes along: a **Decal**, a **Texture**, **Sparkles**, **Fire**, a
**ParticleEmitter**, a **PointLight**...

The size and position of the original parts come from the animation, so moving or resizing them in the model does
nothing. To change the size, use `Scale`.

### Add a hat, a collar or any accessory

1. Drag the pet's model into **Workspace** so you can see it.
2. Add a **Part** or a **MeshPart** (or a whole Model made of parts) **inside** the pet's model and place it where it
   should be, for example on top of the head.
3. Drag the model back into **Models** and press Play.

The accessory moves with the closest body part. To choose the body part yourself, select the accessory and add an
**Attribute** named `Bone` (type string) with one of these values:

{{BONES}}

Accessories keep their own size and position, and they are anchored and don't collide, like the rest of the pet.

### Use your own sounds

1. Find or upload a sound and copy its id (Creator Store or Creator Hub > Development Items > Audio).
2. In **Config**, in that pet's settings, set `Sound = "rbxassetid://YOUR_ID"` and `SoundStart = 0`.

Roblox only plays sounds your game is allowed to use: your own uploads, sounds of the group that owns the game, and
public sounds from the Creator Store. About the default sounds:

{{SOUND_CREDITS}}

### Change the words in the bubbles

In **Config**, edit `Texts` in that pet's settings. `Texts = {}` turns its bubble off.

---

## Troubleshooting

**No pets appear**
- Check that **{{FOLDER}}** is in **ReplicatedStorage** and **{{CLIENT}}** is in **StarterPlayer > StarterPlayerScripts**
  (not in StarterPlayer itself, not in Workspace).
- Open **View > Output**. Messages starting with `[Pets]` tell you what's wrong, for example a misspelled pet name in
  `Config.Pets` (the names are {{PET_LIST}}, with capital letters).
- With `GiveTo = "Attribute"`, only players with the `Pet` attribute get pets.

**Output says "[Pets] {{FOLDER}} is missing from ReplicatedStorage"**
- The {{FOLDER}} folder is missing or was renamed. Put `{{FOLDER}}.rbxm` in ReplicatedStorage and keep its name.

**No sound**
- The sound isn't available to your game (see "Use your own sounds"), or `Volume` is `0`, or `Sound` is `""`.
- In Studio, check that the game's sound isn't muted (the speaker icon at the top).

**My color changes don't show**
- The model must be in **{{FOLDER}} > Models**, keep its name (`Dog`, `Snake`...), and the parts must keep their names.

**Too many pets for my server**
- Give fewer pets per player (`Config.Pets`), or set `ShowOtherPlayersPets = false`: each player then only animates
  their own pets.

---

## Good to know

- Each pet is 25 to 35 parts, all moved with a single `workspace:BulkMoveTo` per frame, so they are light even with a
  full server.
- The pets live in a folder called `AnimatedPets` in Workspace, created on each player's device. They are not on the
  server, so server scripts can't see them (that's on purpose).
- Pets find the ground with a raycast under them, so they walk up ramps and stairs (and on top of terrain water).
  Where there is no floor under them, they stay at their owner's feet height.
- When their owner teleports or respawns far away, the pets jump straight to their spots next to them.
