# Manual test checklist (Roblox Studio)

The automated checks (`lune run tests/run.luau`, strict `luau-lsp` type checking, StyLua) cover the logic, the generated geometry and how code and content fit together. Gameplay feel can only be checked inside Roblox. This list exercises every feature in about 15 minutes.

## 1. Play Solo (Studio → Test → Play)

`Config.Match.AllowSoloInStudio` lowers the player requirement to 1, so a single tester gets a full match.

- [ ] You spawn on the sky-island lobby. The lobby music starts, and the status card reads **MATCH STARTS IN 0:30**, with the next mode under it.
- [ ] The big board in the world shows the same countdown.
- [ ] The practice wall: hold click with the bomb, watch the aim arc, release. Bricks fly, the wall rebuilds about 8 s later, and you get knocked back but take no damage.
- [ ] Hit a training dummy with the sword and with a bomb. Floating damage numbers appear.
- [ ] Climb the rainbow parkour. Touching the golden pad shows a toast and fireworks.
- [ ] Walk off the island edge. You're caught and put back on the spawn.
- [ ] The **SITTING OUT / PLAYING NEXT MATCH** and **MUSIC** buttons toggle.
- [ ] When the countdown ends, the versus splash appears with a 10…1 beep countdown, and you're frozen at your team's base in first person.
- [ ] **BATTLE BEGINS!** and the battle music starts. The HUD shows the timer, both tower bars, bomb status, health and score.
- [ ] Throw bombs at the enemy tower. Bricks break and the health bar drops. Blow out a whole side of the base and watch the top topple.
- [ ] The first power-ups appear on the centre pads at about 0:20. Pick one up and check the toast and the HUD chip.
- [ ] A random event fires at about 0:45 with a banner.
- [ ] At 1:50 you get the storm warning. At 2:00 the purple wall appears and shrinks. Standing outside it tints the screen, zaps you and shows the warning.
- [ ] Destroy the enemy tower, or wait out the timer. You see the results screen, a sting and fireworks, then you're sent back to the lobby.

## 2. Two-player local server (Test → Clients and Servers → 2 players)

- [ ] Both players start on opposite teams.
- [ ] Bombs and swords damage enemies but never team-mates. Knockouts show in the kill feed and award points.
- [ ] A killed player spectates a team-mate with **RESPAWNING IN 5**, then respawns at their base.
- [ ] After the Final Showdown begins (use the admin button or wait for 1:00 left), a killed player is eliminated and spectates. If a whole team is eliminated, the other team wins.
- [ ] Close one client mid-match. The remaining team wins by forfeit.

## 3. Admin panel (log in as UserId 954019325)

- [ ] The **★ ADMIN** button appears at the top left, and F2 toggles the panel. Non-admin test clients never see it.
- [ ] Match tab: Start Match skips the countdown. End Round, Blue/Red Wins, +60 s, Final Showdown, Shrink Storm Now, Rebuild Towers and Collapse Tower all work, and each shows feedback text.
- [ ] Fun tab: each event, Fireworks on/off, Give Everyone Bombs (3 bombs, the first one Mega), Spawn Bomb for Everyone and Heal Everyone.
- [ ] Players tab: cycle the target, give the Rocket Launcher and fire it, toggle God Mode, and teleport.
- [ ] Modes tab: pick a mode. It's highlighted, and the lobby card shows it for the next match.

## 4. Mobile emulation (Test → Device → a phone)

- [ ] The HUD scales down and nothing sits under the thumbstick or jump button.
- [ ] Hold-and-release on the screen throws a bomb where you aimed.
- [ ] Spectator arrows work by touch.
