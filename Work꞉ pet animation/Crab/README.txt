ANIMATED CRAB PET
=================

A cartoon crab that scuttles sideways after each player: its eyes look around
on their stalks, it blinks, pinches the air and throws its claws up to "SNAP!"
with a pop-up bubble and claw clicks.

It works in any Roblox game, R15 or R6, with or without StreamingEnabled. You
drag two files into Studio and that's it: no server script, no RemoteEvents,
nothing to publish. Every player sees everybody's crab, and since each
player's device animates the pets on its own, there's no network traffic at
all. The crab is just for looks: its parts are anchored and never collide,
so it can't push players, block doors or be used to climb.


WHAT'S IN THIS FOLDER
---------------------

The folders are named after the places in Studio's Explorer where each file
goes:

  Crab/
    README.txt                   this file
    ReplicatedStorage/
      CrabPet.rbxm               drag onto ReplicatedStorage
    StarterPlayer/
      StarterPlayerScripts/
        CrabPetClient.rbxm       drag onto StarterPlayerScripts


INSTALL (2 MINUTES)
-------------------

1. Open your game in Roblox Studio. If you don't see the Explorer, open it
   with View > Explorer.
2. Drag ReplicatedStorage/CrabPet.rbxm from your computer and drop it on
   ReplicatedStorage in the Explorer. Another way: right click
   ReplicatedStorage > Insert from File... and pick the file.
3. Drag StarterPlayer/StarterPlayerScripts/CrabPetClient.rbxm and drop it on
   StarterPlayerScripts. It's inside StarterPlayer: click the little arrow
   next to StarterPlayer to see it.
4. Press Play. The crab shows up next to your character and follows you.

If a file lands in the wrong place (in Workspace, for example), just drag it
in the Explorer to where it belongs. With everything in place, the Explorer
looks like this:

  ReplicatedStorage
    CrabPet                (Folder)
      Config               (ModuleScript)   all the settings
      Models               (Folder)
        Crab               (Model)          what the crab looks like
      Modules              (Folder)         the code, no need to touch it
        CrabAnimation      (ModuleScript)
        CrabModel          (ModuleScript)
        CrabPet            (ModuleScript)
        PetFollow          (ModuleScript)
        PetKit             (ModuleScript)
        PetRig             (ModuleScript)
        PetSpawner         (ModuleScript)
  StarterPlayer
    StarterPlayerScripts
      CrabPetClient        (LocalScript)    starts the pets

.rbxm files don't open with a double click. Open Studio first, then drag them
into the Studio window.


WHAT THE CRAB DOES
------------------

A red blocky crab with two big claws and its eyes on stalks. None of it is a
canned animation: it all reacts to how fast its owner is moving.

- Standing: it breathes, and each eye stalk looks around on its own, so now
  and then it looks two ways at once. It blinks (sometimes with one eye only),
  opens and closes a pincer and taps a foot.
- Walking: like a real crab, it turns its side to where it's going and
  scuttles sideways on quick little steps, the shell rocking, claws up and
  both eyes looking ahead. Each time it sets off it picks which side goes
  first.
- Hurrying: when it falls behind, the steps get faster and the shell sits
  lower.
- SNAP!: every few seconds it throws both claws up in the air and snaps them
  three times, with a little hop on each snap, its eyes popping up and its
  mouth open. A bubble pops up with the clicks of a crab claw, in time with
  the snaps.

It scuttles along on its owner's left, a little behind, and turns to face
ahead again when its owner stops.


SETTINGS
--------

