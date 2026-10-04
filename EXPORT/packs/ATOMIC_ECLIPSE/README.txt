ATOMIC ECLIPSE
==============

A 32 second anime finisher for Roblox R15.

The character walks forward slowly while violet energy lines run up the body, wakes up, floats,
charges a singularity in front of the chest, goes completely silent for a moment, and then
everything goes white: nuke, shockwaves, debris, a mushroom column and falling ash. It ends with
a soft landing, a flick of the sword and a calm stance.

60 fps, 1523 keyframes, 44 named markers so you can sync your own sounds and effects.

Thanks for buying! Everything you need is in this folder and explained below.


WHAT'S IN THIS FOLDER
---------------------

  1_Animation_Only/AtomicEclipse_Animation.rbxm
      Just the animation. Standard R15 joints, no sword, no effects, no scripts.

  2_Animation_With_Sword/AtomicEclipse_Animation_Sword.rbxm
      The animation with the sword joint, plus the sword model and a small script that puts it
      in the character's right hand.

  3_Full_Ability/AtomicEclipse_Full.rbxm
      The complete ability: animation, all visual effects, sword, scarf, camera shake, screen
      effects, damage, knockback, cooldown and keybind. Ready to drop into a game.

  Demo/AtomicEclipse_Demo.rbxl
      A place with the full ability already installed. Open it, press Play, press 1.

  Preview/AtomicEclipse_Preview.mp4
      Preview video.

Pick the version you need. You don't have to install more than one.


BEFORE YOU START
----------------

- Your game has to use R15 avatars: Game Settings > Avatar > Avatar Type > R15.
- Roblox only plays animations owned by the game's owner. If the game belongs to a group,
  publish the animation to that group. If it's your own game, publish it to your account.
  Nobody else can give you a working animation ID, so you always publish it yourself.


HOW TO PUBLISH THE ANIMATION (used by options 1 and 2, and for live games in option 3)
-------------------------------------------------------------------------------------

1. In Studio, find the KeyframeSequence (the animation object) in the Explorer.
2. Right click it > Save to Roblox. (Or: select a R15 rig, open the Animation Editor, load the
   animation from the rig's AnimSaves and click "..." > Publish to Roblox.)
3. Pick the owner (your account or the group that owns the game) and confirm.
4. Copy the ID it gives you. You'll paste it in your script or in the config.


OPTION 1: ANIMATION ONLY
------------------------

1. Drag AtomicEclipse_Animation.rbxm into Studio. You get a KeyframeSequence named ATOMIC_ECLIPSE.
2. Publish it (see above) and copy the ID.
3. Play it from a LocalScript (or a server Script, both work):

    local Players = game:GetService("Players")

    local character = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()
    local animator = character:WaitForChild("Humanoid"):WaitForChild("Animator")

    local animation = Instance.new("Animation")
    animation.AnimationId = "rbxassetid://PASTE_YOUR_ID_HERE"

    local track = animator:LoadAnimation(animation)
    track.Priority = Enum.AnimationPriority.Action4
    track:Play()

    track:GetMarkerReachedSignal("NUKE"):Connect(function()
        print("boom")
    end)

Good to know:
- The animation doesn't loop. It lasts exactly 32 seconds.
- During the first 6 seconds the character walks about 6.5 studs forward. Roblox animations
  can't move the character itself, so with this version the walk happens in place. If you
  want the character to actually move, call Humanoid:Move or MoveTo during those 6 seconds,
  or use the full ability (option 3), which does it for you.
- The character floats during the middle part and lands at 27.4 seconds. That's in the
  animation itself, you don't need to do anything.
- The marker list is at the end of this file.


OPTION 2: ANIMATION + SWORD
---------------------------

1. Drag AtomicEclipse_Animation_Sword.rbxm into Studio. You get a folder named
   ATOMIC_ECLIPSE_Sword with two things inside:
     - ATOMIC_ECLIPSE (KeyframeSequence): the animation, including the sword movement.
     - AttachSword (Script): gives every R15 character the sword in the right hand.
2. Move AttachSword to ServerScriptService. The sword model (EmberBlade) is inside the script,
   leave it there.
3. Publish the KeyframeSequence (see above) and play it with the code from option 1.

Good to know:
- Don't rename EmberBlade or the Motor6D inside it (EmberBladeGrip). The animation finds the
  sword joint by those names.
- The sword has a trail (EmberBlade > BladeTrail) that starts off. Set Enabled to true if you
  want it.
- In the full ability the sword dissolves into light during the explosion. In this version it
  stays visible. If you want to hide it, set Transparency to 1 on the sword parts at the
  BLADE_DISSOLVE marker and back to 0 at BLADE_REFORM.
- Everything else from option 1 applies here too (walk in place, 32 seconds, no loop).


OPTION 3: FULL ABILITY
----------------------

Install:

1. Drag AtomicEclipse_Full.rbxm into Studio. You get a folder named EmberAbilities. Inside it
   there are three folders named after services, and each one holds one thing:
     EmberAbilities > ReplicatedStorage > Ember
     EmberAbilities > ServerScriptService > EmberServer
     EmberAbilities > StarterPlayerScripts > EmberClient
2. Move each of those three into the real service with the same name:
     Ember        > ReplicatedStorage
     EmberServer  > ServerScriptService
     EmberClient  > StarterPlayer > StarterPlayerScripts
3. Delete what's left of the EmberAbilities folder.
4. Press Play and press 1.

That's it for Studio. Inside Studio the animation loads straight from the file, so you don't
need to publish anything to test.

For a live game (published, with real players):

1. Publish ReplicatedStorage > Ember > KeyframeSequences > ANIM_01_ATOMIC_ECLIPSE (see above).
2. Open ReplicatedStorage > Ember > Assets and paste the ID:

    Assets.Animations = {
        ANIM_01_ATOMIC_ECLIPSE = "1234567890",
    }

   Just the number is fine. Without the ID the ability still runs its effects in a live game,
   but the character won't animate (you'll see a warning in the output).

