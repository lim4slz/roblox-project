--!strict
-- Central tuning file. Anything a designer is likely to tweak while balancing
-- lives here, so nobody has to dig through service code to change a number.
--
-- This module is deliberately free of Roblox datatypes (no Vector3/Color3) so the
-- Lune map builder can require it at build time as well as the game at runtime.

local Config = {}

-- Players listed here get the in-game admin panel. Nobody else ever receives it.
Config.AdminUserIds = { 954019325 }
-- Studio "Local Server" tests use fake players with negative UserIds. Flip this
-- on to give every tester the panel there. It never applies in live servers.
Config.AllowAdminPanelInStudio = false

Config.Match = {
	MinPlayers = 2,
	-- Lets a single developer press Play in Studio and get a full match.
	AllowSoloInStudio = true,

	LobbyCountdown = 30,
	-- With this many players waiting, the countdown is cut short.
	QuickStartPlayers = 8,
	QuickStartCountdown = 10,

	GetReadyDuration = 10,
	BattleDuration = 300,
	ResultsDuration = 12,

	RespawnDelay = 5,
	SpawnProtection = 3,

	-- Any one of these flips the match into the Final Showdown (tense music,
	-- no more respawns).
	ShowdownTowerHealth = 0.25,
	ShowdownAlivePlayers = 3,
	ShowdownTimeLeft = 60,

	-- Last N seconds tick audibly.
	FinalCountdown = 30,
}

Config.Tower = {
	-- A tower falls once only this fraction of its bricks is still standing.
	-- The health bars are normalised so they hit 0% at exactly this point.
	DefeatFraction = 0.3,
	-- Chunks that lose support fall as one welded piece, then burst apart.
	ChunkScatterDelay = 1.6,
	DebrisLifetime = 6,
	-- Caps how many loose bricks we hand to the physics engine at once.
	MaxLooseBricks = 260,
}

Config.Bomb = {
	FuseTime = 3,
	ReloadTime = 2.2,
	ChargeTime = 0.9,
	MinThrowSpeed = 42,
	MaxThrowSpeed = 96,
	-- Extra upward push so a flat throw still arcs nicely.
	UpwardBias = 0.2,
	-- How much of the thrower's own velocity the bomb inherits.
	InheritVelocity = 0.5,
	Size = 1.6,
	Elasticity = 0.45,

	BlastRadius = 11,
	BrickRadius = 8.5,
	MaxDamage = 100,
	MinDamage = 30,
	SelfDamageMultiplier = 0.5,
	Knockback = 75,

	MegaMultiplier = 1.6,
	ThrowCooldown = 0.25,
}

Config.Sword = {
	Damage = 20,
	LungeDamage = 32,
	Cooldown = 0.5,
	-- A second click inside this window turns the swing into a lunge.
	LungeWindow = 0.35,
	Range = 7,
	Knockback = 32,
	LungeKnockback = 55,
}

Config.Rocket = {
	Speed = 95,
	Cooldown = 1.4,
	Lifetime = 4,
	BlastRadius = 9,
	BrickRadius = 7,
	MaxDamage = 70,
	MinDamage = 20,
	Knockback = 70,
}

Config.Zone = {
	-- Seconds after "Battle Begins!" before the storm forms.
	StartDelay = 120,
	WarningLead = 10,
	-- A new shrink starts every Interval seconds and takes ShrinkDuration.
	Interval = 30,
	ShrinkDuration = 12,
	-- Radius before the first shrink, then after each shrink. Six shrinks take
	-- the safe area from the whole arena down to the centre plateau by ~4:42.
	Radii = { 235, 190, 150, 115, 82, 54, 30 },
	-- Damage per second for players caught outside, indexed by shrink number.
	DamagePerSecond = { 3, 5, 7, 10, 14, 18 },
	WallHeight = 140,
}

Config.Events = {
	FirstEventAt = 45,
	Interval = 60,
	IntervalJitter = 10,
	-- No new events this close to the end of the match.
	QuietFinalSeconds = 25,
}

Config.PowerUps = {
	FirstSpawnAt = 20,
	SpawnInterval = 22,
	MaxActive = 3,
	Lifetime = 35,
	SpeedBoost = { WalkSpeed = 26, Duration = 10 },
	Shield = { Duration = 8 },
	Heal = { Amount = 50 },
	TripleBomb = { Charges = 3 },
}

Config.Scoring = {
	Knockout = 100,
	Assist = 50,
	EnemyBrick = 5,
	TowerDestroyed = 250,
	WinBonus = 150,
	-- Damage counts toward an assist if dealt within this many seconds of death.
	AssistWindow = 10,
	AssistMinimumDamage = 20,
}

Config.Player = {
	WalkSpeed = 16,
	JumpPower = 50,
	MaxHealth = 100,
}

Config.Lobby = {
	-- Falling off the sky island this far below the floor teleports you back.
	VoidDepth = 40,
	PracticeWallRegenDelay = 8,
	DummyMaxHealth = 500,
	-- Explosions in the lobby are just for fun: no damage and softer knockback.
	KnockbackScale = 0.45,
}

Config.Camera = {
	LockFirstPersonInBattle = true,
	ShowArmsInFirstPerson = true,
	ShakeMaxDistance = 60,
	ShakeIntensity = 0.6,
}

Config.Teams = {
	{
		Name = "Blue",
		DisplayName = "Blue Team",
		BrickColor = "Bright blue",
		Color = { 59, 130, 246 },
		LightColor = { 147, 197, 253 },
		DarkColor = { 30, 64, 175 },
	},
	{
		Name = "Red",
		DisplayName = "Red Team",
		BrickColor = "Bright red",
		Color = { 239, 68, 68 },
		LightColor = { 252, 165, 165 },
		DarkColor = { 153, 27, 27 },
	},
}

return Config
