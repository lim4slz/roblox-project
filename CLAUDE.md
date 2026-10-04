# Ember Abilities

Habilidades de anime para Roblox R15. O Blender é só a ferramenta de criação; o que vai pro jogo é o
KeyframeSequence (.rbxm) e o runtime em Luau (`ROBLOX/src`). Pipeline completa e comandos: `README.md`.
Guia de instalação local: `docs/COMO_CONTINUAR.md`.

## Regras do dono

- Terminar uma habilidade 100% (animação, QA, VFX, export, testes, docs, push) antes de começar a próxima.
- Scripts escritos como se o dono tivesse feito: português, poucos comentários (`--`/`#`), nada de texto com cara de IA.
- Nomes próprios e originais ("inspirado em"). Nunca usar o nome da obra de referência no produto.
- Nunca fingir teste nem inventar API do Roblox. O que não deu pra testar (ex.: dentro do Studio) vai escrito como limitação.
- Relatórios e mensagens de commit em português.

## Estado

| # | Habilidade | Estado |
|---|---|---|
| 01 | ATOMIC ECLIPSE | pronta, testada no Studio pelo dono, pacote de venda em `EXPORT/packs/ATOMIC_ECLIPSE` |
| 02 | STARBURST REQUIEM | em produção: `abilities/anim_02_starburst_requiem.py`, cortes em `abilities/moves.py` |
| 03 | RAIJIN SPEAR | rascunho em `SCRIPTS/blender/_wip/` |
| 04 | SPIRAL TEMPEST | rascunho em `SCRIPTS/blender/_wip/` |
| 05 | TITAN SPECTER | rascunho em `SCRIPTS/blender/_wip/` |

`_wip/vfx_recipes_full.py` e `_wip/vfx_previs_full.py` têm ideias antigas de VFX das próximas (formato antigo, só referência).

## Próximos passos da STARBURST

1. Cortes: `fit_cuts.py` acha pegada + cotovelo limpos pra cada corte; colar no `CUTS` e rodar `pose_lab.py` até `LAB TOTAL 0`.
   Último resultado do lab: 14 contatos de ~0.25 (antebraço no tronco nas transições) e AzureBlade na perna direita no `diag_a` L.
2. Bake: `run_ability.py -- anim_02_starburst_requiem --export` e `check_motion.py`. Corrigir os movimentos fora do CUTS
   (`draw_second`, `x_guard`, `dual_open`, `final_thrust`, `dual_rise`, `spin_cut`, `dual_cross_down`, `backflip`, `twirl`).
3. VFX: escrever `CUES`/`HITS` no arquivo da habilidade (mesmo formato da ATOMIC): lâminas de luz azul/ciano, arcos de corte
   (ring parcial no plano do golpe), faíscas, afterimages nos golpes rápidos, explosão final, overdrive aéreo, X no chão.
   A AzureBlade precisa entrar no `Rig.augment` só quando a habilidade usar duas lâminas, o special `blade` precisa de
   parâmetro pra qual lâmina, e faltam âncoras da lâmina esquerda em `Anchors.luau`.
4. Roblox: `kfs_builder.py`, `build_kfs.luau`, `gen_ability_data.py`, `build_kit.luau`, testes, `docs/STARBURST_REQUIEM.md`,
   README e um `build_packs` pra ela.

Se o orçamento estiver curto: versão menor (~15 s, 8 golpes) reaproveitando as camadas de VFX que já existem.

## Coisas que já custaram caro descobrir

- Braço R15: o pivô do ombro fica em (±1, 0.563, 0) no espaço do UpperTorso e o pulso alcança só ~1.57 studs. Manter a
  pegada a no máximo ~1.45 do ombro. Fora disso o braço estica reto e atravessa o peito.
- Antebraço e mão são prismas 1×1. Na frente do tronco o centro precisa de z ≤ -0.9, ou o cotovelo vai pra fora (x ≥ 1.5).
  O giro do corpo (yaw do tronco) é que dá a amplitude do golpe, não a mão cruzando o peito.
- `pole` no `arms={...}` é pra onde aponta a ponta do cotovelo.
- Chão em `rc.FLOOR_Y = -3` no espaço do root. A lâmina tem 5.2 studs: apontando muito pra baixo ela bate no chão e o
  clamp gira a mão pra dentro da perna.
- Tolerâncias do QA: antebraço × corpo 0.2; mão e lâmina 0.12.
- Lune: salvar lado a lado uma instância lida de arquivo e uma criada no script derruba o `serializeModel`. Põe tudo numa Folder.
- luau-lsp: rodar de dentro de `ROBLOX/` com `--sourcemap=sourcemap.json` (gerar antes com `python3 SCRIPTS/tools/sourcemap.py`).
- No cliente, nunca `WaitForChild` sem timeout em coisa do jogo do usuário (ex.: PlayerModule). Já travou a habilidade num jogo real.
- Os scripts do pacote do comprador saem em inglês via `ROBLOX/packs/english.luau`. Comentário ou `warn` novo em português
  precisa de tradução lá, senão o `build_packs.luau` para com erro.
- Mudou o motor (`anim_engine.py`)? Refaz o bake da ATOMIC e compara o `.rbxanim` com o commitado antes de subir.
