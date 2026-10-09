# Animated Pets: All in One

Every animated pet in one install: `Dog`, `Snake`. By default every player gets all of them; the Config picks
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
All in One/
├── README.md                     you are here
├── ReplicatedStorage/
│   └── AllPets.rbxm              drag onto ReplicatedStorage
└── StarterPlayer/
    └── StarterPlayerScripts/
        └── AllPetsClient.rbxm    drag onto StarterPlayer > StarterPlayerScripts
```

---

## Install (2 minutes)

1. Open your game in Roblox Studio. If you don't see the Explorer, open it with **View > Explorer**.
2. Drag **`ReplicatedStorage/AllPets.rbxm`** from your computer and drop it on **ReplicatedStorage** in the Explorer.
   - Other way: right click **ReplicatedStorage** > **Insert from File...** and pick the file.
3. Drag **`StarterPlayer/StarterPlayerScripts/AllPetsClient.rbxm`** and drop it on **StarterPlayerScripts**
   (it's inside **StarterPlayer**, click the arrow next to StarterPlayer to see it).
4. Press **Play**. The pets appear next to your character and follow you around.

If a file lands in the wrong place (for example in Workspace), just drag it in the Explorer to the right one.
When everything is in place, your Explorer looks like this:

```
ReplicatedStorage
└── AllPets                 (Folder)
    ├── Config              (ModuleScript)  all the settings
    ├── Models              (Folder)        the look of each pet
    │   ├── Dog             (Model)
    │   └── Snake           (Model)
    └── Modules             (Folder)        the code, you don't need to touch it
        ├── DogAnimation    (ModuleScript)
        ├── DogModel        (ModuleScript)
        ├── DogPet          (ModuleScript)
        ├── PetFollow       (ModuleScript)
        ├── PetKit          (ModuleScript)
        ├── PetRig          (ModuleScript)
        ├── PetSpawner      (ModuleScript)
        ├── SnakeAnimation  (ModuleScript)
        ├── SnakeModel      (ModuleScript)
        └── SnakePet        (ModuleScript)
StarterPlayer
└── StarterPlayerScripts
    └── AllPetsClient       (LocalScript)   starts the pets
```

> `.rbxm` files don't open with a double click. Open Roblox Studio first, then drag them into the Studio window.

---

## The pets

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

## What the snake does

A long blocky snake (about 14 studs) in two shades of green, with a forked tongue. Everything is procedural:

- **Slither**: the head weaves left and right as it moves, and every body segment slides through the exact
  S-shaped path the head took, like a real snake. Over stairs and slopes the body follows the ground the head
  went over, one segment at a time.
- **Dash**: when it falls behind it moves faster with wider curves and the head kept low.
- **Idle**: the front of the body rises a little, the head sways and turns to look at its owner, and a slow
  ripple runs down the neck.
- **Tongue**: it flicks its forked tongue in and out every second or two (sometimes twice in a row).
- **HISS!**: every few seconds it rears up high, opens its mouth to show its fangs, frowns, shakes its head
  and goes wild with the tongue, with a **HSSS!** bubble and a hiss sound.

Its head goes a little behind its owner, on the left; the body trails behind.

Each pet walks on its own spot next to its owner, so they don't bump into each other (change it with `Spot`).

---

## Settings

Open **ReplicatedStorage > AllPets > Config** (double click it). Change the values, save, press Play.
This is the whole file with the default values:

```lua
--[[
	Pet settings. Change anything here and press Play to see it.
	The full guide is in README.md, next to the files you dragged in.
]]

local Config = {}

-- Pets every player gets. Pet names: "Dog", "Snake"
Config.Pets = { "Dog", "Snake" }

-- Who gets pets:
--   "Everyone"   every player gets Config.Pets (default)
--   "Attribute"  only players whose "Pet" attribute is set by your scripts
-- On any player the attribute wins over Config.Pets. From a server Script:
--   player:SetAttribute("Pet", "Dog")         that player gets the dog
--   player:SetAttribute("Pet", "Dog,Snake")   several pets, comma separated
--   player:SetAttribute("Pet", "")            no pet
--   player:SetAttribute("Pet", nil)           back to Config.Pets
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

