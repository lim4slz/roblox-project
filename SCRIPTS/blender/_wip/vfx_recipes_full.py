"""
Single source of truth for the VFX of the five abilities.

Each cue fires at  marker_frame + offset  (60 fps). The SAME data drives:
  * the Blender previs (SCRIPTS/blender/vfx_previs.py) - timing/composition
  * the Roblox runtime (generated ROBLOX/.../AbilityData/*.luau, executed by
    VFXCore.luau with native ParticleEmitter / Beam / Trail / Attachment /
    PointLight / Highlight / ColorCorrection instances)

Units: studs, seconds, Color3 0-255. Anchors are resolved at runtime:
  blade_tip, blade_base, grip, RightHand, LeftHand, Head, UpperTorso,
  LowerTorso, LeftFoot, RightFoot, feet (ground below root), root,
  impact (blade tip projected on the ground), ahead:N (ground N studs in
  front), sky:N (N studs above root), chest_ahead:N, beam_end.

Every cue declares a `layer` (primary / secondary / tertiary) so the
runtime quality manager can drop tertiary layers first on low-end devices.
"""

PALETTE = {
    "CORE": (255, 248, 230),
    "GOLD": (255, 196, 64),
    "EMBER": (255, 120, 24),
    "CRIMSON": (214, 38, 30),
    "VIOLET": (150, 70, 255),
    "VOID": (60, 16, 110),
    "ASH": (46, 40, 44),
    "INK": (8, 6, 10),
    "WHITE": (255, 255, 255),
    "AZURE": (70, 160, 255),
    "CYAN": (130, 235, 255),
    "ELECTRIC": (150, 200, 255),
    "STORM": (40, 40, 70),
    "WIND": (200, 240, 255),
    "BLUEFLAME": (120, 120, 255),
}


def cue(marker, fx, anchor=None, offset=0, layer="primary", when=None, **params):
    return {"marker": marker, "offset": offset, "fx": fx, "anchor": anchor, "layer": layer, "when": when,
            "params": params}


# --------------------------------------------------------------------------
# ANIM_01 — ATOMIC ECLIPSE (inspired by "I Am Atomic")
# --------------------------------------------------------------------------
ATOMIC_ECLIPSE = [
    cue("CAST_START", "screen", None, kind="dim", brightness=-0.04, saturation=-0.05, dur=2.0, tint="VIOLET"),
    cue("CIRCUITS_START", "circuits", "character", count=6, color="VIOLET", dur_until="IMPLODE"),
    cue("STEP_SIGIL", "step_sigil", "feet", color="VIOLET"),
    cue("AWAKEN", "flash", "Head", color="VIOLET", size0=0.3, size1=2.2, dur=0.2),
    cue("AWAKEN", "ring", "feet", color="VIOLET", r0=0.5, r1=6.0, w0=0.6, w1=0.05, dur=0.5, orient="ground"),
    cue("AWAKEN", "highlight", "character", color="VIOLET", fill=0.9, dur_until="RELEASE"),
    cue("CONVERGE", "converge", "chest", radius=40.0, count=1600, color="VIOLET", dur_until="IMPLODE"),
    cue("SIGIL_GROUND", "sigil", "feet", when="1", radius=8.0, color="VIOLET", spin=24, spokes=12, rings=3,
        dur_until="RELEASE", implode_at="IMPLODE"),
    cue("SIGIL_GROUND", "sigil", "feet", when="2", radius=14.0, color="CORE", spin=-14, spokes=16, rings=2,
        dur_until="RELEASE", implode_at="IMPLODE"),
    cue("SIGIL_GROUND", "sigil", "feet", when="3", radius=20.0, color="VIOLET", spin=9, spokes=24, rings=3,
        dur_until="RELEASE", implode_at="IMPLODE"),
    cue("DIM", "screen", None, kind="dim", brightness=-0.15, saturation=-0.2, dur=4.0, tint="VIOLET"),
    cue("LEVITATE", "ring", "feet", color="CORE", color2="VIOLET", r0=1.0, r1=9.0, w0=0.8, w1=0.05, dur=0.6,
        orient="ground"),
    cue("LEVITATE", "burst", "feet", template="dust", count=18, layer="secondary"),
    cue("HALO", "halo", "UpperTorso", radius=3.6, color="VIOLET", dur_until="IMPLODE"),
    cue("HELIX", "helix", "character", count=3, radius=3.2, height=7.5, color="VIOLET", dur_until="IMPLODE"),
    cue("ORBS", "orbs", "chest", count=6, radius=4.2, color="CORE", dur_until="IMPLODE"),
    cue("CHARGE_PEAK", "flash", "hands", color="CORE", color2="VIOLET", size0=0.5, size1=4.0, dur=0.2),
    cue("CHARGE_PEAK", "shake", None, amp=0.35, dur=0.6, freq=26),
    cue("IMPLODE", "ring", "hands", color="CORE", color2="VIOLET", r0=22.0, r1=0.2, w0=0.4, w1=1.2, dur=0.2,
        orient="ground"),
    cue("IMPLODE", "screen", None, kind="dim", brightness=-0.42, saturation=-0.3, dur=0.2),
    cue("SILENCE", "point", "hands", dur_until="RELEASE"),
    cue("POINT_PULSE", "ring", "hands", color="CORE", r0=0.3, r1=3.5, w0=0.3, w1=0.02, dur=0.3, orient="facing"),
    cue("RELEASE", "screen", None, kind="white"),
    cue("RELEASE", "shake", None, amp=3.5, dur=2.2, freq=18),
    cue("RELEASE", "fov", None, delta=12, dur=0.8),
    cue("NUKE", "nuke", "hands", radius=60.0, grow=1.5, hold=1.2, fade=2.5),
    cue("SHOCKWAVE", "ring", "feet", when="1", color="CORE", r0=4.0, r1=80.0, w0=3.0, w1=0.4, dur=1.0,
        orient="ground"),
    cue("SHOCKWAVE", "ring", "feet", when="2", color="VIOLET", r0=4.0, r1=100.0, w0=2.4, w1=0.3, dur=1.3,
        orient="ground"),
    cue("SHOCKWAVE", "ring", "feet", when="3", color="CRIMSON", r0=4.0, r1=120.0, w0=1.8, w1=0.2, dur=1.6,
        orient="ground"),
    cue("DUST_WALL", "dust_wall", "feet", radius=70.0, dur=3.0),
    cue("DEBRIS", "debris", "feet", count=60, speed=45.0, dur=2.4),
    cue("COLUMN", "column", "feet", height=90.0, radius=6.0, color="VIOLET", dur=4.5),
    cue("MUSHROOM", "mushroom", "feet", height=80.0, radius=38.0, dur=6.0),
    cue("ASH_FALL", "ash", "feet", radius=60.0, count=2500, dur=6.0),
    cue("SCREEN_RESTORE", "screen", None, kind="restore", dur=2.5),
    cue("LAND", "ring", "feet", color="ASH", r0=0.5, r1=4.0, w0=0.4, w1=0.05, dur=0.4, orient="ground",
        layer="secondary"),
    cue("FLICK", "burst", "blade_tip", template="embers_dir", count=24, color="VIOLET", dir="blade_swing"),
]