All the settings are in ReplicatedStorage > CrabPet > Config. Double click
it, change what you like and press Play. This is the whole file, with the
default values:

    --[[
        Pet settings. Change anything here and press Play to see it.
        The full guide is in README.txt, next to the files you dragged in.
    ]]

    local Config = {}

    -- Pets every player gets. Pet names: "Crab"
    Config.Pets = { "Crab" }

    -- Who gets pets:
    --   "Everyone"   every player gets Config.Pets (default)
    --   "Attribute"  only players whose "Pet" attribute is set by your scripts
    -- On any player the attribute wins over Config.Pets. From a server Script:
    --   player:SetAttribute("Pet", "Crab")   that player gets the crab
    --   player:SetAttribute("Pet", "")       no pet
    --   player:SetAttribute("Pet", nil)      back to Config.Pets
    Config.GiveTo = "Everyone"
    Config.Attribute = "Pet"

    -- false = each player only sees their own pets (lighter on big servers).
    Config.ShowOtherPlayersPets = true

    -- CRAB -----------------------------------------------------------------------
    Config.Crab = {
        -- 1 = original size, 2 = twice as big, 0.5 = half.
        Scale = 1,
        -- Where it scuttles next to its owner, in studs: X to the right
        -- (negative = left), Z behind (negative = in front).
        Spot = Vector3.new(-5.8, 0, 0.4),
        -- The claw clicks of a SNAP. Any sound id your game is allowed to play.
        -- "" = no sound.
        Sound = "rbxassetid://9113957844",
        SoundStart = 0, -- second of the sound file where the first click is
        Volume = 0.8,
        -- Words that pop up over its head when it snaps. {} = no bubble.
        Texts = { "SNAP!", "Snip snap!", "CLACK!", "Snap snap!" },
        -- Seconds between the SNAPs it does on its own: { min, max }.
        -- false = it only snaps when your scripts call PetSpawner.react.
        Every = { 4, 8 },
    }

    return Config

What each one does:

  Config.Pets
      The pets every player gets.

  Config.GiveTo
      "Everyone" gives Config.Pets to every player. "Attribute" gives pets
      only to the players you pick (see "Only some players get the crab"
      below).

  Config.Attribute
      Name of the player attribute that picks a player's pets. "Pet" unless
      you change it.

  Config.ShowOtherPlayersPets
      false = each player only sees their own pet. Handy on big servers or
      for slow devices.

  Scale
      Size of the crab: 2 is twice as big, 0.5 is half. Its steps,
      speed and bubble grow with it.

  Spot
      Where it goes next to its owner, in studs. X is to the right (negative
      goes to the left), Z is behind (negative goes in front).

  Sound
      Sound id of the snap. "" means no sound.

  SoundStart
      Second of the sound file where the snap starts, for sounds
      that begin with some silence.

  Volume
      How loud the snap is, from 0 to 10.

  Texts
      Words that pop up over its head when it snaps. One is picked at
      random each time. {} means no bubble.

  Every
      { min, max }: how many seconds between the times it snaps on its
      own. false means it only does it when your own scripts ask (see below).


ONLY SOME PLAYERS GET THE CRAB (GAME PASS, VIP, ADMINS...)
----------------------------------------------------------

1. In Config, set Config.GiveTo = "Attribute".
2. Add a Script (a normal server Script) to ServerScriptService, paste this
   and put your game pass id in it:

    local MarketplaceService = game:GetService("MarketplaceService")
    local Players = game:GetService("Players")

    local GAME_PASS_ID = 123456789 -- your game pass id

    local function check(player)
        local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, GAME_PASS_ID)
        if ok and owns then
            player:SetAttribute("Pet", "Crab")
        end
    end

    Players.PlayerAdded:Connect(check)
    for _, player in Players:GetPlayers() do
        check(player)
    end

    -- Bought it while playing: give it right away.
    MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
        if purchased and passId == GAME_PASS_ID then
            player:SetAttribute("Pet", "Crab")
        end
    end)

The same idea works for anything else: a group rank, a badge, a level, a list
of admins. Whenever a server script sets the Pet attribute on a player, that
player's pets change on every screen right away.

To hide or bring back someone's pet (from a button or a chat command, say),
from a server Script:

    player:SetAttribute("Pet", "")      -- hide this player's pet
    player:SetAttribute("Pet", nil)     -- back to the pets in Config


MAKE THE CRAB SNAP FROM YOUR OWN SCRIPTS
----------------------------------------

From any LocalScript:

    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Players = game:GetService("Players")

    local PetSpawner = require(ReplicatedStorage:WaitForChild("CrabPet"):WaitForChild("Modules"):WaitForChild("PetSpawner"))

    -- the local player's pets snap right now
    PetSpawner.react(Players.LocalPlayer)

    -- only the crab, if the player has other pets too
    PetSpawner.react(Players.LocalPlayer, "Crab")

