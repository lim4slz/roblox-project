ANIMATED SNAKE PET
==================

A long cartoon snake that slithers after each player: it weaves through an
S-shaped path, climbs stairs segment by segment, flicks its forked tongue and
rears up to "HISS!" with a pop-up bubble.

It works in any Roblox game, R15 or R6, with or without StreamingEnabled. You
drag two files into Studio and that's it: no server script, no RemoteEvents,
nothing to publish. Every player sees everybody's snake, and since each
player's device animates the pets on its own, there's no network traffic at
all. The snake is just for looks: its parts are anchored and never collide,
so it can't push players, block doors or be used to climb.


WHAT'S IN THIS FOLDER
---------------------

The folders are named after the places in Studio's Explorer where each file
goes:

  Snake/
    README.txt                   this file
    ReplicatedStorage/
      SnakePet.rbxm              drag onto ReplicatedStorage
    StarterPlayer/
      StarterPlayerScripts/
        SnakePetClient.rbxm      drag onto StarterPlayerScripts


INSTALL (2 MINUTES)
-------------------

1. Open your game in Roblox Studio. If you don't see the Explorer, open it
   with View > Explorer.
2. Drag ReplicatedStorage/SnakePet.rbxm from your computer and drop it on
   ReplicatedStorage in the Explorer. Another way: right click
   ReplicatedStorage > Insert from File... and pick the file.
3. Drag StarterPlayer/StarterPlayerScripts/SnakePetClient.rbxm and drop it on
   StarterPlayerScripts. It's inside StarterPlayer: click the little arrow
   next to StarterPlayer to see it.
4. Press Play. The snake shows up next to your character and follows you.

If a file lands in the wrong place (in Workspace, for example), just drag it
in the Explorer to where it belongs. With everything in place, the Explorer
looks like this:

  ReplicatedStorage
    SnakePet               (Folder)
      Config               (ModuleScript)   all the settings
      Models               (Folder)
        Snake              (Model)          what the snake looks like
      Modules              (Folder)         the code, no need to touch it
        PetFollow          (ModuleScript)
        PetKit             (ModuleScript)
        PetRig             (ModuleScript)
        PetSpawner         (ModuleScript)
        SnakeAnimation     (ModuleScript)
        SnakeModel         (ModuleScript)
        SnakePet           (ModuleScript)
  StarterPlayer
    StarterPlayerScripts
      SnakePetClient       (LocalScript)    starts the pets

.rbxm files don't open with a double click. Open Studio first, then drag them
into the Studio window.


WHAT THE SNAKE DOES
-------------------

A long blocky snake (about 14 studs) in two shades of green, with a forked
tongue. None of it is a canned animation:

- Slithering: the head weaves left and right as it goes, and every piece of
  the body slides through the exact S-shaped path the head took, like a real
  snake. On stairs and slopes the body follows the ground the head went over,
  one piece at a time.
- Hurrying: when it falls behind it goes faster, with wider curves and the
  head kept low.
- Standing: the front of the body rises a little, the head sways and turns to
  look at its owner, and a slow ripple runs down the neck.
- The tongue: it flicks its forked tongue in and out every second or two,
  sometimes twice in a row.
- HISS!: every few seconds it rears up high, opens its mouth to show its fangs,
  frowns, shakes its head and goes wild with the tongue, with a HSSS! bubble
  and a hiss.

Its head stays a little behind its owner, on the left, and the body trails
behind.


SETTINGS
--------

All the settings are in ReplicatedStorage > SnakePet > Config. Double click
it, change what you like and press Play. This is the whole file, with the
default values:

    --[[
        Pet settings. Change anything here and press Play to see it.
        The full guide is in README.md, next to the files you dragged in.
    ]]

    local Config = {}

    -- Pets every player gets. Pet names: "Snake"
    Config.Pets = { "Snake" }

    -- Who gets pets:
    --   "Everyone"   every player gets Config.Pets (default)
    --   "Attribute"  only players whose "Pet" attribute is set by your scripts
    -- On any player the attribute wins over Config.Pets. From a server Script:
    --   player:SetAttribute("Pet", "Snake")   that player gets the snake
    --   player:SetAttribute("Pet", "")        no pet
    --   player:SetAttribute("Pet", nil)       back to Config.Pets
    Config.GiveTo = "Everyone"
    Config.Attribute = "Pet"

    -- false = each player only sees their own pets (lighter on big servers).
    Config.ShowOtherPlayersPets = true

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

What each one does:

  Config.Pets
      The pets every player gets.

  Config.GiveTo
      "Everyone" gives Config.Pets to every player. "Attribute" gives pets
      only to the players you pick (see "Only some players get the snake"
      below).

  Config.Attribute
      Name of the player attribute that picks a player's pets. "Pet" unless
      you change it.

  Config.ShowOtherPlayersPets
      false = each player only sees their own pet. Handy on big servers or
      for slow devices.

  Scale
      Size of the snake: 2 is twice as big, 0.5 is half. Its steps,
      speed and bubble grow with it.

  Spot
      Where it walks next to its owner, in studs. X is to the right (negative
      goes to the left), Z is behind (negative goes in front).

  Sound
      Sound id of the hiss. "" means no sound.

  SoundStart
      Second of the sound file where the hiss starts, for sounds
      that begin with some silence.

  Volume
      How loud the hiss is, from 0 to 10.

  Texts
      Words that pop up over its head when it hisses. One is picked at
      random each time. {} means no bubble.

  Every
      { min, max }: how many seconds between the times it hisses on its
      own. false means it only does it when your own scripts ask (see below).