# --------------------------------------------------------------------------
# ANIM_01 — SOLAR CLEAVER : gold/ember, one devastating impact
# --------------------------------------------------------------------------
SOLAR_CLEAVER = [
    # blade ignition (persistent until END)
    cue("CAST_START", "blade_aura", "blade_tip", color="GOLD", color2="EMBER", dur_until="DISSIPATE", rate=26),
    cue("CAST_START", "light", "blade_base", color="EMBER", range=10, brightness=2.5, dur=0.25, layer="secondary"),
    cue("TRAIL_START", "trail", "blade", on=True, color="CORE", color2="EMBER", color3="CRIMSON", lifetime=0.2),
    cue("TRAIL_END", "trail", "blade", on=False),
    # anticipation readability
    cue("CHARGE_PEAK", "flash", "blade_tip", color="CORE", color2="GOLD", size0=0.4, size1=3.2, dur=0.18),
    cue("CHARGE_PEAK", "burst", "blade_tip", template="gather", count=26, color="GOLD", layer="secondary"),
    cue("CHARGE_PEAK", "ring", "feet", color="GOLD", color2="EMBER", r0=0.8, r1=4.0, w0=0.6, w1=0.05, dur=0.3,
        orient="ground", layer="secondary"),
    cue("LEAP", "burst", "feet", template="dust", count=14, layer="secondary"),
    cue("LEAP", "ring", "feet", color="ASH", color2="ASH", r0=1.0, r1=5.0, w0=0.8, w1=0.1, dur=0.3, orient="ground",
        layer="secondary"),
    # IMPACT — primary hierarchy
    cue("IMPACT", "flash", "impact", color="CORE", color2="GOLD", size0=1.0, size1=9.0, dur=0.16,
        light_range=40, light_brightness=8),
    cue("IMPACT", "screen", None, kind="flash", brightness=0.35, contrast=0.3, saturation=0.25, dur=0.14),
    cue("IMPACT", "shake", None, amp=1.2, dur=0.45, freq=22),
    cue("IMPACT", "fov", None, delta=6, dur=0.25),
    cue("IMPACT", "slash_arc", "impact", plane="swing_vertical", radius=5.5, arc_deg=150, start_deg=-20,
        thickness=1.6, color="CORE", color2="GOLD", dur=0.22, linger=0.05),
    cue("IMPACT", "burst", "impact", template="sparks", count=60, color="GOLD", speed=(40, 75), spread=75),
    cue("IMPACT", "burst", "impact", template="embers", count=40, color="EMBER", layer="secondary"),
    cue("IMPACT", "crack", "impact", count=7, length=(4.0, 10.0), width=0.35, color="EMBER", color2="CRIMSON",
        grow=0.15, hold=1.2, fade=0.6, bias_forward=0.7),
    cue("SHOCKWAVE", "ring", "impact", color="GOLD", color2="CRIMSON", r0=2.0, r1=18.0, w0=2.5, w1=0.4, dur=0.36,
        orient="ground"),
    cue("SHOCKWAVE", "ring", "impact", color="WHITE", color2="GOLD", r0=1.0, r1=12.0, w0=0.6, w1=0.05, dur=0.22,
        orient="ground", layer="secondary"),
    cue("SHOCKWAVE", "burst", "impact", template="dust_ring", count=24, layer="secondary"),
    cue("DEBRIS", "debris", "impact", count=10, speed=(18, 34), up=(18, 36), size=(0.4, 1.1), dur=1.0),
    cue("DEBRIS", "burst", "impact", template="smoke", count=20, color="ASH", layer="tertiary"),
    cue("SECONDARY_BURST", "flame_jets", "impact", count=4, height=(4.0, 6.5), dur=0.45, color="EMBER", color2="GOLD"),
    cue("SECONDARY_BURST", "burst", "impact", template="embers", count=30, color="GOLD", layer="secondary"),
    cue("SECONDARY_BURST", "light", "impact", color="EMBER", range=24, brightness=4, dur=0.5, flicker=True,
        layer="secondary"),
    cue("FLICK", "burst", "blade_tip", template="embers_dir", count=30, color="GOLD", dir="blade_swing"),
    cue("DISSIPATE", "stream", "impact", template="smoke_wisp", rate=10, dur=1.0, layer="tertiary"),
]

