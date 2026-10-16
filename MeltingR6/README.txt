MELTING R6
==========

An R6 character whose head is melting: one eye popping out, an empty socket
with a nerve hanging from it, and a huge grin full of teeth. The body is the
classic R6 shape, so it works with any R6 animation.

The rig is the same as a regular Roblox R6: a Humanoid set to R6, a
HumanoidRootPart, and the usual Motor6Ds (Neck, Left/Right Shoulder,
Left/Right Hip and RootJoint), named the way the Animate script and the
Animation Editor expect.


WHAT'S IN THE ZIP
-----------------

Each folder is named after the place in Studio's Explorer where its file goes:

  MeltingR6/
    README.txt                  this file
    Workspace/
      MeltingR6.glb             the 3D model (goes in through the 3D Importer)
    ServerScriptService/
      MeltingR6Rig.rbxm         the script, drag it onto ServerScriptService
      MeltingR6Rig.lua          the same script as plain text, if you'd rather paste it
    Test/
      MeltingR6_Test.rbxl       an empty place with the script already in it

Unzip it first (right click > Extract All).

Why isn't the model already inside a .rbxm? Roblox only shows meshes that were
uploaded to your account, and the thing that uploads them is Studio's 3D
Importer. So the model goes in through the Importer, and the script builds the
rig on top of it.


ADDING IT TO YOUR GAME
----------------------

1. Open your game in Roblox Studio. If you can't see the Explorer, open it
   from View > Explorer.

2. THE MODEL: go to the Avatar tab > 3D Importer (or File > Import 3D) and
   pick Workspace/MeltingR6.glb.
   You can leave the settings as they are, just make sure "Merge Meshes" is
   OFF. Click Import and MeltingR6 shows up in Workspace.

3. THE SCRIPT: drag ServerScriptService/MeltingR6Rig.rbxm from your computer
   and drop it on ServerScriptService in the Explorer. Or right click
   ServerScriptService > Insert from File... and pick the file.

   (Rather paste it? Right click ServerScriptService > Insert Object > Script,
   delete what's in it, open MeltingR6Rig.lua in Notepad, copy everything and
   paste it into the Script.)

4. Hit Play. The Output should say:
     [MeltingR6] R6 rig ready: Workspace.MeltingR6
   and he'll be standing on the ground, fully rigged.

When everything is in place, the Explorer looks like this:

  Workspace
    MeltingR6              (Model)    what the Importer brought in
  ServerScriptService
    MeltingR6Rig           (Script)   builds the rig when the game starts

If a file lands in the wrong spot (in Workspace, for example), just drag it in
the Explorer to where it belongs.

.rbxm files don't open with a double click. Open Studio first, then drag the
file into its window.


TRYING IT IN A SEPARATE PLACE
-----------------------------

Open Test/MeltingR6_Test.rbxl in Studio (File > Open from File...). It already
has a floor, a spawn and the script in ServerScriptService. Just do step 2
(import the .glb), hit Play and walk over to him.


USING IT IN YOUR GAME
---------------------

Want more than one? Duplicate MeltingR6 in Workspace (Ctrl+D) as many times as
you like. Every one that's in Workspace when the game starts gets rigged.

Walking somewhere (it's a regular Humanoid, so it works like any NPC). In a
Script inside ServerScriptService:

    local npc = workspace:WaitForChild("MeltingR6")
    npc:WaitForChild("Humanoid"):MoveTo(Vector3.new(0, 0, -30))

Playing an R6 animation (he doesn't come with any, he just stands still):

    local npc = workspace:WaitForChild("MeltingR6")
    local animation = Instance.new("Animation")
    animation.AnimationId = "rbxassetid://PASTE_YOUR_ID_HERE"
    npc:WaitForChild("Humanoid"):WaitForChild("Animator"):LoadAnimation(animation):Play()

Keep in mind Roblox only plays animations published by the same account (or
group) that owns the game.

Spawning him from a script: MeltingR6Rig only rigs what's in Workspace when the
server starts. If you want to keep him in ServerStorage and clone him later,
rig him in Studio first (next section), drag him into ServerStorage, and clone
him from there:

    local model = game.ServerStorage.MeltingR6:Clone()
    model:PivotTo(CFrame.new(0, 5, 0))
    model.Parent = workspace

Playing as him: rig him in Studio first (next section), rename the model to
StarterCharacter and put it inside StarterPlayer. Your game has to be set to
R6 (Game Settings > Avatar > R6). To get him walking with animations, hit Play,
copy the "Animate" script from your own character (Workspace > your name),
stop the game and paste Animate inside StarterCharacter.


KEEPING HIM RIGGED IN STUDIO (TO ANIMATE, CLONE OR PLAY AS HIM)
---------------------------------------------------------------

When you hit Play, the rig only exists while the game is running. To make it
stick in the place:

1. Open MeltingR6Rig.lua in Notepad and copy everything.
2. In Studio: View > Command Bar, paste it and hit Enter.

That's it. MeltingR6 now keeps its Humanoid and Motor6Ds saved in the place,
and you can open him in the Animation Editor. Ctrl+Z undoes it. You can leave
the script in ServerScriptService anyway: it doesn't touch anything that's
already rigged.


IF SOMETHING GOES WRONG
-----------------------

"Couldn't find the imported model in Workspace"
    The model isn't in Workspace, or it was imported with "Merge Meshes" on
    (which squashes it into a single part). Import it again with that option
    off.

"The mesh came in rotated"
    The rig works fine. This only matters if you use a script that writes a
    fixed Neck.C0 (a head that follows the mouse, for example). If that's you,
    import it again switching "World Forward" between Front and Back.

He came in huge or tiny
    Leave it, the script resizes him to the right R6 size.


DETAILS
-------

- The head is split into several parts (Head, Mouth, EyeSockets, PoppingEye,
  Nerve, Teeth and Gums) because Roblox won't take a mesh with more than about
  20k triangles. They're all welded to the Head, massless and with no
  collision.
- Only the Torso and Head collide, same as a regular R6.
- Around 100k triangles in total. Fine for a main monster, but if you put
  dozens of them on screen at once it can get heavy on phones.
