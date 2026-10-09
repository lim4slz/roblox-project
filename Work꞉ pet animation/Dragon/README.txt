ANIMATED DRAGON PET
===================

A cartoon dragon that flies after each player: it flaps its wings, lands and
folds them when its owner stands still, takes off again when they move and
breathes a stream of fire with a pop-up bubble and a whoosh.

It works in any Roblox game, R15 or R6, with or without StreamingEnabled. You
drag two files into Studio and that's it: no server script, no RemoteEvents,
nothing to publish. Every player sees everybody's dragon, and since each
player's device animates the pets on its own, there's no network traffic at
all. The dragon is just for looks: its parts are anchored and never collide,
so it can't push players, block doors or be used to climb.


WHAT'S IN THIS FOLDER
---------------------

The folders are named after the places in Studio's Explorer where each file
goes:

  Dragon/
    README.txt                    this file
    ReplicatedStorage/
      DragonPet.rbxm              drag onto ReplicatedStorage
    StarterPlayer/
      StarterPlayerScripts/
        DragonPetClient.rbxm      drag onto StarterPlayerScripts


INSTALL (2 MINUTES)
-------------------

1. Open your game in Roblox Studio. If you don't see the Explorer, open it
   with View > Explorer.
2. Drag ReplicatedStorage/DragonPet.rbxm from your computer and drop it on
   ReplicatedStorage in the Explorer. Another way: right click
   ReplicatedStorage > Insert from File... and pick the file.
3. Drag StarterPlayer/StarterPlayerScripts/DragonPetClient.rbxm and drop it on
   StarterPlayerScripts. It's inside StarterPlayer: click the little arrow
   next to StarterPlayer to see it.
4. Press Play. The dragon shows up next to your character and follows you.

If a file lands in the wrong place (in Workspace, for example), just drag it
in the Explorer to where it belongs. With everything in place, the Explorer
looks like this:

  ReplicatedStorage
    DragonPet              (Folder)
      Config               (ModuleScript)   all the settings
      Models               (Folder)
        Dragon             (Model)          what the dragon looks like
      Modules              (Folder)         the code, no need to touch it
        DragonAnimation    (ModuleScript)
        DragonModel        (ModuleScript)
        DragonPet          (ModuleScript)
        PetFollow          (ModuleScript)
        PetKit             (ModuleScript)
        PetRig             (ModuleScript)
        PetSpawner         (ModuleScript)
  StarterPlayer
    StarterPlayerScripts
      DragonPetClient      (LocalScript)    starts the pets

.rbxm files don't open with a double click. Open Studio first, then drag them
into the Studio window.


WHAT THE DRAGON DOES
--------------------

A green blocky dragon with yellow wings, two horns and little fangs. None of
it is a canned animation: it all reacts to how fast its owner is moving.

- Hovering: it flies about 2 studs off the ground next to its owner, beating
  its wings (a quick downstroke that lifts it, a slower upstroke), its legs
  dangling and its tail swaying. It blinks and looks around.
- Flying: when its owner walks it leans into the flight and flaps a little
  harder. When it falls behind it stretches out and flaps hard, legs tucked
  back and tail straight.
- Landing: when its owner stands still for 6 seconds it lands next to them,
  folds its wings back and sits, looking around. As soon as its owner moves
  it takes off again.
- Fire!: every few seconds it rears its head back to take a breath, then
  throws it forward with the jaw wide open and breathes a stream of flames,
  wings beating hard, with a pop-up bubble and the whoosh of the fire. The
  flames are four glowing Neon blocks that hide inside its head the rest of
  the time.

It flies behind its owner, on the right, a bit higher than the other pets, so
it doesn't bump into them.


SETTINGS
--------