ONLY SOME PLAYERS GET THE SNAKE (GAME PASS, VIP, ADMINS...)
-----------------------------------------------------------

1. In Config, set Config.GiveTo = "Attribute".
2. Add a Script (a normal server Script) to ServerScriptService, paste this
   and put your game pass id in it:

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

    -- Bought it while playing: give it right away.
    MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
        if purchased and passId == GAME_PASS_ID then
            player:SetAttribute("Pet", "Snake")
        end
    end)

The same idea works for anything else: a group rank, a badge, a level, a list
of admins. Whenever a server script sets the Pet attribute on a player, that
player's pets change on every screen right away.

To hide or bring back someone's pet (from a button or a chat command, say),
from a server Script:

    player:SetAttribute("Pet", "")      -- hide this player's pet
    player:SetAttribute("Pet", nil)     -- back to the pets in Config


MAKE THE SNAKE HISS FROM YOUR OWN SCRIPTS
-----------------------------------------

From any LocalScript:

    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Players = game:GetService("Players")

    local PetSpawner = require(ReplicatedStorage:WaitForChild("SnakePet"):WaitForChild("Modules"):WaitForChild("PetSpawner"))

    -- the local player's pets hiss right now
    PetSpawner.react(Players.LocalPlayer)

    -- only the snake, if the player has other pets too
    PetSpawner.react(Players.LocalPlayer, "Snake")

PetSpawner.react(player) works for any player, not just the local one, and
only on the device that calls it. PetSpawner.getPets(player) gives you that
player's pets; each one has a model (the Model in workspace.AnimatedPets). Set
Every = false in Config if it should only hiss when you say so.


BIGGER OR SMALLER
-----------------

In Config, change Scale inside Config.Snake: 2 is twice as big, 0.5 is
half. Use Scale for this, resizing the model in Models won't do it.


COLORS AND MATERIALS
--------------------

1. Open ReplicatedStorage > SnakePet > Models > Snake.
2. Click a part (Body3, for example) and change Color, Material,
   Transparency or Reflectance in the Properties window.
3. Press Play.

It's easier when you can see it: drag the Snake model into Workspace, edit
it, then drag it back into Models. Keep the name Snake and the part names.

Anything you put inside a part comes along too: a Decal, a Texture, Sparkles,
Fire, a ParticleEmitter, a PointLight... Drop a PointLight into Body3
and the snake glows.

The size and position of the original parts come from the animation, so moving
or resizing them in the model does nothing. For the size, use Scale.


HATS, COLLARS AND OTHER ACCESSORIES
-----------------------------------

1. Drag the Snake model into Workspace so you can see it.
2. Put a Part or a MeshPart (or a whole Model made of parts) inside the
   Snake model, where it should go. On top of the head, for example.
3. Drag the model back into Models and press Play.

The accessory moves with the closest body part. To pick the body part
yourself, select the accessory and add an Attribute called Bone (type string)
with one of these:

  Head, Body1, Body2, Body3, Body4, Body5, Body6, Body7, Body8, Body9, Body10,
  Tongue, Mouth, BrowL, BrowR

Accessories keep their own size and position, and like the rest of the
snake they're anchored and don't collide.


YOUR OWN SOUND
--------------

1. Find or upload a sound and copy its id (Creator Store, or Creator Hub >
   Development Items > Audio).
2. In Config, set Sound = "rbxassetid://YOUR_ID" and SoundStart = 0.

Roblox only plays sounds your game is allowed to use: your own uploads, sounds
from the group that owns the game, and public sounds from the Creator Store.
The default hiss is "Snake Hiss 1 (SFX)" by Pro Sound Effects, licensed by
Roblox for every experience. It has 2.8 seconds of silence at the start,
that's why SoundStart is 2.8 by default.


THE WORDS IN THE BUBBLE
-----------------------

Edit Texts in Config, for example Texts = { "SSSS!", "Hiss!" }.
Texts = {} turns the bubble off.


TROUBLESHOOTING
---------------

No snake shows up
  - Check that SnakePet is in ReplicatedStorage and SnakePetClient is in
    StarterPlayer > StarterPlayerScripts (not in StarterPlayer itself, not in
    Workspace).
  - Open View > Output. Messages starting with [Pets] tell you what's wrong,
    like a misspelled name in Config.Pets.
  - With GiveTo = "Attribute", only players with the Pet attribute get pets.

The Output says "[Pets] SnakePet is missing from ReplicatedStorage"
  - The SnakePet folder isn't there or was renamed. Drag SnakePet.rbxm into
    ReplicatedStorage again and keep its name.

No sound
  - The sound isn't available to your game (see "Your own sound"), or Volume
    is 0, or Sound is "".
  - In Studio, make sure the game sound isn't muted (the speaker icon at the
    top).

My color changes don't show
  - The model has to be in SnakePet > Models, named exactly Snake, and
    the parts have to keep their names.

Too many pets for my server
  - Set ShowOtherPlayersPets = false. Each player then only animates their
    own pet.


GOOD TO KNOW
------------

- The snake is 25 parts, all moved with a single
  workspace:BulkMoveTo per frame, so it's light even with a full server.
- The pets live in a folder called AnimatedPets in Workspace, made on each
  player's device. They aren't on the server, so server scripts can't see them
  (on purpose).
- The snake finds the ground with a raycast, so it walks up ramps and
  stairs (and on top of terrain water). Where there's no floor under it, it
  stays at its owner's feet height.
- When its owner teleports or respawns far away, the snake jumps straight
  to its spot next to them.