# --------------------------------------------------------------------------
# ANIM_02 — VOID SUN BURST : charge -> implosion -> beam -> detonation
# --------------------------------------------------------------------------
VOID_SUN_BURST = [
    cue("CAST_START", "sigil", "feet", radius=5.0, color="VIOLET", color2="GOLD", spin=40, dur_until="DISSIPATE",
        rings=2, spokes=8),
    cue("CHARGE_START", "orb", "LeftHand", size0=0.35, size1=1.4, grow_until="CHARGE_PEAK", dur_until="COMPRESS",
        core="CORE", shell="VIOLET", rim="GOLD", light_range=16),
    cue("CHARGE_START", "stream", "LeftHand", template="inward", rate=40, dur_until="COMPRESS", color="VIOLET",
        radius=4.0),
    cue("CHARGE_START", "highlight", "character", color="VIOLET", fill=0.88, dur_until="DISSIPATE"),
    cue("CHARGE_STAGE", "ring", "LeftHand", color="VIOLET", color2="GOLD", r0=0.6, r1=3.5, w0=0.4, w1=0.05,
        dur=0.25, orient="random", layer="secondary"),
    cue("CHARGE_STAGE", "levitate", "feet", count=6, radius=(2.0, 4.5), rise=(1.5, 3.5), dur_until="RELEASE",
        layer="tertiary"),
    cue("CHARGE_STAGE", "arcs", "LeftHand", count=3, radius=2.2, dur=0.4, color="VIOLET", color2="CORE",
        layer="secondary"),
    cue("CHARGE_PEAK", "flash", "LeftHand", color="CORE", color2="VIOLET", size0=0.5, size1=3.5, dur=0.2),
    cue("CHARGE_PEAK", "shake", None, amp=0.25, dur=0.25, freq=30),
    cue("COMPRESS", "ring", "LeftHand", color="GOLD", color2="VIOLET", r0=8.0, r1=0.4, w0=0.2, w1=0.8, dur=0.1,
        orient="facing"),
    cue("COMPRESS", "screen", None, kind="dim", brightness=-0.12, saturation=-0.25, dur=0.1, hold=0.1),
    # release
    cue("RELEASE", "beam", "LeftHand", length=60, width=6.0, dur_until="DISSIPATE", core="CORE", shell="VIOLET",
        rim="GOLD", grow=0.06),
    cue("RELEASE", "flash", "LeftHand", color="CORE", color2="VIOLET", size0=0.8, size1=6.0, dur=0.12,
        light_range=30, light_brightness=6),
    cue("RELEASE", "ring", "LeftHand", color="VIOLET", color2="GOLD", r0=1.0, r1=8.0, w0=1.2, w1=0.1, dur=0.25,
        orient="facing"),
    cue("RELEASE", "screen", None, kind="tint", color="VIOLET", brightness=0.2, contrast=0.2, dur=0.12),
    cue("RELEASE", "shake", None, amp=1.0, dur=0.3, freq=24),
    cue("RELEASE", "fov", None, delta=8, dur=0.3),
    cue("STOMP", "ring", "LeftFoot", color="ASH", color2="ASH", r0=0.6, r1=7.0, w0=0.8, w1=0.1, dur=0.3,
        orient="ground", layer="secondary"),
    cue("STOMP", "burst", "LeftFoot", template="dust", count=12, layer="secondary"),
    cue("BEAM_PEAK", "beam_rings", "LeftHand", count=3, interval=0.1, speed=90, radius=3.5, color="GOLD",
        layer="secondary"),
    cue("BEAM_PEAK", "shake", None, amp=0.4, dur=0.6, freq=26, layer="secondary"),
    cue("SECONDARY_BURST", "flash", "beam_end", color="CORE", color2="VIOLET", size0=2.0, size1=14.0, dur=0.2,
        light_range=50, light_brightness=8),
    cue("SECONDARY_BURST", "ring", "beam_end", color="VIOLET", color2="GOLD", r0=2.0, r1=22.0, w0=2.5, w1=0.3,
        dur=0.4, orient="ground"),
    cue("SECONDARY_BURST", "burst", "beam_end", template="void_sparks", count=80, color="VIOLET", speed=(35, 70)),
    cue("SECONDARY_BURST", "burst", "beam_end", template="smoke", count=30, color="VOID", layer="tertiary"),
    cue("SECONDARY_BURST", "debris", "beam_end", count=8, speed=(14, 28), up=(16, 30), size=(0.4, 1.0), dur=1.0,
        layer="secondary"),
    cue("DISSIPATE", "stream", "LeftHand", template="smoke_wisp", rate=12, dur=0.8, color="VOID",
        layer="tertiary"),
    cue("HAND_SHAKE", "burst", "LeftHand", template="embers_dir", count=20, color="VIOLET", dir="down"),
]

# --------------------------------------------------------------------------
# ANIM_03 — ASHSTEP DASH : speed, afterimages, a single clean cut line
# --------------------------------------------------------------------------
ASHSTEP_DASH = [
    cue("CAST_START", "burst", "feet", template="dust", count=8, layer="secondary"),
    cue("DASH_START", "ring", "feet", color="ASH", color2="EMBER", r0=1.0, r1=8.0, w0=1.0, w1=0.1, dur=0.25,
        orient="ground"),
    cue("DASH_START", "ring", "UpperTorso", color="CORE", color2="EMBER", r0=1.0, r1=5.0, w0=0.6, w1=0.05,
        dur=0.18, orient="facing"),
    cue("DASH_START", "flash", "UpperTorso", color="CORE", color2="EMBER", size0=0.6, size1=4.0, dur=0.1),
    cue("DASH_START", "burst", "feet", template="dust", count=18),
    cue("DASH_START", "shake", None, amp=0.5, dur=0.2, freq=26),
    cue("DASH_START", "fov", None, delta=12, dur=0.45),
    cue("TRAIL_START", "trail", "body", on=True, color="CORE", color2="EMBER", color3="ASH", lifetime=0.35),
    cue("TRAIL_START", "stream", "UpperTorso", template="embers", rate=90, dur_until="TRAIL_END", color="EMBER"),
    cue("TRAIL_START", "stream", "UpperTorso", template="speedlines", rate=60, dur_until="SKID", color="CORE",
        layer="secondary"),
    cue("TRAIL_END", "trail", "body", on=False),
    cue("AFTERIMAGE", "afterimage", "character", color="EMBER", color2="VIOLET", dur=0.35, transparency=0.35),
    cue("SLASH", "trail", "blade", on=True, color="CORE", color2="CRIMSON", color3="VIOLET", lifetime=0.16,
        offset=-3),
    cue("SLASH", "trail", "blade", on=False, offset=6),
    cue("SLASH", "slash_arc", "UpperTorso", plane="horizontal", radius=5.0, arc_deg=170, start_deg=60,
        thickness=1.2, color="CORE", color2="CRIMSON", dur=0.2, linger=0.05),
    cue("SLASH", "cut_line", "chest_ahead:0", length=26, color="WHITE", color2="CRIMSON", dur=0.35, back=True),
    cue("SLASH", "burst", "blade_tip", template="sparks", count=40, color="CRIMSON", speed=(30, 60), spread=50),
    cue("SLASH", "shake", None, amp=0.7, dur=0.25, freq=24),
    cue("SLASH", "cut_detonate", "chest_ahead:0", offset=5, length=26, color="CRIMSON", color2="VIOLET",
        count=6, back=True),
    cue("SKID", "stream", "feet", template="dust", rate=40, dur=0.2),
    cue("SKID", "scorch", "feet", length=5.0, width=1.6, dur=1.6, back=True, layer="secondary"),
    cue("SKID", "burst", "feet", template="sparks", count=16, color="EMBER", speed=(10, 25), spread=40,
        layer="secondary"),
    cue("FLOURISH", "trail", "blade", on=True, color="GOLD", color2="EMBER", color3="ASH", lifetime=0.12),
    cue("FLOURISH", "trail", "blade", on=False, offset=14),
    cue("FLOURISH", "ring", "grip", color="EMBER", color2="GOLD", r0=0.5, r1=5.0, w0=0.4, w1=0.05, dur=0.3,
        orient="ground", layer="secondary"),
]