All the settings are in ReplicatedStorage > DragonPet > Config. Double click
it, change what you like and press Play. This is the whole file, with the
default values:

    --[[
        Pet settings. Change anything here and press Play to see it.
        The full guide is in README.txt, next to the files you dragged in.
    ]]

    local Config = {}

    -- Pets every player gets. Pet names: "Dragon"
    Config.Pets = { "Dragon" }

    -- Who gets pets:
    --   "Everyone"   every player gets Config.Pets (default)
    --   "Attribute"  only players whose "Pet" attribute is set by your scripts
    -- On any player the attribute wins over Config.Pets. From a server Script:
    --   player:SetAttribute("Pet", "Dragon")   that player gets the dragon
    --   player:SetAttribute("Pet", "")         no pet
    --   player:SetAttribute("Pet", nil)        back to Config.Pets
    Config.GiveTo = "Everyone"
    Config.Attribute = "Pet"

    -- false = each player only sees their own pets (lighter on big servers).
    Config.ShowOtherPlayersPets = true

    -- DRAGON ---------------------------------------------------------------------
    Config.Dragon = {
        -- 1 = original size, 2 = twice as big, 0.5 = half.
        Scale = 1,
        -- Where it flies next to its owner, in studs: X to the right (negative =
        -- left), Z behind (negative = in front). It flies about 2 studs up.
        Spot = Vector3.new(4.6, 0, 6.6),
        -- The whoosh of its fire. Any sound id your game is allowed to play.
        -- "" = no sound.
        Sound = "rbxassetid://9114439216",
        -- Second of the sound file where the whoosh starts. The default sound
        -- builds up slowly, so it starts 1.3 seconds in. Set it to 0 when you use
        -- your own sound.
        SoundStart = 1.3,
        Volume = 0.6,
        -- Words that pop up over its head when it breathes fire. {} = no bubble.
        Texts = { "ROAR!", "RAWR!", "FWOOSH!", "Rawr!" },
        -- Seconds between the fire breaths it does on its own: { min, max }.
        -- false = it only breathes fire when your scripts call PetSpawner.react.
        Every = { 6, 12 },
    }

    return Config

What each one does:

  Config.Pets
      The pets every player gets.

  Config.GiveTo
      "Everyone" gives Config.Pets to every player. "Attribute" gives pets
      only to the players you pick (see "Only some players get the dragon"
      below).

  Config.Attribute
      Name of the player attribute that picks a player's pets. "Pet" unless
      you change it.

  Config.ShowOtherPlayersPets
      false = each player only sees their own pet. Handy on big servers or
      for slow devices.

  Scale
      Size of the dragon: 2 is twice as big, 0.5 is half. Its steps,
      speed and bubble grow with it.

  Spot
      Where it goes next to its owner, in studs. X is to the right (negative
      goes to the left), Z is behind (negative goes in front).

  Sound
      Sound id of the whoosh. "" means no sound.

  SoundStart
      Second of the sound file where the whoosh starts, for sounds
      that begin with some silence.

  Volume
      How loud the whoosh is, from 0 to 10.

  Texts
      Words that pop up over its head when it breathes fire. One is picked at
      random each time. {} means no bubble.

  Every
      { min, max }: how many seconds between the times it breathes fire on its
      own. false means it only does it when your own scripts ask (see below).


ONLY SOME PLAYERS GET THE DRAGON (GAME PASS, VIP, ADMINS...)
------------------------------------------------------------

1. In Config, set Config.GiveTo = "Attribute".
2. Add a Script (a normal server Script) to ServerScriptService, paste this
   and put your game pass id in it:

    local MarketplaceService = game:GetService("MarketplaceService")
    local Players = game:GetService("Players")

    local GAME_PASS_ID = 123456789 -- your game pass id

    local function check(player)
        local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, GAME_PASS_ID)
        if ok and owns then
            player:SetAttribute("Pet", "Dragon")
        end
    end

    Players.PlayerAdded:Connect(check)
    for _, player in Players:GetPlayers() do
        check(player)
    end

    -- Bought it while playing: give it right away.
    MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
        if purchased and passId == GAME_PASS_ID then
            player:SetAttribute("Pet", "Dragon")
        end
    end)

The same idea works for anything else: a group rank, a badge, a level, a list
of admins. Whenever a server script sets the Pet attribute on a player, that
player's pets change on every screen right away.

To hide or bring back someone's pet (from a button or a chat command, say),
from a server Script:

    player:SetAttribute("Pet", "")      -- hide this player's pet
    player:SetAttribute("Pet", nil)     -- back to the pets in Config


MAKE THE DRAGON BREATHE FIRE FROM YOUR OWN SCRIPTS
--------------------------------------------------

From any LocalScript:

    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Players = game:GetService("Players")

    local PetSpawner = require(ReplicatedStorage:WaitForChild("DragonPet"):WaitForChild("Modules"):WaitForChild("PetSpawner"))

    -- the local player's pets breathe fire right now
    PetSpawner.react(Players.LocalPlayer)

    -- only the dragon, if the player has other pets too
    PetSpawner.react(Players.LocalPlayer, "Dragon")

