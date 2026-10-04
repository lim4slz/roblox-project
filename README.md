# Ember Abilities

Habilidades de anime para Roblox, animadas no Blender e rodando no Roblox com VFX feitos em código.
O Blender é só a ferramenta de criação: o que vai pro jogo é o KeyframeSequence e o runtime em Luau.

| # | Habilidade | Inspiração | Estado |
|---|---|---|---|
| 01 | **ATOMIC ECLIPSE** | "I Am Atomic" (The Eminence in Shadow) | pronta |
| 02 | STARBURST REQUIEM | Starburst Stream (SAO) | em produção |
| 03 | RAIJIN SPEAR | Chidori / Kirin (Naruto) | em produção |
| 04 | SPIRAL TEMPEST | Rasengan / Rasenshuriken (Naruto) | em produção |
| 05 | TITAN SPECTER | Susanoo + meteoro do Madara (Naruto) | em produção |

Os nomes e a execução são próprios. As obras citadas são só referência de clima e ritmo.

Detalhes da ATOMIC ECLIPSE: [docs/ATOMIC_ECLIPSE.md](docs/ATOMIC_ECLIPSE.md)

Pra continuar no seu PC (o que instalar e como): [docs/COMO_CONTINUAR.md](docs/COMO_CONTINUAR.md)

## Testar rápido

1. Abra `ROBLOX/build/EmberAbilities_Test.rbxl` no Roblox Studio.
2. Dê Play e aperte **1**.

No Studio a animação é registrada na hora a partir do KeyframeSequence, então funciona sem publicar nada.
Em jogo publicado é preciso publicar a animação (veja abaixo).

## Colocar em outro jogo

Com Rojo: `rojo serve ROBLOX/default.project.json`.

Sem Rojo: insira `ROBLOX/build/EmberAbilities.rbxm`. Depois mova cada pasta de dentro dele pro serviço com o mesmo nome:
`Ember` vai em ReplicatedStorage, `EmberServer` em ServerScriptService e `EmberClient` em StarterPlayerScripts.

O personagem precisa ser **R15**. A lâmina e o cachecol são adicionados pelo servidor quando o personagem nasce.

### Publicar a animação

1. Insira `EXPORT/KeyframeSequences/ANIM_01_ATOMIC_ECLIPSE.rbxm` no Studio.
2. Clique com o direito no KeyframeSequence e use **Save to Roblox**, ou abra pelo Animation Editor e use **Publish to Roblox**.
   Publique no mesmo dono do jogo (usuário ou grupo).
3. Cole o ID em `ROBLOX/src/shared/Assets.luau` (`Assets.Animations.ANIM_01_ATOMIC_ECLIPSE`).

## Pacotes de venda

`lune run SCRIPTS/lune/build_packs.luau` (depois do `build_kit.luau`) gera a pasta pronta pra mandar pro comprador, em inglês, em `EXPORT/packs/ATOMIC_ECLIPSE/`:

```
1_Animation_Only/        só a animação, juntas padrão do R15
2_Animation_With_Sword/  animação + espada + script que encaixa na mão
3_Full_Ability/          habilidade completa (efeitos, espada, dano)
Demo/                    place com a habilidade instalada
Preview/                 vídeo
README.txt               instruções completas
```

Os scripts da pasta saem com comentários e mensagens em inglês (`ROBLOX/packs/english.luau`); o build para se sobrar português.
Não use o nome da obra de referência no título nem na thumbnail.

## Estrutura

```
ANIMATIONS/<NOME>/        .blend da animação, .rbxanim (export do add-on), timing, cues, checagens
CHARACTER/                metadados do rig (C0/C1 de cada junta)
EXPORT/KeyframeSequences/ KeyframeSequence pronto pro Roblox (com KeyframeMarkers)
EXPORT/reports/           relatório da redução de keyframes e da releitura do .rbxm
EXPORT/packs/             pasta de venda pronta pro comprador
REFERENCE/                previs em vídeo e contact sheets
RIG/                      rig R15 do Blender (feito com o create_rig do add-on)
ROBLOX/                   projeto Rojo, kit .rbxm, place de teste e fontes dos pacotes
SCRIPTS/blender/          motor de animação, habilidades, previs, QA
SCRIPTS/tools/            exportação pro Roblox (KeyframeSequence, dados, rig, sourcemap)
SCRIPTS/lune/             build do .rbxm/.rbxl e testes
docs/                     relatório de cada habilidade
```

## Pipeline

Precisa de Blender 4.5, do add-on **Roblox Animations Importer/Exporter v3.0.1** (Cautioned/RBXMonkey), de Python 3 e do [Lune](https://github.com/lune-org/lune) 0.10.
O add-on não vem no repositório (é GPL). Aponte `RBX_ADDON_SRC` pro zip dele.

```bash
export RBX_ADDON_SRC=/caminho/add-on-roblox-animations-importer-exporter-v3.0.1.zip
B=blender   # ou o caminho do executável

# rig (só quando mudar o rig)
$B -b --factory-startup --python SCRIPTS/blender/build_rig.py
python3 SCRIPTS/tools/gen_rig_data.py

# animação: bake + export pelo add-on + previs de VFX
$B -b --factory-startup RIG/EMBER_R15_RIG.blend --python SCRIPTS/blender/run_ability.py -- anim_01_atomic_eclipse --export
$B -b ANIMATIONS/ANIM_01_ATOMIC_ECLIPSE/ANIM_01_ATOMIC_ECLIPSE.blend --python SCRIPTS/blender/check_motion.py

# Roblox
python3 SCRIPTS/tools/kfs_builder.py ANIM_01_ATOMIC_ECLIPSE
lune run SCRIPTS/lune/build_kfs.luau ANIM_01_ATOMIC_ECLIPSE
python3 SCRIPTS/tools/gen_ability_data.py ANIM_01_ATOMIC_ECLIPSE
lune run SCRIPTS/lune/build_kit.luau

# testes
lune run SCRIPTS/lune/test_runtime.luau
python3 SCRIPTS/tools/props_used.py && lune run SCRIPTS/lune/check_props.luau
```

Para o previs em vídeo, use `run_ability.py` com `--video` (32 s inteiros) ou `--clip=760-1560-2` (um trecho), mais `--lowres` para ir mais rápido.

## VFX

Os efeitos seguem o modelo do Qwinkle's Particles 2: partículas que são peças 3D de verdade, com curvas de tamanho, transparência e cor ao longo da vida, speed, drag, spread, accel e link com o personagem. Os efeitos são montados em camadas (flash, núcleo, fumaça, faíscas, entulho, raios, distorção, luz, tela e shake), cada uma com seu delay.

Tudo sai de uma spec só, em `SCRIPTS/blender/abilities/anim_01_atomic_eclipse.py`. Ela vira o previs no Blender e o arquivo `ROBLOX/src/shared/Abilities/AtomicEclipse.luau`, que o runtime (`ROBLOX/src/shared/VFX`) executa.

Quem tiver o plugin Qwinkle's Particles 2 pode trocar ou somar qualquer efeito sem mexer em código. Veja `ROBLOX/src/shared/QwinkleBridge.luau`.