# --------------------------------------------------------------------------
# ANIM_04 — CINDER CATACLYSM : ultimate, world-scale composition
# --------------------------------------------------------------------------
CINDER_CATACLYSM = [
    cue("CAST_START", "screen", None, kind="dim", brightness=-0.15, saturation=-0.3, dur=0.6, hold_until="IMPACT"),
    cue("CAST_START", "blade_aura", "blade_tip", color="GOLD", color2="EMBER", dur_until="RECOVERY", rate=30),
    cue("SIGIL_GROUND", "sigil", "feet", radius=12.0, color="GOLD", color2="CRIMSON", spin=25,
        dur_until="IMPACT", rings=3, spokes=12),
    cue("SIGIL_GROUND", "shake", None, amp=0.15, dur=2.6, freq=18, layer="secondary"),
    cue("ASCEND", "stream", "feet", template="updraft", rate=45, dur_until="DIVE", color="EMBER", radius=6.0),
    cue("ASCEND", "levitate", "feet", count=14, radius=(3.0, 9.0), rise=(2.0, 7.0), dur_until="IMPACT"),
    cue("ASCEND", "ring", "feet", color="GOLD", color2="EMBER", r0=1.0, r1=9.0, w0=1.0, w1=0.1, dur=0.4,
        orient="ground"),
    cue("SKY_SIGIL", "sky_rings", "sky:18", count=3, spacing=4.0, radius=(6.0, 12.0), color="GOLD",
        color2="VIOLET", spin=35, dur_until="COMPRESS"),
    cue("CHARGE_START", "streams_to", "blade_tip", source="sky_rings", count=6, color="GOLD", dur_until="COMPRESS"),
    cue("CHARGE_START", "highlight", "character", color="GOLD", fill=0.9, dur_until="RECOVERY"),
    cue("SUN_FORM", "sun", "blade_tip", height=6.0, r0=1.0, r1=5.0, grow=0.4, dur_until="COMPRESS",
        core="CORE", inner="GOLD", outer="EMBER", light_range=60),
    cue("SUN_GROW", "sun_grow", "blade_tip", r1=12.0, grow=0.5),
    cue("SUN_GROW", "shake", None, amp=0.35, dur=0.6, freq=20, layer="secondary"),
    cue("CHARGE_PEAK", "flash", "sun", color="CORE", color2="GOLD", size0=8.0, size1=26.0, dur=0.25),
    cue("CHARGE_PEAK", "starburst", "sun", color="CORE", size=30, dur=0.3, layer="secondary"),
    cue("REVERSE_GRIP", "flash", "grip", color="CORE", color2="GOLD", size0=0.4, size1=3.0, dur=0.12,
        layer="secondary"),
    cue("COMPRESS", "sun_collapse", "blade_tip", dur=0.12),
    cue("COMPRESS", "screen", None, kind="dim", brightness=-0.32, saturation=-0.5, dur=0.1, hold=0.15),
    cue("DIVE", "trail", "blade", on=True, color="CORE", color2="GOLD", color3="CRIMSON", lifetime=0.25),
    cue("DIVE", "stream", "UpperTorso", template="speedlines", rate=80, dur=0.17, color="CORE", layer="secondary"),
    cue("IMPACT", "screen", None, kind="flash", brightness=1.0, contrast=0.4, saturation=0.3, dur=0.3),
    cue("IMPACT", "screen", None, kind="restore", dur=1.2, offset=40),
    cue("IMPACT", "shake", None, amp=3.0, dur=0.85, freq=20),
    cue("IMPACT", "fov", None, delta=10, dur=0.4),
    cue("IMPACT", "trail", "blade", on=False, offset=4),
    cue("PILLAR", "pillar", "impact", color="EMBER", color2="CORE", r0=4.0, r1=7.0, height=60, rise=0.15,
        hold=0.5, fade=0.6),
    cue("PILLAR", "stream", "impact", template="spiral_up", rate=80, dur=1.0, color="GOLD"),
    cue("PILLAR", "light", "impact", color="EMBER", range=60, brightness=10, dur=1.2),
    cue("SHOCKWAVE", "ring", "impact", color="GOLD", color2="CRIMSON", r0=3.0, r1=40.0, w0=4.0, w1=0.6, dur=0.5,
        orient="ground"),
    cue("SHOCKWAVE", "dome", "impact", color="CORE", color2="EMBER", r0=2.0, r1=25.0, dur=0.4),
    cue("DEBRIS", "debris", "impact", count=24, speed=(24, 50), up=(30, 60), size=(0.6, 1.8), dur=1.6),
    cue("DEBRIS", "burst", "impact", template="dust_ring", count=40),
    cue("DEBRIS", "crack", "impact", count=12, length=(10.0, 25.0), width=0.5, color="EMBER", color2="CRIMSON",
        grow=0.25, hold=2.5, fade=1.0, bias_forward=0.0),
    cue("SHOCKWAVE_2", "ring", "impact", color="VIOLET", color2="CRIMSON", r0=2.0, r1=55.0, w0=1.6, w1=0.2,
        dur=0.6, orient="ground"),
    cue("SHOCKWAVE_2", "scorch", "impact", radius=14.0, dur=4.0, layer="secondary"),
    cue("EMBER_RAIN", "rain", "impact", radius=30, height=40, rate=120, dur=1.5, color="EMBER"),
    cue("DISSIPATE", "stream", "impact", template="smoke_column", rate=14, dur=1.5, color="ASH",
        layer="tertiary"),
    cue("REGRIP", "trail", "blade", on=True, color="GOLD", color2="EMBER", color3="ASH", lifetime=0.12),
    cue("REGRIP", "trail", "blade", on=False, offset=12),
    cue("REGRIP", "ring", "grip", color="EMBER", color2="GOLD", r0=0.5, r1=5.0, w0=0.4, w1=0.05, dur=0.3,
        orient="ground", layer="secondary"),
]

