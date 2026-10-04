local Config = {}

Config.Abilities = {
	AtomicEclipse = { key = Enum.KeyCode.One, cooldown = 45 },
}

Config.AnimationPriority = Enum.AnimationPriority.Action4
Config.FadeIn = 0.1
Config.FadeOut = 0.3

Config.Quality = {
	-- multiplicador de quantidade de partículas pelo nível gráfico do jogador (1..10, Automático conta como 7)
	ByLevel = { 0.25, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1, 1 },
	SkipTertiaryBelow = 0.6,
	SkipSecondaryBelow = 0.35,
	MaxParticles = 900,
	MaxLightningSegments = 260,
	ObserverCullDistance = 900,
	ScreenFalloff = 450,
}

Config.Damage = {
	Enabled = true,
	Multiplier = 1,
	HitCaster = false,
}

-- function(attacker: Player, humanoid: Humanoid, abilityName: string, hitName: string, amount: number)
Config.OnHit = nil :: ((Player, Humanoid, string, string, number) -> ())?

-- efeitos feitos no Qwinkle's Particles 2 (ver QwinkleBridge.luau)
Config.UseQwinkle = false
Config.QwinkleReplaces = false

return Config
