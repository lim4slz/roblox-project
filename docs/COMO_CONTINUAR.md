# Como continuar no seu PC

## O que já foi feito

- **Rig R15 no Blender** feito com o add-on, com espada e cachecol (`RIG/`).
- **Motor de animação** em Python (`SCRIPTS/blender`): poses em espaço de juntas do Roblox, IK de braço e perna, braço que
  desvia do corpo, lâmina que não atravessa nada, QA automático de colisão e giro de junta.
- **ATOMIC ECLIPSE** pronta: animação de 32 s, KeyframeSequence com 44 markers, runtime de VFX em Luau, dano no servidor,
  testes, vídeo e pacote de venda em inglês (`EXPORT/packs/ATOMIC_ECLIPSE`).
- **STARBURST REQUIEM** começada: coreografia e biblioteca de cortes com duas lâminas.
- **RAIJIN SPEAR, SPIRAL TEMPEST e TITAN SPECTER**: rascunhos em `SCRIPTS/blender/_wip/`.

## O que baixar

| Programa | Pra quê | Onde |
|---|---|---|
| Git | baixar o projeto e subir mudanças | git-scm.com (no Windows vem com o **Git Bash**, use ele pros comandos) |
| Claude Code | o Claude no seu PC | app desktop ou terminal, instruções em code.claude.com/docs |
| Blender **4.5 LTS** | bake das animações | blender.org |
| Add-on **Roblox Animations Importer/Exporter v3.0.1** (Cautioned/RBXMonkey) | export do Blender pro Roblox | o mesmo zip que você mandou no começo; guarde ele |
| Python 3.11 ou mais novo | ferramentas de export (`SCRIPTS/tools`) | python.org (marque "Add to PATH") |
| Lune 0.10 | monta os .rbxm/.rbxl e roda os testes | github.com/lune-org/lune/releases (coloque o `lune.exe` no PATH) |
| ffmpeg | vídeo do previs | ffmpeg.org (no PATH) |
| Roblox Studio | testar | roblox.com/create |
| luau-lsp (opcional) | checar tipos do Luau | github.com/JohnnyMorganz/luau-lsp/releases + o arquivo `globalTypes.d.luau` do mesmo repositório |
| Rojo (opcional) | sincronizar `ROBLOX/src` com o Studio | rojo.space |

## Primeira vez

No Git Bash:

```bash
git clone https://github.com/lim4slz/roblox-project.git
cd roblox-project
git checkout claude/optimistic-johnson-jendff
```

Diga onde está o zip do add-on (troque o caminho):

```bash
setx RBX_ADDON_SRC "C:\caminho\add-on-roblox-animations-importer-exporter-v3.0.1.zip"
```

Feche e abra o terminal de novo. Teste se está tudo no lugar:

```bash
B="/c/Program Files/Blender Foundation/Blender 4.5/blender.exe"
"$B" --version
lune --version
python --version
ffmpeg -version
```

O projeto foi feito em Linux. No Windows os comandos do README rodam no Git Bash; se algum caminho der erro, peça pro
Claude Code ajustar.

## Abrindo o Claude Code

Abra o Claude Code dentro da pasta `roblox-project`. Ele lê o `CLAUDE.md` sozinho, que tem as regras, o estado de cada
habilidade e os próximos passos. Uma boa primeira mensagem:

> Leia o CLAUDE.md e continue a STARBURST REQUIEM pelo passo 1 (cortes limpos com fit_cuts.py e pose_lab.py). Me avise antes de começar o passo 2.

## Pipeline de uma habilidade

```bash
# 1. animação: bake + export pelo add-on (+ previs de VFX)
"$B" -b --factory-startup RIG/EMBER_R15_RIG.blend --python SCRIPTS/blender/run_ability.py -- anim_01_atomic_eclipse --export
"$B" -b ANIMATIONS/ANIM_01_ATOMIC_ECLIPSE/ANIM_01_ATOMIC_ECLIPSE.blend --python SCRIPTS/blender/check_motion.py

# 2. Roblox
python SCRIPTS/tools/kfs_builder.py ANIM_01_ATOMIC_ECLIPSE
lune run SCRIPTS/lune/build_kfs.luau ANIM_01_ATOMIC_ECLIPSE
python SCRIPTS/tools/gen_ability_data.py ANIM_01_ATOMIC_ECLIPSE
lune run SCRIPTS/lune/build_kit.luau
lune run SCRIPTS/lune/build_packs.luau

# 3. testes
lune run SCRIPTS/lune/test_runtime.luau
python SCRIPTS/tools/props_used.py && lune run SCRIPTS/lune/check_props.luau
```

Ferramentas de animação:

```bash
# testa cada corte isolado e lista o que encosta no corpo
"$B" -b --factory-startup RIG/EMBER_R15_RIG.blend --python SCRIPTS/blender/pose_lab.py
# acha pegada e cotovelo limpos pra cada corte
"$B" -b --factory-startup RIG/EMBER_R15_RIG.blend --python SCRIPTS/blender/fit_cuts.py
# vídeo do previs (lento): --video inteiro, ou --clip=760-1560-2 pra um trecho, --lowres pra ir mais rápido
"$B" -b --factory-startup RIG/EMBER_R15_RIG.blend --python SCRIPTS/blender/run_ability.py -- anim_01_atomic_eclipse --clip=760-1560-2 --lowres
```

## Pra gastar menos

- Uma sessão nova por tarefa. Sessão longa fica cara porque todo o histórico é relido a cada mensagem.
- Pedidos fechados ("limpa os cortes e faz commit") rendem mais que "termina tudo".
- Peça poucos frames em vez de vídeo inteiro pra conferir.
- Bake e render rodam no seu PC e não gastam nada; o que gasta é a conversa.
