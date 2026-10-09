# Animated Dog Pet

A cartoon dog that follows each player around: it walks, runs, wags its tail, blinks, pants and barks "WOOF!" with a pop-up bubble.

- Works in any Roblox game: R15 or R6 avatars, with or without StreamingEnabled.
- Two files to drag into Studio. No server script, no RemoteEvents, nothing to publish.
- Every player sees every player's dog. Each device animates the pets on its own, so there is
  zero network traffic.
- Purely cosmetic: the parts are anchored and never collide, so the dog can't push players,
  block doors or be used to climb.

---

## What's in this folder

The folders here have the same names as the places in Roblox Studio's **Explorer** where each file goes:

```
Dog/
├── README.md                    you are here
├── ReplicatedStorage/
│   └── DogPet.rbxm              drag onto ReplicatedStorage
└── StarterPlayer/
    └── StarterPlayerScripts/
        └── DogPetClient.rbxm    drag onto StarterPlayer > StarterPlayerScripts
```

---

## Install (2 minutes)

1. Open your game in Roblox Studio. If you don't see the Explorer, open it with **View > Explorer**.
2. Drag **`ReplicatedStorage/DogPet.rbxm`** from your computer and drop it on **ReplicatedStorage** in the Explorer.
   - Other way: right click **ReplicatedStorage** > **Insert from File...** and pick the file.