What the ability does:

- Press 1 to cast. It lasts 32 seconds and has a 45 second cooldown (counted from the cast).
- The player can't move while casting. The character walks 6.5 studs forward at the start and
  stops if there's a wall in front.
- The sword and the scarf are added to every R15 character when it spawns.
- Damage happens on the server at 19.6 seconds (NUKE): 45 damage to every Humanoid within
  60 studs, less the farther away they are, plus a strong knockback upward and outward.
  A second shockwave at 20.4 seconds pushes anything within 120 studs (no damage).
- It hits players and NPCs, anything with a Humanoid, except the caster. There's no team check.
- Everyone sees the effects. Players more than 900 studs away skip them to save performance,
  and the camera shake and screen effects fade with distance.
- The amount of particles scales with each player's graphics level, so low-end devices get a
  lighter version automatically.

Settings (ReplicatedStorage > Ember > Config):

    Config.Abilities.AtomicEclipse.key        key to cast (default Enum.KeyCode.One)
    Config.Abilities.AtomicEclipse.cooldown   cooldown in seconds (default 45)
    Config.AnimationPriority                   default Action4
    Config.Damage.Enabled                      false = no damage or knockback at all
    Config.Damage.Multiplier                   2 = double damage, 0.5 = half
    Config.Damage.HitCaster                    true = the caster can hit themselves
    Config.OnHit                               function called on every hit (see below)
    Config.Quality.MaxParticles                hard cap on particles at the same time
    Config.Quality.ObserverCullDistance        distance where other players stop seeing it

Example of Config.OnHit, for kill credit, stats, etc.:

    Config.OnHit = function(attacker, humanoid, abilityName, hitName, amount)
        print(attacker.Name, "hit", humanoid.Parent.Name, "for", amount)
    end

Casting from your own code (a mobile button, a GUI, a tool):

Phones and tablets don't have a "1" key, so if your game has mobile players, give them a
button. From any LocalScript:

    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local remote = ReplicatedStorage:WaitForChild("Ember"):WaitForChild("Remote")

    remote:FireServer("cast", "AtomicEclipse")

The server still checks the cooldown and whether the player is alive, so it's safe to call from
anywhere. A quick on-screen button for mobile with ContextActionService (put it in StarterPlayerScripts):

    local ContextActionService = game:GetService("ContextActionService")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local remote = ReplicatedStorage:WaitForChild("Ember"):WaitForChild("Remote")

    ContextActionService:BindAction("AtomicEclipse", function(_, state)
        if state == Enum.UserInputState.Begin then
            remote:FireServer("cast", "AtomicEclipse")
        end
    end, true, Enum.KeyCode.ButtonY)
    ContextActionService:SetTitle("AtomicEclipse", "ULT")