-- SNAKE ----------------------------------------------------------------------
Config.Snake = {
	-- 1 = original size, 2 = twice as big, 0.5 = half.
	Scale = 1,
	-- Where its head goes next to its owner, in studs: X to the right
	-- (negative = left), Z behind (negative = in front). The body trails behind.
	Spot = Vector3.new(-2.6, 0, 3.4),
	-- The hiss. Any sound id your game is allowed to play. "" = no sound.
	Sound = "rbxassetid://9119302862",
	-- Second of the sound file where the hiss starts. The default sound has
	-- 2.8 seconds of silence first. Set it to 0 when you use your own sound.
	SoundStart = 2.8,
	Volume = 0.9,
	-- Words that pop up over its head when it hisses. {} = no bubble.
	Texts = { "HSSS!", "Hssss!", "HISSS!", "Sss!" },
	-- Seconds between the hisses it does on its own: { min, max }.
	-- false = it only hisses when your scripts call PetSpawner.react.
	Every = { 5, 10 },
}

return Config
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

local PetSpawner = require(ReplicatedStorage:WaitForChild("AllPets"):WaitForChild("Modules"):WaitForChild("PetSpawner"))

PetSpawner.react(Players.LocalPlayer)          -- all of the local player's pets react now
PetSpawner.react(Players.LocalPlayer, "Snake") -- only the snake hisses
```

The dog barks and the snake hisses. `PetSpawner.react(player)` works for any player, not only the local one,
and only on the device that calls it. `PetSpawner.getPets(player)` returns that player's pets; each one has a
`model` (the Model in `workspace.AnimatedPets`). Set `Every = false` on a pet if it should only react when you say so.

### Make a pet bigger or smaller

In **Config**, change `Scale` inside that pet's settings (`Config.Dog`, `Config.Snake`...): `2` is twice as big,
`0.5` is half. Don't resize the models in **Models** for this, use `Scale`.

### Change colors and materials

1. Open **ReplicatedStorage > AllPets > Models** and pick a pet.
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

- **Dog**: `Body`, `Head`, `EarL`, `EarR`, `Jaw`, `Tongue`, `Lids`, `Tail`, `LegFL`, `LegFR`, `LegBL`, `LegBR`
- **Snake**: `Head`, `Body1`, `Body2`, `Body3`, `Body4`, `Body5`, `Body6`, `Body7`, `Body8`, `Body9`, `Body10`, `Tongue`, `Mouth`, `BrowL`, `BrowR`

Accessories keep their own size and position, and they are anchored and don't collide, like the rest of the pet.

### Use your own sounds

1. Find or upload a sound and copy its id (Creator Store or Creator Hub > Development Items > Audio).
2. In **Config**, in that pet's settings, set `Sound = "rbxassetid://YOUR_ID"` and `SoundStart = 0`.

Roblox only plays sounds your game is allowed to use: your own uploads, sounds of the group that owns the game, and
public sounds from the Creator Store. About the default sounds:

- Dog: The default bark is "beagle barking", a public sound from the Creator Store.
- Snake: The default hiss is "Snake Hiss 1 (SFX)" by Pro Sound Effects, licensed by Roblox for every experience. It has 2.8 seconds of silence at the start, that's why the default `SoundStart` is 2.8.

### Change the words in the bubbles

In **Config**, edit `Texts` in that pet's settings. `Texts = {}` turns its bubble off.

---

## Troubleshooting

**No pets appear**
- Check that **AllPets** is in **ReplicatedStorage** and **AllPetsClient** is in **StarterPlayer > StarterPlayerScripts**
  (not in StarterPlayer itself, not in Workspace).
- Open **View > Output**. Messages starting with `[Pets]` tell you what's wrong, for example a misspelled pet name in
  `Config.Pets` (the names are `Dog`, `Snake`, with capital letters).
- With `GiveTo = "Attribute"`, only players with the `Pet` attribute get pets.

**Output says "[Pets] AllPets is missing from ReplicatedStorage"**
- The AllPets folder is missing or was renamed. Put `AllPets.rbxm` in ReplicatedStorage and keep its name.

**No sound**
- The sound isn't available to your game (see "Use your own sounds"), or `Volume` is `0`, or `Sound` is `""`.
- In Studio, check that the game's sound isn't muted (the speaker icon at the top).

**My color changes don't show**
- The model must be in **AllPets > Models**, keep its name (`Dog`, `Snake`...), and the parts must keep their names.

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
