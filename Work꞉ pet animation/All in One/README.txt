ANIMATED PETS: ALL IN ONE
=========================

Every animated pet in one install: Dog and Snake. Out of the box every player
gets all of them, and the Config lets you choose who gets which.

It works in any Roblox game, R15 or R6, with or without StreamingEnabled. You
drag two files into Studio and that's it: no server script, no RemoteEvents,
nothing to publish. Every player sees everybody's pets, and since each
player's device animates them on its own, there's no network traffic at all.
The pets are just for looks: their parts are anchored and never collide, so
they can't push players, block doors or be used to climb.

Use this folder instead of the single pet folders, not together with them. If
you also install a single pet pack, players get that pet twice.


WHAT'S IN THIS FOLDER
---------------------

The folders are named after the places in Studio's Explorer where each file
goes:

  All in One/
    README.txt                   this file
    ReplicatedStorage/
      AllPets.rbxm               drag onto ReplicatedStorage
    StarterPlayer/
      StarterPlayerScripts/
        AllPetsClient.rbxm       drag onto StarterPlayerScripts


INSTALL (2 MINUTES)
-------------------

1. Open your game in Roblox Studio. If you don't see the Explorer, open it
   with View > Explorer.
2. Drag ReplicatedStorage/AllPets.rbxm from your computer and drop it on
   ReplicatedStorage in the Explorer. Another way: right click
   ReplicatedStorage > Insert from File... and pick the file.
3. Drag StarterPlayer/StarterPlayerScripts/AllPetsClient.rbxm and drop it on
   StarterPlayerScripts. It's inside StarterPlayer: click the little arrow
   next to StarterPlayer to see it.
4. Press Play. The pets show up next to your character and follow you.

If a file lands in the wrong place (in Workspace, for example), just drag it
in the Explorer to where it belongs. With everything in place, the Explorer
looks like this:

  ReplicatedStorage
    AllPets                (Folder)
      Config               (ModuleScript)   all the settings
      Models               (Folder)         what each pet looks like
        Dog                (Model)
        Snake              (Model)
      Modules              (Folder)         the code, no need to touch it
        DogAnimation       (ModuleScript)
        DogModel           (ModuleScript)
        DogPet             (ModuleScript)
        PetFollow          (ModuleScript)
        PetKit             (ModuleScript)
        PetRig             (ModuleScript)
        PetSpawner         (ModuleScript)
        SnakeAnimation     (ModuleScript)
        SnakeModel         (ModuleScript)
        SnakePet           (ModuleScript)
  StarterPlayer
    StarterPlayerScripts
      AllPetsClient        (LocalScript)    starts the pets

.rbxm files don't open with a double click. Open Studio first, then drag them
into the Studio window.


WHAT THE DOG DOES
-----------------

A blocky cartoon dog with big floppy ears and a white-tipped tail. None of it
is a canned animation: it all reacts to how fast its owner is moving.

- Standing: a happy little bounce. It looks around with its head tilted, wags
  its tail, blinks now and then and turns to look at its owner.
- Walking: a bouncy waddle, the head nodding with the steps, ears flopping.
- Running: when it falls behind it gallops with big hops, ears back and the
  tongue out.
- WOOF!: every few seconds it barks, one to three times in a row. It crouches,
  hops, snaps its head up, opens its mouth, squints happily and wags faster,
  and a WOOF! bubble pops up with the bark (a slightly different pitch each
  time).

It walks a little behind its owner, on the right. When its owner stops, it
trots to its spot, stops and looks at them.


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

Each pet walks on its own spot next to its owner, so they don't bump into each
other. You can move them with Spot.


SETTINGS
--------

All the settings are in ReplicatedStorage > AllPets > Config. Double click
it, change what you like and press Play. This is the whole file, with the
default values:

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

What each one does:

  Config.Pets
      The pets every player gets. Take out the ones you don't want, for
      example Config.Pets = { "Dog" }.

  Config.GiveTo
      "Everyone" gives Config.Pets to every player. "Attribute" gives pets
      only to the players you pick (see "A different pet for each player"
      below).

  Config.Attribute
      Name of the player attribute that picks a player's pets. "Pet" unless
      you change it.

  Config.ShowOtherPlayersPets
      false = each player only sees their own pets. Handy on big servers or
      for slow devices.

  And for each pet (Config.Dog, Config.Snake...):

  Scale
      Size of that pet: 2 is twice as big, 0.5 is half. Its steps, speed and
      bubble grow with it.

  Spot
      Where it walks next to its owner, in studs. X is to the right (negative
      goes to the left), Z is behind (negative goes in front).

  Sound
      Sound id of its call (the bark, the hiss...). "" means no sound.

  SoundStart
      Second of the sound file where the call starts, for sounds that begin
      with some silence.

  Volume
      How loud the call is, from 0 to 10.

  Texts
      Words that pop up over its head when it calls. One is picked at random
      each time. {} means no bubble.

  Every
      { min, max }: how many seconds between the times it calls on its own.
      false means it only does it when your own scripts ask (see below).


A DIFFERENT PET FOR EACH PLAYER (SHOP, GAME PASS, VIP, LEVEL...)
----------------------------------------------------------------

The Pet attribute on a player picks that player's pets, and it wins over
Config.Pets. Set it from any server Script (in ServerScriptService):

    player:SetAttribute("Pet", "Dog")         -- this player gets the dog
    player:SetAttribute("Pet", "Dog,Snake")   -- several pets, with commas
    player:SetAttribute("Pet", "")            -- no pet
    player:SetAttribute("Pet", nil)           -- back to Config.Pets