# --------------------------------------------------------------------------
# ANIM_05 — EIGHTFOLD EXECUTION : crimson/void, three stages, delayed X
# --------------------------------------------------------------------------
EIGHTFOLD_EXECUTION = [
    cue("CAST_START", "blade_aura", "blade_tip", color="CRIMSON", color2="VIOLET", dur_until="RECOVERY", rate=24),
    cue("CAST_START", "highlight", "character", color="CRIMSON", fill=0.92, dur_until="RECOVERY"),
    # S1
    cue("TRAIL_START", "trail", "blade", on=True, color="CORE", color2="CRIMSON", color3="VIOLET", lifetime=0.18),
    cue("STAGE_1_END", "trail", "blade", on=False),
    cue("HIT_1", "slash_wave", "UpperTorso", plane="horizontal", radius=4.5, arc_deg=150, thickness=1.0,
        color="CORE", color2="CRIMSON", speed=60, travel=20, dur=0.35),
    cue("HIT_1", "burst", "blade_tip", template="sparks", count=30, color="CRIMSON", speed=(30, 55), spread=60),
    cue("HIT_1", "shake", None, amp=0.5, dur=0.18, freq=26),
    cue("STAGE_1_END", "burst", "blade_tip", template="embers_dir", count=12, color="CRIMSON", dir="blade_swing",
        layer="tertiary"),
    # S2
    cue("TRAIL_START", "trail", "blade", on=True, color="CORE", color2="VIOLET", color3="CRIMSON", lifetime=0.22),
    cue("HIT_2", "spiral_slash", "root", count=3, radius=4.0, height=(0.0, 4.5), color="CORE", color2="VIOLET",
        dur=0.3),
    cue("HIT_2", "stream", "feet", template="updraft", rate=60, dur=0.4, color="CRIMSON", radius=3.0),
    cue("HIT_2", "shake", None, amp=0.6, dur=0.25, freq=24),
    cue("LAND", "ring", "feet", color="ASH", color2="CRIMSON", r0=1.0, r1=7.0, w0=0.8, w1=0.1, dur=0.3,
        orient="ground"),
    cue("LAND", "burst", "feet", template="dust", count=14, layer="secondary"),
    cue("TRAIL_END", "trail", "blade", on=False),
    # S3
    cue("TRAIL_START", "trail", "blade", on=True, color="CORE", color2="CRIMSON", color3="VIOLET", lifetime=0.2),
    cue("TRAIL_END", "trail", "blade", on=False),
    cue("LEAP", "burst", "feet", template="dust", count=16),
    cue("LEAP", "ring", "feet", color="CRIMSON", color2="ASH", r0=1.0, r1=6.0, w0=0.8, w1=0.1, dur=0.3,
        orient="ground", layer="secondary"),
    cue("HIT_3A", "x_slash", "chest_ahead:3", index=1, plane="diag_a", radius=6.5, thickness=1.5, color="CORE",
        color2="CRIMSON", linger_until="X_DETONATE"),
    cue("HIT_3A", "burst", "blade_tip", template="sparks", count=28, color="CRIMSON", speed=(30, 55), spread=60),
    cue("HIT_3A", "shake", None, amp=0.5, dur=0.15, freq=28),
    cue("HIT_3B", "x_slash", "chest_ahead:3", index=2, plane="diag_b", radius=6.5, thickness=1.5, color="CORE",
        color2="VIOLET", linger_until="X_DETONATE"),
    cue("HIT_3B", "burst", "blade_tip", template="sparks", count=28, color="VIOLET", speed=(30, 55), spread=60),
    cue("HIT_3B", "shake", None, amp=0.6, dur=0.15, freq=28),
    cue("FINAL_IMPACT", "ring", "impact", color="CRIMSON", color2="VIOLET", r0=1.0, r1=10.0, w0=1.2, w1=0.1,
        dur=0.3, orient="ground"),
    cue("FINAL_IMPACT", "crack", "impact", count=5, length=(3.0, 7.0), width=0.3, color="CRIMSON", color2="VIOLET",
        grow=0.12, hold=1.4, fade=0.6, bias_forward=0.0),
    cue("FINAL_IMPACT", "burst", "impact", template="sparks", count=30, color="CRIMSON", speed=(25, 45), spread=80),
    cue("FINAL_IMPACT", "shake", None, amp=0.8, dur=0.25, freq=24),
    cue("X_DETONATE", "x_detonate", "chest_ahead:3", color="CORE", color2="CRIMSON", color3="VIOLET", count=100),
    cue("X_DETONATE", "flash", "chest_ahead:3", color="CORE", color2="CRIMSON", size0=2.0, size1=16.0, dur=0.2,
        light_range=50, light_brightness=8),
    cue("X_DETONATE", "ring", "chest_ahead:3", color="CRIMSON", color2="VIOLET", r0=2.0, r1=20.0, w0=2.0, w1=0.2,
        dur=0.4, orient="facing_back"),
    cue("X_DETONATE", "screen", None, kind="tint", color="CRIMSON", brightness=0.25, contrast=0.25, dur=0.16),
    cue("X_DETONATE", "shake", None, amp=1.5, dur=0.5, freq=22),
    cue("X_DETONATE", "burst", "chest_ahead:3", template="smoke", count=24, color="ASH", layer="tertiary"),
    cue("EXECUTION_POSE", "burst", "blade_tip", template="embers_dir", count=18, color="CRIMSON",
        dir="blade_swing", layer="secondary"),
]

# --------------------------------------------------------------------------
# ANIM_02 — STARBURST REQUIEM (inspired by Starburst Stream)
# --------------------------------------------------------------------------
STARBURST_REQUIEM = [
    cue("CAST_START", "blade_aura", "blade_tip", color="GOLD", color2="CORE", dur_until="END", rate=18),
    cue("MATERIALIZE", "materialize", "LeftHand", blade="AzureBlade", color="AZURE", color2="CYAN"),
    cue("DRAW_FLASH", "flash", "LeftHand", color="CYAN", size0=0.4, size1=3.0, dur=0.15),
    cue("SKILL_ACTIVATE", "flash", "blade_tip", color="CORE", size0=0.5, size1=4.0, dur=0.2),
    cue("SKILL_ACTIVATE", "flash", "blade_l_tip", color="CYAN", size0=0.5, size1=4.0, dur=0.2),
    cue("SKILL_ACTIVATE", "ring", "feet", color="AZURE", r0=1.0, r1=10.0, w0=1.0, w1=0.05, dur=0.5,
        orient="ground"),
    cue("SKILL_ACTIVATE", "highlight", "character", color="AZURE", fill=0.9, dur_until="END"),
    cue("SKILL_ACTIVATE", "screen", None, kind="tint", color="AZURE", brightness=0.12, contrast=0.1, dur=0.2),
    cue("SKILL_ACTIVATE", "blade_aura", "blade_l_tip", color="CYAN", color2="AZURE", dur_until="DEMATERIALIZE",
        rate=18),
    cue("STREAM_START", "shake", None, amp=0.4, dur=0.2, freq=26),
    cue("TRAIL_START", "trail", "blade", when="blade", on=True, color="CORE", color2="GOLD", color3="AZURE",
        lifetime=0.16),
    cue("TRAIL_END", "trail", "blade", when="blade", on=False),
    cue("TRAIL_START", "trail", "blade_l", when="blade_l", on=True, color="CORE", color2="CYAN", color3="AZURE",
        lifetime=0.16),
    cue("TRAIL_END", "trail", "blade_l", when="blade_l", on=False),
    cue("HIT", "slash_hit", "blade_tip", color="CORE", color2="CYAN", count=18),
    cue("HIT", "shake", None, amp=0.35, dur=0.12, freq=30, layer="secondary"),
    cue("AFTERIMAGE", "afterimage", "character", color="AZURE", color2="CYAN", dur=0.3, transparency=0.4),
    cue("FINAL_COIL", "converge", "blade_tip", radius=8.0, count=200, color="CYAN", dur=0.25),
    cue("STARBURST_FINAL", "flash", "blade_tip", color="CORE", color2="CYAN", size0=1.0, size1=12.0, dur=0.25,
        light_range=40, light_brightness=8),
    cue("STARBURST_FINAL", "starburst", "blade_tip", color="CYAN", size=22, dur=0.35),
    cue("STARBURST_FINAL", "thrust_rings", "blade_tip", count=4, color="AZURE", color2="CORE", length=24, dur=0.4),
    cue("STARBURST_FINAL", "burst", "blade_tip", template="sparks", count=120, color="CYAN", speed=(40, 80),
        spread=90),
    cue("STARBURST_FINAL", "screen", None, kind="flash", brightness=0.5, contrast=0.3, dur=0.18),
    cue("STARBURST_FINAL", "shake", None, amp=1.4, dur=0.5, freq=22),
    cue("SPIN_SLASH", "ring", "UpperTorso", color="CYAN", color2="CORE", r0=1.0, r1=7.0, w0=0.8, w1=0.05, dur=0.3,
        orient="ground"),
    cue("X_CROSS_IMPACT", "x_ground", "ahead:3", length=22, color="CYAN", color2="CORE", dur=1.4),
    cue("X_CROSS_IMPACT", "ring", "ahead:3", color="AZURE", r0=1.0, r1=16.0, w0=1.6, w1=0.1, dur=0.4,
        orient="ground"),
    cue("X_CROSS_IMPACT", "debris", "ahead:3", count=20, speed=26.0, dur=1.4),
    cue("X_CROSS_IMPACT", "shake", None, amp=1.2, dur=0.4, freq=24),
    cue("BLADE_SHED", "burst", "blade_tip", template="embers_dir", count=20, color="GOLD", dir="blade_swing"),
    cue("BLADE_SHED", "burst", "blade_l_tip", template="embers_dir", count=20, color="CYAN", dir="blade_swing"),
    cue("DEMATERIALIZE", "dematerialize", "LeftHand", blade="AzureBlade", color="CYAN"),
]