PetSpawner.react(player) works for any player, not just the local one, and
only on the device that calls it. PetSpawner.getPets(player) gives you that
player's pets; each one has a model (the Model in workspace.AnimatedPets). Set
Every = false in Config if it should only snap when you say so.


BIGGER OR SMALLER
-----------------

In Config, change Scale inside Config.Crab: 2 is twice as big, 0.5 is
half. Use Scale for this, resizing the model in Models won't do it.


COLORS AND MATERIALS
--------------------

1. Open ReplicatedStorage > CrabPet > Models > Crab.
2. Click a part (Shell, for example) and change Color, Material,
   Transparency or Reflectance in the Properties window.
3. Press Play.

It's easier when you can see it: drag the Crab model into Workspace, edit
it, then drag it back into Models. Keep the name Crab and the part names.

Anything you put inside a part comes along too: a Decal, a Texture, Sparkles,
Fire, a ParticleEmitter, a PointLight... Drop a PointLight into Shell
and the crab glows.

The size and position of the original parts come from the animation, so moving
or resizing them in the model does nothing. For the size, use Scale.


HATS, COLLARS AND OTHER ACCESSORIES
-----------------------------------

1. Drag the Crab model into Workspace so you can see it.
2. Put a Part or a MeshPart (or a whole Model made of parts) inside the
   Crab model, where it should go. On top of the head, for example.
3. Drag the model back into Models and press Play.

The accessory moves with the closest body part. To pick the body part
yourself, select the accessory and add an Attribute called Bone (type string)
with one of these:

  Root, Body, StalkL, StalkR, ArmL, ForearmL, PincerL, FingerLIn, FingerLOut,
  ArmR, ForearmR, PincerR, FingerRIn, FingerROut, LegFL, ShinFL, LegFR,
  ShinFR, LegBL, ShinBL, LegBR, ShinBR

Accessories keep their own size and position, and like the rest of the
crab they're anchored and don't collide.


YOUR OWN SOUND
--------------

1. Find or upload a sound and copy its id (Creator Store, or Creator Hub >
   Development Items > Audio).
2. In Config, set Sound = "rbxassetid://YOUR_ID" and SoundStart = 0.

Roblox only plays sounds your game is allowed to use: your own uploads, sounds
from the group that owns the game, and public sounds from the Creator Store.
The default snap is "Crab Claw Smaller Snaps Plasticky 3" by Pro Sound
Effects, licensed by Roblox for every experience. Its three clicks match the
three snaps of the animation, so with a sound of your own the clicks may not
line up with the claws.


THE WORDS IN THE BUBBLE
-----------------------

Edit Texts in Config, for example Texts = { "PINCH!", "Clickety clack!" }.
Texts = {} turns the bubble off.


TROUBLESHOOTING
---------------

No crab shows up
  - Check that CrabPet is in ReplicatedStorage and CrabPetClient is in
    StarterPlayer > StarterPlayerScripts (not in StarterPlayer itself, not in
    Workspace).
  - Open View > Output. Messages starting with [Pets] tell you what's wrong,
    like a misspelled name in Config.Pets.
  - With GiveTo = "Attribute", only players with the Pet attribute get pets.

The Output says "[Pets] CrabPet is missing from ReplicatedStorage"
  - The CrabPet folder isn't there or was renamed. Drag CrabPet.rbxm into
    ReplicatedStorage again and keep its name.

No sound
  - The sound isn't available to your game (see "Your own sound"), or Volume
    is 0, or Sound is "".
  - In Studio, make sure the game sound isn't muted (the speaker icon at the
    top).

My color changes don't show
  - The model has to be in CrabPet > Models, named exactly Crab, and
    the parts have to keep their names.

Too many pets for my server
  - Set ShowOtherPlayersPets = false. Each player then only animates their
    own pet.


GOOD TO KNOW
------------

- The crab is 31 parts, all moved with a single
  workspace:BulkMoveTo per frame, so it's light even with a full server.
- The pets live in a folder called AnimatedPets in Workspace, made on each
  player's device. They aren't on the server, so server scripts can't see them
  (on purpose).
- The crab finds the ground with a raycast, so it goes up ramps and
  stairs (and on top of terrain water). Where there's no floor under it, it
  stays at its owner's feet height.
- When its owner teleports or respawns far away, the crab jumps straight
  to its spot next to them.