The change shows on every screen right away. If only the players you pick
should have pets, also set Config.GiveTo = "Attribute": players without the
attribute then get nothing.

For example, a game pass that gives the snake. Paste this in a Script in
ServerScriptService and put your game pass id in it:

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


MAKE THE PETS REACT FROM YOUR OWN SCRIPTS
-----------------------------------------

From any LocalScript:

    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Players = game:GetService("Players")

    local PetSpawner = require(ReplicatedStorage:WaitForChild("AllPets"):WaitForChild("Modules"):WaitForChild("PetSpawner"))

    PetSpawner.react(Players.LocalPlayer)          -- all of the local player's pets, now
    PetSpawner.react(Players.LocalPlayer, "Snake") -- only the snake

The dog barks and the snake hisses. PetSpawner.react(player) works for any
player, not just the local one, and only on the device that calls it.
PetSpawner.getPets(player) gives you that player's pets; each one has a model
(the Model in workspace.AnimatedPets). Set Every = false on a pet if it should
only react when you say so.


BIGGER OR SMALLER
-----------------

In Config, change Scale inside that pet's settings (Config.Dog,
Config.Snake...): 2 is twice as big, 0.5 is half. Use Scale for this,
resizing the models in Models won't do it.


COLORS AND MATERIALS
--------------------

1. Open ReplicatedStorage > AllPets > Models and pick a pet.
2. Click a part and change Color, Material, Transparency or Reflectance in the
   Properties window.
3. Press Play.

It's easier when you can see it: drag the pet's model into Workspace, edit it,
then drag it back into Models. Keep the model's name (Dog, Snake...) and the
part names.

Anything you put inside a part comes along too: a Decal, a Texture, Sparkles,
Fire, a ParticleEmitter, a PointLight...

The size and position of the original parts come from the animation, so moving
or resizing them in the model does nothing. For the size, use Scale.


HATS, COLLARS AND OTHER ACCESSORIES
-----------------------------------

1. Drag the pet's model into Workspace so you can see it.
2. Put a Part or a MeshPart (or a whole Model made of parts) inside the pet's
   model, where it should go. On top of the head, for example.
3. Drag the model back into Models and press Play.

The accessory moves with the closest body part. To pick the body part
yourself, select the accessory and add an Attribute called Bone (type string)
with one of these:

  Dog: Body, Head, EarL, EarR, Jaw, Tongue, Lids, Tail, LegFL, LegFR, LegBL,
    LegBR
  Snake: Head, Body1, Body2, Body3, Body4, Body5, Body6, Body7, Body8, Body9,
    Body10, Tongue, Mouth, BrowL, BrowR

Accessories keep their own size and position, and like the rest of the pet
they're anchored and don't collide.


YOUR OWN SOUNDS
---------------

1. Find or upload a sound and copy its id (Creator Store, or Creator Hub >
   Development Items > Audio).
2. In Config, in that pet's settings, set Sound = "rbxassetid://YOUR_ID" and
   SoundStart = 0.

Roblox only plays sounds your game is allowed to use: your own uploads, sounds
from the group that owns the game, and public sounds from the Creator Store.
About the sounds that come with the pets:

  - Dog: The default bark is "beagle barking", a public sound from the Creator
    Store.
  - Snake: The default hiss is "Snake Hiss 1 (SFX)" by Pro Sound Effects,
    licensed by Roblox for every experience. It has 2.8 seconds of silence at
    the start, that's why SoundStart is 2.8 by default.


THE WORDS IN THE BUBBLES
------------------------

Edit Texts in that pet's settings in Config. Texts = {} turns its bubble off.


TROUBLESHOOTING
---------------

No pets show up
  - Check that AllPets is in ReplicatedStorage and AllPetsClient is in
    StarterPlayer > StarterPlayerScripts (not in StarterPlayer itself, not in
    Workspace).
  - Open View > Output. Messages starting with [Pets] tell you what's wrong,
    like a misspelled name in Config.Pets. The names are Dog and Snake, with
    capital letters.
  - With GiveTo = "Attribute", only players with the Pet attribute get pets.

The Output says "[Pets] AllPets is missing from ReplicatedStorage"
  - The AllPets folder isn't there or was renamed. Drag AllPets.rbxm into
    ReplicatedStorage again and keep its name.

No sound
  - The sound isn't available to your game (see "Your own sounds"), or Volume
    is 0, or Sound is "".
  - In Studio, make sure the game sound isn't muted (the speaker icon at the
    top).

My color changes don't show
  - The model has to be in AllPets > Models, keep its name (Dog, Snake...),
    and the parts have to keep their names.

Too many pets for my server
  - Give each player fewer pets (Config.Pets), or set
    ShowOtherPlayersPets = false so each player only animates their own pets.


GOOD TO KNOW
------------

- Each pet is 25 to 32 parts, all moved with a single workspace:BulkMoveTo
  per frame, so they're light even with a full server.
- The pets live in a folder called AnimatedPets in Workspace, made on each
  player's device. They aren't on the server, so server scripts can't see them
  (on purpose).
- Pets find the ground with a raycast, so they walk up ramps and stairs (and on
  top of terrain water). Where there's no floor under them, they stay at their
  owner's feet height.
- When their owner teleports or respawns far away, the pets jump straight to
  their spots next to them.