PetSpawner.react(player) works for any player, not just the local one, and
only on the device that calls it. PetSpawner.getPets(player) gives you that
player's pets; each one has a model (the Model in workspace.AnimatedPets). Set
Every = false in Config if it should only breathe fire when you say so.


BIGGER OR SMALLER
-----------------

In Config, change Scale inside Config.Dragon: 2 is twice as big, 0.5 is
half. Use Scale for this, resizing the model in Models won't do it.


COLORS AND MATERIALS
--------------------

1. Open ReplicatedStorage > DragonPet > Models > Dragon.
2. Click a part (Body, for example) and change Color, Material,
   Transparency or Reflectance in the Properties window.
3. Press Play.

It's easier when you can see it: drag the Dragon model into Workspace, edit
it, then drag it back into Models. Keep the name Dragon and the part names.

Anything you put inside a part comes along too: a Decal, a Texture, Sparkles,
Fire, a ParticleEmitter, a PointLight... Drop a PointLight into Body
and the dragon glows.

The size and position of the original parts come from the animation, so moving
or resizing them in the model does nothing. For the size, use Scale.


HATS, COLLARS AND OTHER ACCESSORIES
-----------------------------------

1. Drag the Dragon model into Workspace so you can see it.
2. Put a Part or a MeshPart (or a whole Model made of parts) inside the
   Dragon model, where it should go. On top of the head, for example.
3. Drag the model back into Models and press Play.

The accessory moves with the closest body part. To pick the body part
yourself, select the accessory and add an Attribute called Bone (type string)
with one of these:

  Body, Head, Jaw, WingR, WingL, Tail1, Tail2, Tail3, LegFR, LegFL, LegBR,
  LegBL

Accessories keep their own size and position, and like the rest of the
dragon they're anchored and don't collide.


YOUR OWN SOUND
--------------

1. Find or upload a sound and copy its id (Creator Store, or Creator Hub >
   Development Items > Audio).
2. In Config, set Sound = "rbxassetid://YOUR_ID" and SoundStart = 0.

Roblox only plays sounds your game is allowed to use: your own uploads, sounds
from the group that owns the game, and public sounds from the Creator Store.
The default whoosh is "Fire Whoosh 4" by Pro Sound Effects, licensed by Roblox
for every experience. It builds up slowly, that's why SoundStart is 1.3 by
default.


THE WORDS IN THE BUBBLE
-----------------------

Edit Texts in Config, for example Texts = { "BURN!", "Hot hot hot!" }.
Texts = {} turns the bubble off.


TROUBLESHOOTING
---------------

No dragon shows up
  - Check that DragonPet is in ReplicatedStorage and DragonPetClient is in
    StarterPlayer > StarterPlayerScripts (not in StarterPlayer itself, not in
    Workspace).
  - Open View > Output. Messages starting with [Pets] tell you what's wrong,
    like a misspelled name in Config.Pets.
  - With GiveTo = "Attribute", only players with the Pet attribute get pets.

The Output says "[Pets] DragonPet is missing from ReplicatedStorage"
  - The DragonPet folder isn't there or was renamed. Drag DragonPet.rbxm into
    ReplicatedStorage again and keep its name.

No sound
  - The sound isn't available to your game (see "Your own sound"), or Volume
    is 0, or Sound is "".
  - In Studio, make sure the game sound isn't muted (the speaker icon at the
    top).

My color changes don't show
  - The model has to be in DragonPet > Models, named exactly Dragon, and
    the parts have to keep their names.

Too many pets for my server
  - Set ShowOtherPlayersPets = false. Each player then only animates their
    own pet.


GOOD TO KNOW
------------

- The dragon is 48 parts, all moved with a single
  workspace:BulkMoveTo per frame, so it's light even with a full server.
- The pets live in a folder called AnimatedPets in Workspace, made on each
  player's device. They aren't on the server, so server scripts can't see them
  (on purpose).
- The dragon finds the ground with a raycast, so it goes up ramps and
  stairs (and on top of terrain water). Where there's no floor under it, it
  stays at its owner's feet height.
- When its owner teleports or respawns far away, the dragon jumps straight
  to its spot next to them.