# --------------------------------------------------------------------------
# ANIM_03 — RAIJIN SPEAR (inspired by Chidori / Kirin)
# --------------------------------------------------------------------------
RAIJIN_SPEAR = [
    cue("LIGHTNING_FORM", "lightning_hand", "LeftHand", color="ELECTRIC", color2="CORE", dur_until="FIZZLE",
        light_range=16),
    cue("LIGHTNING_FORM", "flash", "LeftHand", color="CORE", color2="ELECTRIC", size0=0.4, size1=3.5, dur=0.15),
    cue("CHIRP", "bolts", "LeftHand", count=5, length=(2.0, 6.0), color="ELECTRIC", dur=0.18, to_ground=True),
    cue("GROUND_SCAR", "scar_path", "LeftHand", color="ELECTRIC", dur_until="LIGHTNING_PEAK", fade=1.5),
    cue("LIGHTNING_PEAK", "flash", "LeftHand", color="CORE", color2="ELECTRIC", size0=0.8, size1=6.0, dur=0.2,
        light_range=30, light_brightness=6),
    cue("LIGHTNING_PEAK", "ring", "feet", color="ELECTRIC", r0=1.0, r1=9.0, w0=0.8, w1=0.05, dur=0.4,
        orient="ground"),
    cue("LIGHTNING_PEAK", "shake", None, amp=0.6, dur=0.3, freq=30),
    cue("DASH_START", "ring", "feet", color="ELECTRIC", r0=1.0, r1=7.0, w0=0.8, w1=0.05, dur=0.25,
        orient="ground"),
    cue("DASH_START", "burst", "feet", template="dust", count=16, layer="secondary"),
    cue("TRAIL_START", "trail", "body", when="body", on=True, color="CORE", color2="ELECTRIC", color3="VIOLET",
        lifetime=0.3),
    cue("TRAIL_END", "trail", "body", when="body", on=False),
    cue("AFTERIMAGE", "afterimage", "character", color="ELECTRIC", color2="CORE", dur=0.25, transparency=0.4),
    cue("PIERCE", "bolts", "LeftHand", count=6, length=(4.0, 9.0), color="CORE", dur=0.15, forward=True),
    cue("PIERCE_BURST", "flash", "chest_ahead:2", color="CORE", color2="ELECTRIC", size0=1.0, size1=9.0, dur=0.18,
        light_range=30, light_brightness=6),
    cue("PIERCE_BURST", "bolts", "chest_ahead:2", count=10, length=(4.0, 10.0), color="ELECTRIC", dur=0.25),
    cue("PIERCE_BURST", "ring", "chest_ahead:2", color="ELECTRIC", r0=1.0, r1=10.0, w0=1.0, w1=0.05, dur=0.3,
        orient="facing"),
    cue("PIERCE_BURST", "shake", None, amp=0.9, dur=0.25, freq=28),
    cue("SKID", "stream", "feet", template="dust", rate=40, dur=0.2),
    cue("FIZZLE", "burst", "LeftHand", template="sparks", count=16, color="ELECTRIC", speed=(8, 20), spread=180),
    cue("STORM_CLOUDS", "storm_clouds", "sky:70", radius=70.0, color="STORM", dur_until="END"),
    cue("STORM_CLOUDS", "screen", None, kind="dim", brightness=-0.18, saturation=-0.2, dur=1.5, tint="STORM"),
    cue("CLOUD_FLASH", "cloud_flash", "sky:68", color="ELECTRIC", count=3, dur=0.2),
    cue("SKY_RAISE", "bolts", "LeftHand", count=1, length=(60.0, 60.0), color="CORE", dur=0.2, from_sky=True),
    cue("SKY_RAISE", "lightning_hand", "LeftHand", color="ELECTRIC", color2="CORE", dur_until="KIRIN_STRIKE",
        light_range=20),
    cue("DRAGON_DESCEND", "dragon", "ahead:30", color="ELECTRIC", color2="CORE", height=70.0, dur=1.0),
    cue("KIRIN_STRIKE", "screen", None, kind="white"),
    cue("KIRIN_STRIKE", "pillar", "ahead:30", color="ELECTRIC", color2="CORE", r0=3.0, r1=5.0, height=90, rise=0.05,
        hold=0.6, fade=0.8),
    cue("KIRIN_STRIKE", "flash", "ahead:30", color="CORE", color2="ELECTRIC", size0=2.0, size1=26.0, dur=0.3,
        light_range=80, light_brightness=12),
    cue("KIRIN_STRIKE", "bolts", "ahead:30", count=16, length=(8.0, 24.0), color="ELECTRIC", dur=0.4),
    cue("KIRIN_STRIKE", "shake", None, amp=3.0, dur=1.0, freq=22),
    cue("KIRIN_STRIKE", "fov", None, delta=10, dur=0.5),
    cue("IMPACT_FRAME", "screen", None, kind="invert", dur=0.05),
    cue("SHOCKWAVE", "ring", "ahead:30", when="kirin", color="CORE", r0=3.0, r1=50.0, w0=3.0, w1=0.3, dur=0.6,
        orient="ground"),
    cue("SHOCKWAVE", "ring", "ahead:30", when="kirin2", color="VIOLET", r0=3.0, r1=70.0, w0=2.0, w1=0.2, dur=0.8,
        orient="ground"),
    cue("DEBRIS", "debris", "ahead:30", when="kirin", count=40, speed=40.0, dur=2.0),
    cue("DEBRIS", "crack", "ahead:30", when="kirin", count=12, length=(8.0, 20.0), width=0.5, color="ELECTRIC",
        color2="VIOLET", grow=0.2, hold=2.0, fade=1.0, bias_forward=0.0),
    cue("SPARK_RESIDUE", "burst", "LeftHand", template="sparks", count=14, color="ELECTRIC", speed=(6, 16),
        spread=180),
]

