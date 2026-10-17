# Audio credits

Every sound is a public asset from Roblox's licensed audio library, usable in any Roblox experience. The creator accounts are:

- **Roblox**: classic Roblox sound effects (`clickfast.wav`, `swoosh.wav`, ...)
- **APMOfficial**: music from APM Music, licensed by Roblox for all creators
- **ProSoundEffects**: the Pro Sound Effects library, licensed by Roblox for all creators

The IDs were checked against `economy.roblox.com` (public, audio type) when this build was made. They live in `src/ReplicatedStorage/Shared/AudioLibrary.luau`, and the generated Sound objects are under `SoundService.GameAudio`.

| Category | Name in code | Asset ID | Title |
|---|---|---|---|
| Music | `Battle` | 1839465913 | Battle Action - Kosinus (APM) |
| Music | `Defeat` | 1846942404 | Loser Sting Three B - John Epping (APM) |
| Music | `Lobby` | 1837768517 | Bossa Me (a) - Peter Christiansen (APM) |
| Music | `Showdown` | 1839847752 | Against Time - Juice Music (APM) |
| Music | `Victory` | 1837762472 | Victory Dance (sting a) - Glenn Herweijer (APM) |
| Sfx | `BattleStart` | 9114631615 | Gong Whoosh 6 |
| Sfx | `Bounce` | 9113262444 | Ball Bounce Exterior 3 |
| Sfx | `BrickCrumble` | 9118587494 | Rock Drop On Concrete |
| Sfx | `Cheer` | 9112766176 | Crowd Cheer And Applause 1 |
| Sfx | `Countdown` | 12221990 | electronicpingshort.wav |
| Sfx | `Explosion` | 9117982449 | Pyro Explosion 1 |
| Sfx | `Fireworks` | 9114447096 | Fireworks Fast 1 |
| Sfx | `FuseTick` | 12221976 | clickfast.wav |
| Sfx | `Hit` | 12222046 | hit.wav |
| Sfx | `Knockout` | 12222253 | victory.wav |
| Sfx | `Notify` | 17208361335 | Roblox GUI - Notification High |
| Sfx | `Pop` | 15675055424 | Roblox_UI_Cute_Pop |
| Sfx | `PowerUp` | 9116422213 | Magic Transformation 17 |
| Sfx | `RocketFire` | 12222084 | Rocket shot.wav |
| Sfx | `SwordLunge` | 12222208 | swordlunge.wav |
| Sfx | `SwordSlash` | 12222216 | swordslash.wav |
| Sfx | `Throw` | 12222200 | swoosh.wav |
| Sfx | `TowerCollapse` | 3149249837 | Cannon_Explode |
| Sfx | `UiClick` | 15675059323 | Roblox_UI_Bright_Click |
| Sfx | `UiHover` | 10066931761 | RBLX UI Hover 01 |
| Sfx | `ZoneAlarm` | 9113089565 | Alarm Tone 2 Tone Fast High Low |
| Sfx | `ZoneZap` | 9114277757 | Electric Zaps 12 |
| Ambient | `Crowd` | 9112766176 | Crowd Cheer And Applause 1 |
| Ambient | `Wind` | 9114057104 | Desert Wind Whistley Light Gusts 1 |

Music loop regions (seconds, measured on whole bars) are set as `Sound.LoopRegion` so the library tracks loop without their fade-out tails:

| Track | Loop |
|---|---|
| Lobby | 0.665 - 139.079 |
| Battle | 0.036 - 97.888 |
| Showdown | 0.251 - 66.689 |