3. Drag **`StarterPlayer/StarterPlayerScripts/DogPetClient.rbxm`** and drop it on **StarterPlayerScripts**
   (it's inside **StarterPlayer**, click the arrow next to StarterPlayer to see it).
4. Press **Play**. The dog appears next to your character and follows you around.

If a file lands in the wrong place (for example in Workspace), just drag it in the Explorer to the right one.
When everything is in place, your Explorer looks like this:

```
ReplicatedStorage
└── DogPet                (Folder)
    ├── Config            (ModuleScript)  all the settings
    ├── Models            (Folder)
    │   └── Dog           (Model)         the look of the dog
    └── Modules           (Folder)        the code, you don't need to touch it
        ├── DogAnimation  (ModuleScript)
        ├── DogModel      (ModuleScript)
        ├── DogPet        (ModuleScript)
        ├── PetFollow     (ModuleScript)
        ├── PetKit        (ModuleScript)
        ├── PetRig        (ModuleScript)
        └── PetSpawner    (ModuleScript)
StarterPlayer
└── StarterPlayerScripts
    └── DogPetClient      (LocalScript)   starts the pets
```

> `.rbxm` files don't open with a double click. Open Roblox Studio first, then drag them into the Studio window.

---

## What the dog does

A blocky cartoon dog with big floppy ears and a white-tipped tail. Everything is procedural, so it reacts to
how fast its owner moves instead of playing fixed animations:

- **Idle**: a happy bounce, looks around with a curious head tilt, wags its tail, blinks now and then, and turns
  to look at its owner.
- **Walk**: a bouncy waddle with diagonal leg pairs, head nodding with the steps, ears flopping.
- **Run**: when it falls behind it gallops with big hops, ears swept back and the tongue out, panting.
- **WOOF!**: every few seconds it barks in bursts of 1 to 3: a quick crouch, a hop, the head snaps up, the mouth
  opens, the eyes squint happily, the tail wags faster, and a **WOOF!** bubble pops up with a bark sound
  (each bark slightly different in pitch).

It walks a little behind its owner, on the right. When its owner stops, it trots to its spot, stops and looks at them.

---

## Settings

Open **ReplicatedStorage > DogPet > Config** (double click it). Change the values, save, press Play.
This is the whole file with the default values:

```lua
--[[
	Pet settings. Change anything here and press Play to see it.
	The full guide is in README.md, next to the files you dragged in.
]]

local Config = {}

-- Pets every player gets. Pet names: "Dog"
Config.Pets = { "Dog" }

-- Who gets pets:
--   "Everyone"   every player gets Config.Pets (default)
--   "Attribute"  only players whose "Pet" attribute is set by your scripts
-- On any player the attribute wins over Config.Pets. From a server Script:
--   player:SetAttribute("Pet", "Dog")   that player gets the dog
--   player:SetAttribute("Pet", "")      no pet
--   player:SetAttribute("Pet", nil)     back to Config.Pets
Config.GiveTo = "Everyone"
Config.Attribute = "Pet"

-- false = each player only sees their own pets (lighter on big servers).
Config.ShowOtherPlayersPets = true

-- DOG ------------------------------------------------------------------------
Config.Dog = {
	-- 1 = original size, 2 = twice as big, 0.5 = half.
	Scale = 1,
	-- Where it walks next to its owner, in studs: X to the right (negative =
	-- left), Z behind (negative = in front).
	Spot = Vector3.new(2.6, 0, 3.4),
	-- The bark. Any sound id your game is allowed to play. "" = no sound.
	Sound = "rbxassetid://7103147161",
	SoundStart = 0, -- second of the sound file where the bark starts
	Volume = 0.6,
	-- Words that pop up over its head when it barks. {} = no bubble.
	Texts = { "WOOF!", "Woof!", "WOOF!", "WOOF!!" },
	-- Seconds between the barks it does on its own: { min, max }.
	-- false = it only barks when your scripts call PetSpawner.react.
	Every = { 3.5, 8 },
}

return Config
```

What each setting does:

| Setting | What it does |
|---|---|
| `Config.Pets` | The pets every player gets. |
| `Config.GiveTo` | `"Everyone"`: everybody gets `Config.Pets`. `"Attribute"`: only players you choose get a pet (see the recipes below). |
| `Config.Attribute` | Name of the player attribute that picks a player's pets (default `"Pet"`). |
| `Config.ShowOtherPlayersPets` | `false` = each player only sees their own pet. Good for servers with many players or slow devices. |
| `Scale` | Size of the dog. `2` = twice as big, `0.5` = half. Its speed, steps and bubble grow with it. |
| `Spot` | Where it walks next to its owner, in studs: `X` to the right (negative = left), `Z` behind (negative = in front). |
| `Sound` | Sound id of the bark. `""` = no sound. |
| `SoundStart` | Second of the sound file where the bark starts (for sounds with silence at the beginning). |
| `Volume` | Volume of the bark, `0` to `10`. |
| `Texts` | Words that pop up over its head when it barks. One is picked at random. `{}` = no bubble. |
| `Every` | `{ min, max }` seconds between the times it barks on its own. `false` = only when your scripts ask for it. |

---

## Recipes

### Give the dog only to some players (game pass, VIP, admins...)

1. In **Config**, set `Config.GiveTo = "Attribute"`.
2. Add a **Script** (a normal server Script) to **ServerScriptService** and paste this. Change the game pass id:

```lua
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local GAME_PASS_ID = 123456789 -- your game pass id

local function check(player)
	local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, GAME_PASS_ID)
	if ok and owns then
		player:SetAttribute("Pet", "Dog")
	end
end

Players.PlayerAdded:Connect(check)
for _, player in Players:GetPlayers() do
	check(player)
end

-- Bought it during the game: give it right away.
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if purchased and passId == GAME_PASS_ID then
		player:SetAttribute("Pet", "Dog")
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

### Make the dog bark from your own scripts

From any **LocalScript**:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local PetSpawner = require(ReplicatedStorage:WaitForChild("DogPet"):WaitForChild("Modules"):WaitForChild("PetSpawner"))

-- The local player's pets bark right now:
PetSpawner.react(Players.LocalPlayer)

-- Only the dog, even if the player has more pets:
PetSpawner.react(Players.LocalPlayer, "Dog")
```

`PetSpawner.react(player)` works for any player, not only the local one, and only on the device that calls it.
`PetSpawner.getPets(player)` returns that player's pets; each one has a `model` (the Model in
`workspace.AnimatedPets`). Set `Every = false` in Config if it should only bark when you say so.

