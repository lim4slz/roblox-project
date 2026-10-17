# Doomspire Brickbattle (Remastered)

A team-based tower-destruction game for Roblox, inspired by the classic *Doomspire Brickbattle* and rebuilt for today. Two teams each defend a LEGO-style brick tower. You win by blowing up the enemy tower with bouncing bombs before a storm forces everyone into the middle. Matches last 5 minutes at most, and every round rolls a different mode.

**Open `dist/DoomspireBrickbattle.rbxl` in Roblox Studio and press Play.** The place contains the map, scripts, tools and sounds, so there's nothing to install. Every sound is a Roblox-licensed public asset, so audio works straight away.

---

## How a match plays

| Phase | What happens |
|---|---|
| **Lobby** | Players wait on a floating sky island. A 30-second countdown starts once 2 players are in (1 when testing in Studio), or 10 seconds once 8 are waiting. Calm lobby music plays. You can practise throwing at a wall that rebuilds itself, hit training dummies, or climb the rainbow parkour spiral. |
| **Get Ready (10 s)** | Teams are balanced and everyone spawns frozen at their base. A "versus" screen shows both rosters and the mode, with a beep each second. |
| **Battle (≤ 5 min)** | "BATTLE BEGINS!" Play is locked to first person. Throw bombs to knock bricks out of the enemy tower; anything left without support collapses. Random events and power-ups keep things moving. |
| **Storm** | At 2:00 a purple force-field wall appears and shrinks every 30 s. Standing outside it hurts, and the damage grows each time it shrinks. By about 4:40 only the centre plateau is safe. |
| **Final Showdown** | Starts when a tower drops to 25%, only 3 players remain, or 60 s are left. Tense music kicks in, respawns stop, and the last 30 s tick out loud. |
| **Results (12 s)** | Shows the winning team, your own result, the MVP and both scoreboards. Fireworks go off over the winners' tower, then everyone returns to the lobby. |

**How a team wins:** destroy the enemy tower (it falls once only 30% of its bricks remain). In the Showdown you can also win by eliminating the whole enemy team. If time runs out, the team with more tower left wins; knockouts break a tie, then total score.

### Controls

| | Desktop | Mobile |
|---|---|---|
| Throw a bomb | Hold left click to charge (the aim arc shows where it will land), release to throw | Hold and release a tap |
| Sword | Click to slash, double-click to lunge | Tap / double-tap |
| Switch tools | `1` bomb, `2` sword | Hotbar |
| Spectate | `←` `→` to switch players, `F` for free camera (WASD + Q/E, hold right mouse to look) | On-screen arrows |
| Admin panel | `F2` or the ★ ADMIN button (admin only) | ★ ADMIN button |

### Weapons, power-ups, events and modes

- **Bomb** (main weapon): one bomb at a time with a 3-second fuse. It bounces, blinks and ticks faster as the fuse runs out, and a new one appears in your hand 2.2 s after each throw. A blast hurts enemies, never team-mates, and knocks everyone back, so bomb-jumping works.
- **Sword**: classic slash plus a lunge.
- **Rocket Launcher**: the old Brickbattle rocket. The admin can hand it out.
- **Power-ups** spawn on the glowing pads: Mega Bomb, Triple Bomb, Speed, Shield and +50 Health.
- **Random events** happen about once a minute: Bomb Rain, Low Gravity, Speed Rush, Mega Madness and Supply Drop.
- **Modes** (one is rolled each round, and the admin can pick the next one): Classic, Mega Bombs, Low Gravity, Bomb Frenzy and Chaos.

**Scoring:** a knockout is worth 100, an assist 50, each enemy brick 5, the final blow on a tower 250, and every player on the winning team gets 150. The leaderboard shows Score, KOs and session Wins.

**Teams** are balanced with a snake draft by session strength. Late joiners go to the smaller team. If people leave and the teams end up two or more players apart, someone on the bigger team switches sides at their next respawn.

---

## Admin panel

Only the player with **UserId 954019325** gets the panel. The server copies its GUI from `ServerStorage` into that player's `PlayerGui`, so nobody else ever downloads it, and the server checks the UserId again on every command.

| Tab | Commands |
|---|---|
| Match | Start Match, End Round, Blue Wins, Red Wins, +60 Seconds, Final Showdown, Shrink Storm Now, Rebuild Towers, Collapse Blue/Red Tower |
| Fun | Bomb Rain, Low Gravity, Speed Rush, Mega Madness, Supply Drop, Random Event, Toggle Fireworks, Give Everyone Bombs (3 each, first one Mega), Spawn Bomb for Everyone (a live bomb drops on every other player), Heal Everyone |
| Players | Target selector (Me / Everyone / a player), Give Bomb / Sword / Rocket Launcher, God Mode, Teleport to Arena / Lobby |
| Modes | Pick the next match's mode |

To add more admins, edit `Config.AdminUserIds`. When testing a Studio *Local Server*, the fake players have negative UserIds; set `Config.AllowAdminPanelInStudio = true` to give them the panel there. That setting has no effect in live servers.

---

## Project structure