That also casts with the Y button on a gamepad.

If you want to remove the keyboard shortcut, set the key to nil:

    AtomicEclipse = { key = nil, cooldown = 45 },


DEMO PLACE
----------

Open Demo/AtomicEclipse_Demo.rbxl in Studio and press Play. Press 1 to cast. There are training
dummies around the spawn at different distances so you can see the damage and knockback.

There's also a rig called AnimationRig with the animation in its AnimSaves. Select it and open
the Animation Editor if you want to look at the keyframes or edit the animation.


MARKERS
-------

Times are in seconds from the start. Markers with a number after them happen more than once.

     0.03  CAST_START       the cast starts
     0.17  CIRCUITS_START   energy lines start running up the body
     1.30  STEP_SIGIL 1-5   a glowing ring under each step (1.30, 2.23, 3.17, 4.10, 5.03)
     5.83  AWAKEN           eyes light up, ground pulse
     7.00  CONVERGE         particles start flowing into the body
     7.17  SIGIL_GROUND 1-3 magic circle grows on the ground (7.17, 8.67, 10.00)
     7.50  DIM              the world gets darker
    10.20  LEVITATE         starts floating
    12.67  HALO             eclipse halo appears behind the back
    13.33  HELIX            ribbons spiral around the body
    13.67  ORBS             orbs start circling the chest
    16.50  CHARGE_PEAK      peak of the charge
    16.67  BLADE_DISSOLVE   the sword dissolves into light
    17.33  IMPLODE          everything collapses into one point
    17.67  SILENCE          dead silence, dark screen
    18.00  POINT_PULSE 1-3  the point pulses (18.00, 18.50, 19.00)
    19.60  RELEASE          release
    19.60  WHITE_FLASH      white flash
    19.63  NUKE             the explosion (damage happens here)
    19.70  SHOCKWAVE 1-3    shockwave rings (19.70, 20.00, 20.42)
    19.75  DUST_WALL        wall of dust
    19.83  DEBRIS           rocks flying
    20.00  COLUMN           energy column
    20.67  MUSHROOM         mushroom cloud
    25.00  ASH_FALL         ash starts falling
    26.00  SCREEN_RESTORE   screen back to normal
    26.50  BLADE_REFORM     the sword comes back
    27.37  LAND             lands softly
    29.13  TRAIL_START      sword trail on
    29.37  FLICK            flicks the sword
    29.50  TRAIL_END        sword trail off
    31.33  DISSIPATE        last of the energy fades
    31.67  RECOVERY         back to stance
    32.00  END              end

If you want to add sound, the best spots are AWAKEN, CHARGE_PEAK, SILENCE (cut all sound
here, it makes the explosion hit much harder), NUKE and LAND.


TROUBLESHOOTING
---------------

Nothing happens when I press 1
  - Check that all three folders are in the right services (Ember in ReplicatedStorage,
    EmberServer in ServerScriptService, EmberClient in StarterPlayerScripts).
  - Check the Output window. "is not R15" means the game is set to R6.
  - You may be on cooldown (45 seconds).

The effects play but the character doesn't move (live game)
  - The animation ID is missing or was published by someone who doesn't own the game.
    Publish it on the game owner's account or group and paste the ID in Ember > Assets.

The animation plays but the sword doesn't move (option 2)
  - EmberBlade or EmberBladeGrip was renamed, or AttachSword isn't in ServerScriptService.

The character walks in place at the start (options 1 and 2)
  - That's expected. See the note in option 1.

The animation gets overridden by walking/idle or by another animation
  - Raise the priority: track.Priority = Enum.AnimationPriority.Action4.

The pose looks a bit different on my avatar
  - The animation was made on the default blocky R15 body. Avatars with very different
    proportions (very tall, very thin, Rthro) use the same joint rotations on a different
    body, so the hands can end up in slightly different places.

The distortion sphere is barely visible
  - It uses Glass, which only refracts on high graphics settings. On low settings it's
    almost invisible. That's normal.


NOTES
-----

- All effects are made with Parts, Beams, Lights and post-processing. There are no textures,
  meshes or sounds to upload, and nothing has to be published besides the animation.
- Roblox can't really invert the screen colors, so the impact frame is a blown-out black and
  white frame instead.
- Don't resell or redistribute these files.

Enjoy!