### Make it bigger or smaller

In **Config**, change `Scale` inside `Config.Dog`: `2` is twice as big, `0.5` is half.
Don't resize the model in **Models** for this, use `Scale`.

### Change its colors and materials

1. Open **ReplicatedStorage > DogPet > Models > Dog**.
2. Click a part (for example `Body`) and change **Color**, **Material**, **Transparency** or **Reflectance** in
   the Properties window.
3. Press Play.

Tip: it's easier to edit when you can see it. Drag the **Dog** model into **Workspace**, edit it, then drag it back
into **Models**. Keep the name `Dog` and keep the part names.

Anything you put inside a part also comes along: a **Decal**, a **Texture**, **Sparkles**, **Fire**, a
**ParticleEmitter**, a **PointLight**... For example, drop a `PointLight` into `Body` and the dog glows.

The size and position of the original parts come from the animation, so moving or resizing them in the model
does nothing. To change the size, use `Scale`.

### Add a hat, a collar or any accessory

1. Drag the **Dog** model into **Workspace** so you can see it.
2. Add a **Part** or a **MeshPart** (or a whole Model made of parts) **inside** the Dog model and place it where it
   should be, for example on top of the head.
3. Drag the Dog model back into **Models** and press Play.

The accessory moves with the closest body part. To choose the body part yourself, select the accessory and
add an **Attribute** named `Bone` (type string) with one of these values:

`Body`, `Head`, `EarL`, `EarR`, `Jaw`, `Tongue`, `Lids`, `Tail`, `LegFL`, `LegFR`, `LegBL`, `LegBR`

Accessories keep their own size and position, and they are anchored and don't collide, like the rest of the dog.

### Use your own sound

1. Find or upload a sound and copy its id (Creator Store or Creator Hub > Development Items > Audio).
2. In **Config**, set `Sound = "rbxassetid://YOUR_ID"` and `SoundStart = 0`.

Roblox only plays sounds your game is allowed to use: your own uploads, sounds of the group that owns the game,
and public sounds from the Creator Store. The default bark is "beagle barking", a public sound from the Creator Store.

### Change the words in the bubble

In **Config**, edit `Texts`, for example `Texts = { "BARK!", "Arf arf!" }`. `Texts = {}` turns the bubble off.

---

## Troubleshooting

**No dog appears**
- Check that **DogPet** is in **ReplicatedStorage** and **DogPetClient** is in **StarterPlayer > StarterPlayerScripts**
  (not in StarterPlayer itself, not in Workspace).
- Open **View > Output**. Messages starting with `[Pets]` tell you what's wrong, for example a misspelled pet name in
  `Config.Pets`.
- With `GiveTo = "Attribute"`, only players with the `Pet` attribute get pets.

**Output says "[Pets] DogPet is missing from ReplicatedStorage"**
- The DogPet folder is missing or was renamed. Put `DogPet.rbxm` in ReplicatedStorage and keep its name.

**No sound**
- The sound isn't available to your game (see "Use your own sound"), or `Volume` is `0`, or `Sound` is `""`.
- In Studio, check that the game's sound isn't muted (the speaker icon at the top).

**My color changes don't show**
- The model must be in **DogPet > Models**, named exactly `Dog`, and the parts must keep their names.

**Too many pets for my server**
- Set `ShowOtherPlayersPets = false`: each player then only animates their own pet.

---

## Good to know

- Each dog is about 32 parts, all moved with a single `workspace:BulkMoveTo` per frame, so it is light even
  with a full server.
- The pets live in a folder called `AnimatedPets` in Workspace, created on each player's device. They are not on the
  server, so server scripts can't see them (that's on purpose).
- The dog finds the ground with a raycast under it, so it walks up ramps and stairs (and on top of terrain
  water). Where there is no floor under it, it stays at its owner's feet height.
- When its owner teleports or respawns far away, the dog jumps straight to its spot next to them.
