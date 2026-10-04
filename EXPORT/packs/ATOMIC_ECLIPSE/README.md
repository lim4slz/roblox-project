# ATOMIC ECLIPSE

32-second anime finisher for Roblox R15: shadow walk, energy charge, a violet nuke and a calm recovery.
Hand-keyed at 60 fps, 1523 keyframes, 44 named markers for syncing effects and sound.

## What's inside

| File | What it is |
|---|---|
| `ATOMIC_ECLIPSE_Animation.rbxm` | Animation only (KeyframeSequence). Standard R15 joints, no sword, no effects. |
| `ATOMIC_ECLIPSE_Animation_Sword.rbxm` | Same animation with the sword joint + the sword model and a script that puts it in the right hand. |
| `ATOMIC_ECLIPSE_Full.rbxm` | Complete ability: animation, all visual effects, sword, scarf, damage, knockback, cooldown, keybind. |
| `ATOMIC_ECLIPSE_preview.mp4` | Preview video. |

Requirements: R15 avatars (Game Settings > Avatar > R15).

## Animation only

1. Drag `ATOMIC_ECLIPSE_Animation.rbxm` into Studio.
2. Right click the KeyframeSequence > **Save to Roblox** (or open it in the Animation Editor and Publish). Publish it on the account or group that owns your game.
3. Play it with the ID you got:

```lua
local animation = Instance.new("Animation")
animation.AnimationId = "rbxassetid://YOUR_ID"
local track = humanoid:WaitForChild("Animator"):LoadAnimation(animation)
track:Play()
```

Markers can be read with `track:GetMarkerReachedSignal("NUKE"):Connect(...)`. Names: CAST_START, AWAKEN, CHARGE_PEAK, IMPLODE, NUKE, SHOCKWAVE, RECOVERY, END and others.

## Animation + sword

1. Drag `ATOMIC_ECLIPSE_Animation_Sword.rbxm` into Studio. You get a folder `ATOMIC_ECLIPSE_Sword` with two things:
   - `ATOMIC_ECLIPSE` (KeyframeSequence): publish it like above.
   - `AttachSword` (Script): move it to **ServerScriptService**. Every R15 character gets the sword in the right hand.
2. Keep the names `EmberBlade` and `EmberBladeGrip`. The animation moves that joint by name.

The sword has a Trail (`BladeTrail`) that starts disabled. Turn it on with `Enabled = true` if you want a trail.

In the full ability the sword dissolves into light during the release. Here it stays visible; to hide it, set the sword parts' `Transparency` to 1 on the `BLADE_DISSOLVE` marker and back to 0 on `BLADE_REFORM`.

## Full ability

1. Drag `ATOMIC_ECLIPSE_Full.rbxm` into Studio and move each folder to the service with the same name:
   - `Ember` > ReplicatedStorage
   - `EmberServer` > ServerScriptService
   - `EmberClient` > StarterPlayerScripts
2. Press Play and press **1**. Inside Studio it works right away, without publishing.
3. For a live game: publish `Ember/KeyframeSequences/ANIM_01_ATOMIC_ECLIPSE` and paste the ID in `Ember/Assets` (`Animations.ANIM_01_ATOMIC_ECLIPSE`).
4. Damage, knockback, cooldown and key are in `Ember/Config`.

The effects are all code (Parts, Beams, Lights, ColorCorrection). No textures or meshes to upload. Quality scales down with the player's graphics setting.

---

# ATOMIC ECLIPSE (PT-BR)

Finalização de anime de 32 segundos para Roblox R15, feita à mão a 60 fps, com 44 markers.

- **Só a animação:** `ATOMIC_ECLIPSE_Animation.rbxm`. Arraste pro Studio, publique (Save to Roblox) na conta ou grupo dono do jogo e toque com o ID.
- **Animação + espada:** `ATOMIC_ECLIPSE_Animation_Sword.rbxm`. Publique o KeyframeSequence e coloque o script `AttachSword` em ServerScriptService. Não mude os nomes `EmberBlade` e `EmberBladeGrip`.
- **Habilidade completa:** `ATOMIC_ECLIPSE_Full.rbxm`. `Ember` vai em ReplicatedStorage, `EmberServer` em ServerScriptService e `EmberClient` em StarterPlayerScripts. No Studio aperte Play e **1**. Em jogo publicado, publique o KeyframeSequence e cole o ID em `Ember/Assets`. Ajustes em `Ember/Config`.

Precisa de avatar R15.