```
dist/DoomspireBrickbattle.rbxl     <- the ready-to-open place
default.project.json               Rojo project (scripts + generated assets -> place)
src/
  ReplicatedStorage/Shared/        code shared by server and client
    Config.luau                    every gameplay number in one place
    AudioLibrary.luau              all music/SFX asset IDs, volumes, loop points
    GameState.luau                 replicated match state (attributes)
    Remotes.luau                   the full list of RemoteEvents
    UIKit.luau                     the UI toolkit/theme every screen uses
    ZoneMath, Trajectory, Variants, TeamInfo, Signal, SoundPlayer, Format
  ServerScriptService/Server/
    Main.server.luau               boots the services
    Services/                      Match (game loop), Team, Player, Tower, Combat,
                                   Bomb, Weapon, Zone, Event, Lobby, Score, Admin, Rules
    Lib/                           BrickGraph (collapse logic), BrickStructure, CollisionGroups
  ServerStorage/AdminPanel/        admin GUI (only ever given to admins)
  StarterPlayer/StarterPlayerScripts/Client/
    Main.client.luau               boots the controllers
    Controllers/                   Camera, Music, Vfx, Zone, Weapon, Hud, Notification,
                                   Announcement, Results, Spectate, Lobby
    Lib/                           ArmAnimator (procedural throw/slash), EffectParts
map/                               Lune scripts that generate the arena, towers,
                                   lobby, tools and Sound objects
assets/                            generated .rbxm models (checked in)
tests/                             Lune test suite
scripts/build.sh                   regenerate -> build -> test -> zip
```

The map is generated rather than hand-placed, so tower geometry, symmetry and brick attributes are exact. It is still ordinary parts in the place file, though. You can edit it in Studio, and the towers keep working as long as a tower `Model` keeps its `Team` attribute and its `Bricks/` and `Decor/` folders. Bottom-row bricks carry `Grounded = true`.

### How the towers collapse

Each tower is about 460 anchored bricks laid in a running bond. When a bomb goes off, bricks inside the blast radius break loose. A flood fill through face-touching bricks (`Lib/BrickGraph.luau`) then finds everything that can no longer reach the ground. Each floating cluster is welded into one chunk so it topples as a piece, then bursts apart. Blow out the base and the whole top comes down. Health is the share of bricks still standing, and the bars are scaled so they hit 0% at the defeat threshold.

### Networking and performance

- Match state is replicated as attributes on `ReplicatedStorage.GameState`. Timers are absolute server timestamps, so clients count down locally without a packet every second.
- The storm radius is a pure function of battle time (`ZoneMath`). The client animates the wall smoothly and the server only checks damage once a second.
- Bomb ticking and blinking, explosion effects, power-up spinning and arm animations all run on the client from small events. The server only simulates what affects gameplay.
- Everything is built from primitive parts. Explosion effects are a few dozen short-lived cubes, with no textures or heavy particle effects, so it stays light on phones.

---

## Configuration

Gameplay tuning lives in `src/ReplicatedStorage/Shared/Config.luau`: match timings, the respawn delay, showdown triggers, bomb physics and damage, sword and rocket stats, storm radii and damage, event and power-up frequency, scoring, lobby options and camera settings. Modes are defined in `Variants.luau`.

### Audio

All audio comes from Roblox's licensed library (public assets you can use in any experience). Sound objects are under `SoundService.GameAudio`. To use your own music, upload it through the Asset Manager and replace the `Id` in `AudioLibrary.luau`, or the `SoundId` on the Sound object.

| Use | Track | Asset ID |
|---|---|---|
| Lobby music | *Bossa Me (a)*, Peter Christiansen (APM) | 1837768517 |
| Battle music | *Battle Action*, Kosinus (APM) | 1839465913 |
| Final Showdown | *Against Time*, Juice Music (APM) | 1839847752 |
| Victory / Defeat stings | *Victory Dance (sting a)* / *Loser Sting Three B* (APM) | 1837762472 / 1846942404 |
| Ambience | Desert wind, distant crowd (Pro Sound Effects) | 9114057104 / 9112766176 |

The music loop points were measured on whole bars so the tracks loop without the library fade-out. The sound effects (explosions, brick crumble, fuse tick, swoosh, sword, countdown, storm alarm, UI clicks, fireworks and more) are listed with credits in `docs/AUDIO.md`.

---

## Building from source

```bash
rokit install            # rojo, lune, stylua, luau-lsp (versions pinned in rokit.toml)
./scripts/build.sh       # generate map -> build place -> run tests -> dist/DoomspireBrickbattle.zip
```

For live editing, run `lune run map/build.luau` once, then `rojo serve` and connect the Rojo Studio plugin.

The checks run on this build:

- `lune run tests/run.luau`: 44 tests. They cover the collapse graph, the real generated towers (a fresh tower stands, one bomb at the door doesn't topple it, cutting the base drops everything), storm timing, bomb launch maths, modes, formatting, and cross-checks between code and place: every remote used is declared, every sound played exists, every map object a service looks up is present, and all text is in English.
- `luau-lsp analyze` with the Roblox type definitions: the whole codebase passes strict type checking.
- `stylua --check src map tests`: formatting is clean.

Since this was built outside Roblox Studio, run through `docs/TESTING.md` in Studio once: Play Solo, a 2-player local server, and the admin panel on the admin account.