# --------------------------------------------------------------------------
# ANIM_04 — SPIRAL TEMPEST (inspired by Rasengan / Rasenshuriken)
# --------------------------------------------------------------------------
SPIRAL_TEMPEST = [
    cue("CAST_START", "hide_blade", "character"),
    cue("SEAL", "ring", "hands", color="AZURE", r0=0.2, r1=1.6, w0=0.2, w1=0.02, dur=0.2, orient="facing",
        layer="secondary"),
    cue("SEAL_COMPLETE", "flash", "hands", color="CORE", color2="AZURE", size0=0.4, size1=3.0, dur=0.15),
    cue("AURA_BURST", "ring", "feet", color="AZURE", r0=1.0, r1=10.0, w0=1.0, w1=0.05, dur=0.5, orient="ground"),
    cue("AURA_BURST", "highlight", "character", color="AZURE", fill=0.9, dur_until="END"),
    cue("AURA_BURST", "column", "feet", height=14.0, radius=2.2, color="AZURE", dur=0.8),
    cue("SPHERE_FORM", "spiral_sphere", "LeftHand", r0=0.2, r1=0.9, grow=1.0, color="AZURE", color2="CYAN",
        dur_until="SPHERE_TRANSFER"),
    cue("SPHERE_TRANSFER", "spiral_sphere", "RightHand", r0=0.9, r1=1.1, grow=0.3, color="AZURE", color2="CYAN",
        dur_until="SPIRAL_BLAST"),
    cue("SPIRAL_IMPACT", "spiral_crater", "chest_ahead:1.5", radius=9.0, color="AZURE", color2="CYAN", dur=2.5),
    cue("SPIRAL_IMPACT", "flash", "chest_ahead:1.5", color="CORE", color2="CYAN", size0=1.0, size1=7.0, dur=0.18),
    cue("SPIRAL_IMPACT", "shake", None, amp=1.0, dur=0.6, freq=30),
    cue("SHOCKWAVE", "ring", "chest_ahead:1.5", when="spiral", color="CYAN", r0=1.0, r1=14.0, w0=1.2, w1=0.1,
        dur=0.4, orient="facing"),
    cue("SPIRAL_BLAST", "flash", "chest_ahead:1.5", color="CORE", color2="AZURE", size0=2.0, size1=16.0, dur=0.3,
        light_range=40, light_brightness=8),
    cue("SPIRAL_BLAST", "spiral_rings", "chest_ahead:1.5", count=5, radius=(2.0, 18.0), color="CYAN", dur=0.6),
    cue("SPIRAL_BLAST", "debris", "chest_ahead:1.5", count=24, speed=34.0, dur=1.6),
    cue("SPIRAL_BLAST", "shake", None, amp=1.6, dur=0.5, freq=24),
    cue("BARRAGE_SHOT", "sphere_shot", "hands", speed=60.0, travel=18.0, radius=0.7, color="AZURE",
        color2="CYAN"),
    cue("BARRAGE_SHOT", "shake", None, amp=0.3, dur=0.12, freq=30, layer="secondary"),
    cue("SHURIKEN_FORM", "shuriken", "RightHand", r0=0.4, r1=2.4, grow=4.0, blades=4, color="AZURE",
        color2="WIND", dur_until="SHURIKEN_FLY", above=1.6),
    cue("SHURIKEN_FORM", "stream", "RightHand", template="wind", rate=60, dur_until="SHURIKEN_FLY", color="WIND"),
    cue("SHURIKEN_GROW", "flash", "RightHand", color="CORE", color2="AZURE", size0=1.0, size1=5.0, dur=0.15),
    cue("SHURIKEN_GROW", "shake", None, amp=0.4, dur=0.4, freq=26),
    cue("SHURIKEN_FLY", "shuriken_fly", "RightHand", travel=40.0, dur=0.7, radius=2.6, color="AZURE",
        color2="WIND"),
    cue("SHURIKEN_DOME", "wind_dome", "ahead:42", radius=26.0, color="WIND", color2="AZURE",
        dur_until="DOME_COLLAPSE"),
    cue("SHURIKEN_DOME", "screen", None, kind="flash", brightness=0.4, contrast=0.2, dur=0.2),
    cue("SHURIKEN_DOME", "shake", None, amp=2.2, dur=1.8, freq=22),
    cue("SHOCKWAVE", "ring", "ahead:42", when="dome", color="WIND", r0=4.0, r1=60.0, w0=2.0, w1=0.2, dur=0.7,
        orient="ground"),
    cue("SHURIKEN_DOME", "debris", "ahead:42", count=40, speed=30.0, dur=2.0),
    cue("DOME_COLLAPSE", "flash", "ahead:42", color="CORE", color2="AZURE", size0=4.0, size1=30.0, dur=0.3),
    cue("DOME_COLLAPSE", "ring", "ahead:42", color="AZURE", r0=30.0, r1=2.0, w0=0.6, w1=1.6, dur=0.25,
        orient="ground"),
    cue("END", "show_blade", "character"),
]

