ANIMATED PETS: ALL IN ONE
=========================

Every animated pet in one install: Dog, Snake, Bunny, Crab and Dragon. Out of
the box every player gets all of them, and the Config lets you choose who gets
which.

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
        Bunny              (Model)
        Crab               (Model)
        Dragon             (Model)
      Modules              (Folder)         the code, no need to touch it
        BunnyAnimation     (ModuleScript)
        BunnyModel         (ModuleScript)
        BunnyPet           (ModuleScript)
        CrabAnimation      (ModuleScript)
        CrabModel          (ModuleScript)
        CrabPet            (ModuleScript)
        DogAnimation       (ModuleScript)
        DogModel           (ModuleScript)
        DogPet             (ModuleScript)
        DragonAnimation    (ModuleScript)
        DragonModel        (ModuleScript)
        DragonPet          (ModuleScript)
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


WHAT THE BUNNY DOES
-------------------

A white blocky bunny with long pink-lined ears and a fluffy tail. None of it
is a canned animation: it all reacts to how fast its owner is moving.

- Sitting: it breathes, twitches its nose in quick little bursts, flicks or
  turns one ear at a time to listen, looks around and blinks.
- Hopping: a crouch, a push with the long hind feet, an arc through the air
  with the ears streaming back, front paws first on landing, then the hind
  feet, and the ears flop forward.
- Running: when it falls behind, the hops get longer, higher and faster, with
  the body stretched out.
- Binky!: every few seconds it does a binky, the jump real bunnies do when
  they're happy. It crouches, springs straight up with a twist, kicks its
  hind feet out, flaps its ears, shuts its eyes, opens its mouth and lands
  with a little squash, with a pop-up bubble and a squeak.

It hops along on its owner's right, a little behind. When its owner stops, it
hops to its spot and sits down.


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

Each pet has its own spot next to its owner, so they don't bump into each
other (the dragon flies over the others). You can move them with Spot.


SETTINGS
--------

All the settings are in ReplicatedStorage > AllPets > Config. Double click
it, change what you like and press Play. This is the whole file, with the
default values:

    --[[
        Pet settings. Change anything here and press Play to see it.
        The full guide is in README.txt, next to the files you dragged in.
    ]]

    local Config = {}

    -- Pets every player gets. Pet names: "Dog", "Snake", "Bunny", "Crab", "Dragon"
    Config.Pets = { "Dog", "Snake", "Bunny", "Crab", "Dragon" }

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

    -- BUNNY ----------------------------------------------------------------------
    Config.Bunny = {
        -- 1 = original size, 2 = twice as big, 0.5 = half.
        Scale = 1,
        -- Where it hops next to its owner, in studs: X to the right (negative =
        -- left), Z behind (negative = in front).
        Spot = Vector3.new(5.2, 0, 0.6),
        -- The squeak of a binky. Any sound id your game is allowed to play.
        -- "" = no sound.
        Sound = "rbxassetid://9125994553",
        SoundStart = 0, -- second of the sound file where the squeak starts
        Volume = 0.5,
        -- Words that pop up over its head when it does a binky. {} = no bubble.
        Texts = { "Boing!", "Hop!", "Wheee!", "Yay!" },
        -- Seconds between the binkies it does on its own: { min, max }.
        -- false = it only does them when your scripts call PetSpawner.react.
        Every = { 4.5, 9 },
    }

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
      Where it goes next to its owner, in studs. X is to the right (negative
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

The dog barks, the snake hisses, the bunny does a binky, the crab snaps and
the dragon breathes fire. PetSpawner.react(player) works for any player, not
just the local one, and only on the device that calls it.
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

  Dog: Body, Head, EarL, EarR, Jaw, Tongue, Tail, LegFL, LegFR, LegBL, LegBR
  Snake: Head, Body1, Body2, Body3, Body4, Body5, Body6, Body7, Body8, Body9,
    Body10, Tongue, BrowL, BrowR
  Bunny: Body, Tail, Head, EarL, EarR, Muzzle, Nose, LegFL, LegFR, FootL,
    FootR
  Crab: Root, Body, StalkL, StalkR, ArmL, ForearmL, PincerL, FingerLIn,
    FingerLOut, ArmR, ForearmR, PincerR, FingerRIn, FingerROut, LegFL, ShinFL,
    LegFR, ShinFR, LegBL, ShinBL, LegBR, ShinBR
  Dragon: Body, Head, Jaw, WingR, WingL, Tail1, Tail2, Tail3, LegFR, LegFL,
    LegBR, LegBL

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
  - Bunny: The default squeak is "Squeeze Toy Squeaky Rubber With Noisemaker
    Hits 9" by Pro Sound Effects, licensed by Roblox for every experience.
  - Crab: The default snap is "Crab Claw Smaller Snaps Plasticky 3" by Pro
    Sound Effects, licensed by Roblox for every experience. Its three clicks
    match the three snaps of the animation, so with a sound of your own the
    clicks may not line up with the claws.
  - Dragon: The default whoosh is "Fire Whoosh 4" by Pro Sound Effects,
    licensed by Roblox for every experience. It builds up slowly, that's why
    SoundStart is 1.3 by default.


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
    like a misspelled name in Config.Pets. The names are Dog, Snake, Bunny,
    Crab and Dragon, with capital letters.
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

- Each pet is 25 to 48 parts, all moved with a single workspace:BulkMoveTo
  per frame, so they're light even with a full server.
- The pets live in a folder called AnimatedPets in Workspace, made on each
  player's device. They aren't on the server, so server scripts can't see them
  (on purpose).
- Pets find the ground with a raycast, so they go up ramps and stairs (and on
  top of terrain water). Where there's no floor under them, they stay at their
  owner's feet height (the dragon flies that much higher).
- When their owner teleports or respawns far away, the pets jump straight to
  their spots next to them.