# --------------------------------------------------------------------------
# ANIM_05 — TITAN SPECTER: FALLING STAR (inspired by Susanoo + Tengai Shinsei)
# --------------------------------------------------------------------------
TITAN_SPECTER = [
    cue("EYES_FLARE", "flash", "Head", color="CRIMSON", size0=0.3, size1=2.0, dur=0.2),
    cue("AURA", "flame_aura", "character", color="VIOLET", color2="BLUEFLAME", dur_until="SPECTER_FADE"),
    cue("AURA", "highlight", "character", color="VIOLET", fill=0.88, dur_until="SPECTER_FADE"),
    cue("GROUND_CRACK", "crack", "feet", count=9, length=(3.0, 8.0), width=0.3, color="VIOLET", color2="VOID",
        grow=0.3, hold=6.0, fade=1.0, bias_forward=0.0),
    cue("FIST", "ring", "LeftHand", color="VIOLET", r0=0.3, r1=4.0, w0=0.4, w1=0.02, dur=0.3, orient="facing"),
    cue("SPECTER_STAGE", "specter", "root", when="1", stage=1, color="VIOLET", color2="BLUEFLAME", height=18.0,
        dur_until="SPECTER_FADE"),
    cue("SPECTER_STAGE", "specter_stage", "root", when="2", stage=2),
    cue("SPECTER_STAGE", "specter_stage", "root", when="3", stage=3),
    cue("SPECTER_STAGE", "shake", None, amp=0.6, dur=0.5, freq=18),
    cue("TITAN_POSE", "flash", "sky:16", color="CRIMSON", size0=0.5, size1=4.0, dur=0.3),
    cue("SPECTER_SWING", "specter_action", "root", action="swing"),
    cue("SPECTER_SWING", "crescent_wave", "UpperTorso", radius=22.0, travel=80.0, speed=90.0, color="VIOLET",
        color2="CORE", dur=0.9),
    cue("SPECTER_SWING", "shake", None, amp=1.8, dur=0.6, freq=20),
    cue("SPECTER_SLAM", "specter_action", "root", action="slam"),
    cue("SPECTER_SLAM", "fissure", "ahead:6", length=60.0, color="VIOLET", color2="CRIMSON", dur=3.0),
    cue("SPECTER_SLAM", "shake", None, amp=2.2, dur=0.7, freq=20),
    cue("SKY_RIFT", "storm_clouds", "sky:120", radius=120.0, color="VOID", dur_until="END", rift=True),
    cue("SKY_RIFT", "screen", None, kind="dim", brightness=-0.2, saturation=-0.2, dur=1.5, tint="VOID"),
    cue("METEOR_APPEAR", "meteor", "ahead:80", start_height=300.0, radius=20.0, color="EMBER", color2="CRIMSON",
        fall_until="METEOR_IMPACT"),
    cue("METEOR_FALL", "shake", None, amp=0.5, dur=3.8, freq=14, layer="secondary"),
    cue("SPECTER_SHIELD", "specter_action", "root", action="shield"),
    cue("METEOR_IMPACT", "screen", None, kind="white"),
    cue("METEOR_IMPACT", "nuke", "ahead:80", radius=70.0, grow=1.2, hold=1.4, fade=2.5, palette="fire"),
    cue("METEOR_IMPACT", "shake", None, amp=3.5, dur=2.2, freq=18),
    cue("IMPACT_FRAME", "screen", None, kind="invert", dur=0.05),
    cue("SHOCKWAVE", "ring", "ahead:80", when="meteor", color="CORE", r0=6.0, r1=110.0, w0=3.5, w1=0.4, dur=1.0,
        orient="ground"),
    cue("SHOCKWAVE", "ring", "ahead:80", when="meteor_2", color="CRIMSON", r0=6.0, r1=150.0, w0=2.5, w1=0.3,
        dur=1.4, orient="ground"),
    cue("DEBRIS", "debris", "ahead:80", when="meteor", count=80, speed=60.0, dur=3.0),
    cue("METEOR_IMPACT", "dust_wall", "ahead:80", radius=110.0, dur=3.5),
    cue("METEOR_IMPACT", "mushroom", "ahead:80", height=90.0, radius=45.0, dur=6.0),
    cue("BLAST_ARRIVES", "burst", "feet", template="dust_ring", count=40),
    cue("BLAST_ARRIVES", "shake", None, amp=1.4, dur=0.6, freq=22),
    cue("SPECTER_FADE", "specter_action", "root", action="fade"),
    cue("EMBER_RAIN", "ash", "feet", radius=60.0, count=2000, dur=3.0),
]

RECIPES = {
    "ANIM_02_STARBURST_REQUIEM": STARBURST_REQUIEM,
    "ANIM_03_RAIJIN_SPEAR": RAIJIN_SPEAR,
    "ANIM_04_SPIRAL_TEMPEST": SPIRAL_TEMPEST,
    "ANIM_05_TITAN_SPECTER": TITAN_SPECTER,
    "ANIM_01_ATOMIC_ECLIPSE": ATOMIC_ECLIPSE,
    "ANIM_01_SOLAR_CLEAVER": SOLAR_CLEAVER,
    "ANIM_02_VOID_SUN_BURST": VOID_SUN_BURST,
    "ANIM_03_ASHSTEP_DASH": ASHSTEP_DASH,
    "ANIM_04_CINDER_CATACLYSM": CINDER_CATACLYSM,
    "ANIM_05_EIGHTFOLD_EXECUTION": EIGHTFOLD_EXECUTION,
}


def resolve(name, timing):
    """Attach absolute frames/times to each cue using the timing JSON.
    Markers that appear several times (AFTERIMAGE, CHARGE_STAGE,
    TRAIL_START...) expand to one cue instance per occurrence, in order."""
    fps = timing["fps"]
    f0 = timing["frame_start"]
    occ = {}
    for m in timing["markers"]:
        occ.setdefault(m["name"], []).append(m["frame"])
    use_count = {}
    out = []
    vals = {}
    for m in timing["markers"]:
        vals.setdefault(m["name"], []).append((m["frame"], m.get("value", "")))
    for c in RECIPES[name]:
        frames = occ.get(c["marker"])
        if c.get("when") is not None:
            frames = [fr for fr, v in vals.get(c["marker"], []) if v == c["when"]]
        if not frames:
            raise KeyError(f"{name}: cue references unknown marker {c['marker']}")
        if c["marker"] in ("TRAIL_START", "TRAIL_END") and len(frames) > 1:
            k = use_count.get((c["marker"], c["fx"], c["params"].get("on")), 0)
            use_count[(c["marker"], c["fx"], c["params"].get("on"))] = k + 1
            frames = [frames[min(k, len(frames) - 1)]]
        for fr in frames:
            d = dict(c)
            d["params"] = dict(c["params"])
            d["frame"] = fr + c["offset"]
            d["time"] = round((d["frame"] - f0) / fps, 4)
            for key in [k for k in d["params"] if k.endswith("_at")]:
                at_frames = occ.get(d["params"][key])
                if not at_frames:
                    raise KeyError(f"{name}: {key} references unknown marker {d['params'][key]}")
                d["params"][key] = next((e for e in at_frames if e >= d["frame"]), at_frames[-1])
            for key in ("dur_until", "grow_until", "hold_until", "linger_until"):
                if key in d["params"]:
                    end_frames = occ.get(d["params"][key])
                    if not end_frames:
                        raise KeyError(f"{name}: {key} references unknown marker {d['params'][key]}")
                    end = next((e for e in end_frames if e >= d["frame"]), end_frames[-1])
                    d["params"][key.replace("_until", "")] = round((end - d["frame"]) / fps, 4)
            out.append(d)
    out.sort(key=lambda d: d["frame"])
    return out
