# ANIM_01 — ATOMIC ECLIPSE

Inspirada em "I Am Atomic" (The Eminence in Shadow). Nome, golpe e execução são próprios.
O arco é: calma absoluta, o mundo escurece, toda a magia é comprimida num ponto, silêncio
e uma explosão atômica com o conjurador intacto no olho dela.

Previs: [REFERENCE/ANIM_01_ATOMIC_ECLIPSE](../REFERENCE/ANIM_01_ATOMIC_ECLIPSE) (vídeo do clímax e contact sheet).

## Dados técnicos

| | |
|---|---|
| Duração | 32,0 s (frames 0–1920 a 60 fps) |
| Rig | R15 bloco + EmberBlade (mão direita) + cachecol de 4 segmentos |
| Export | add-on RBXMonkey 3.0.1, `serialize()`, bake denso de 1921 keyframes, interpolação Linear |
| KeyframeSequence | 1523 keyframes depois da redução, 44 KeyframeMarkers, Priority Action4, sem loop, 884 KB |
| Root motion | fora do KeyframeSequence: anda 6,5 studs pra frente nos primeiros 5 s (`RootMotion.luau`) |
| Arquivos | `ANIMATIONS/ANIM_01_ATOMIC_ECLIPSE/`, `EXPORT/KeyframeSequences/ANIM_01_ATOMIC_ECLIPSE.rbxm`, `ROBLOX/src/shared/Abilities/AtomicEclipse.luau` |

Por que Linear: o bake já tem uma pose por frame (IK, overlap, ruído e cachecol simulados no Blender).
O Roblox interpola entre keyframes com slerp. A redução só tira um keyframe se a interpolação dos vizinhos
reproduz ele em todos os ossos com erro abaixo de 0,35° e 0,006 stud.

## Fases

| Fase | Frames | O que acontece |
|---|---|---|
| SHADOW_WALK | 0–360 | Caminhada lenta e pesada arrastando a lâmina. Circuitos sobem pelo corpo, um sigilo acende a cada passo e a lâmina solta faíscas raspando o chão. |
| AWAKENING | 360–720 | Os olhos acendem. A mão esquerda sobe, energia converge de 34 studs e três círculos mágicos se abrem com pilares de luz. Pedras sobem do chão e ele começa a levitar. |
| SINGULARITY | 720–1176 | Sobe 2,6 studs com os braços abertos: halo de eclipse com corona, hélices, orbes e raios. A lâmina vira energia e entra nas mãos, que se fecham. Vem a implosão (pedras, círculos e partículas sugados), depois o silêncio, com um ponto branco e 3 pulsos. |
| ATOMIC | 1176–1500 | Frame de impacto P&B, flash branco e a esfera atômica de 60 studs (núcleo, plasma, campo). Seguem distorção, 3 ondas de choque, parede de poeira, entulho que quica, coluna de luz e cogumelo com anel de condensação. |
| AFTERMATH | 1500–1920 | Cinzas caem e a cratera brilha. A lâmina se reforma, ele desce e pousa, olha a destruição, sacode a lâmina e fica relaxado. |

## Markers

| Frame | Tempo (s) | Marker | Valor |
|---|---|---|---|
| 2 | 0.03 | CAST_START | |
| 10 | 0.17 | CIRCUITS_START | |
| 78 / 134 / 190 / 246 / 302 | 1.30 … 5.03 | STEP_SIGIL | 1…5 |
| 350 | 5.83 | AWAKEN | |
| 420 | 7.00 | CONVERGE | |
| 430 / 520 / 600 | 7.17 / 8.67 / 10.00 | SIGIL_GROUND | 1 / 2 / 3 |
| 450 | 7.50 | DIM | |
| 612 | 10.20 | LEVITATE | |
| 760 | 12.67 | HALO | |
| 800 | 13.33 | HELIX | |
| 820 | 13.67 | ORBS | |
| 990 | 16.50 | CHARGE_PEAK | |
| 1000 | 16.67 | BLADE_DISSOLVE | |
| 1040 | 17.33 | IMPLODE | |
| 1060 | 17.67 | SILENCE | |
| 1080 / 1110 / 1140 | 18.00 / 18.50 / 19.00 | POINT_PULSE | 1 / 2 / 3 |
| 1176 | 19.60 | RELEASE, WHITE_FLASH | |
| 1178 | 19.63 | NUKE | |
| 1182 / 1200 / 1225 | 19.70 / 20.00 / 20.42 | SHOCKWAVE | 1 / 2 / 3 |
| 1185 | 19.75 | DUST_WALL | |
| 1190 | 19.83 | DEBRIS | |
| 1200 | 20.00 | COLUMN | |
| 1240 | 20.67 | MUSHROOM | |
| 1500 | 25.00 | ASH_FALL | |
| 1560 | 26.00 | SCREEN_RESTORE | |
| 1590 | 26.50 | BLADE_REFORM | |
| 1642 | 27.37 | LAND | soft |
| 1748 / 1770 | 29.13 / 29.50 | TRAIL_START / TRAIL_END | flick |
| 1762 | 29.37 | FLICK | ember_shed |
| 1880 / 1900 / 1920 | 31.33 / 31.67 / 32.00 | DISSIPATE / RECOVERY / END | |

Os markers vão dentro do KeyframeSequence (o add-on não exporta markers, então o `kfs_builder.py` adiciona a partir do timing).
O runtime não depende de `GetMarkerReachedSignal`: os cues são disparados pelo tempo da AnimationTrack (quem lança) ou pelo relógio do servidor (quem assiste). Assim nada se perde com lag e quem entra atrasado continua sincronizado.

## VFX no Roblox

Cada momento é um conjunto de camadas. No Roblox cada tipo de camada vira:

| Camada | Classe no Roblox |
|---|---|
| part (partículas 3D) | Parts Neon/SmoothPlastic/Slate de um pool, movidas com `BulkMoveTo`, com curvas de tamanho, transparência e cor |
| animate (esfera, coluna, disco) | uma Part animada no lugar |
| ring (anéis, ondas de choque) | 8–10 Beams com FaceCamera fechando um círculo (arco de Bézier exato via CurveSize) |
| lightning | segmentos de Part Neon (núcleo + brilho) regenerados a cada 0,04–0,05 s, com bifurcação |
| light | PointLight |
| screen | ColorCorrectionEffect com rampa, hold e release |
| flash | Frame branco/preto em tela cheia. "invert" vira um frame P&B estourado, porque o Roblox não inverte cor |
| shake | câmera com `BindToRenderStep` depois da câmera, com falloff por distância |
| distort | esfera de Glass (refração; precisa de gráfico alto) |
| highlight | Highlight no personagem |
| sigil, circuits, helix, orbs, halo, point, blade | componentes próprios em `VFX/Specials.luau` (Beams, Trails, Attachments, Parts) |

Resumo dos momentos principais:

- **Caminhada:** fumaça escura subindo do corpo, motes violeta, faíscas da lâmina raspando, rastro brilhando no chão e sigilo a cada passo (anel + disco + poeira + faíscas + luz).
- **Convergência:** streaks esticados pela velocidade vindo de uma casca de 34 studs, motes lentos e raios curtos.
- **Círculos:** 3 círculos girando em sentidos opostos (anéis, raios, runas, hexagrama), cada um com pilares de luz. As pedras sobem devagar e são puxadas pras mãos na implosão.
- **Singularidade:** halo de eclipse (disco escuro + anéis + espinhos + corona de partículas), hélices, orbes com trail e raios.
- **Implosão e silêncio:** anel colapsando, 110 streaks pra dentro, distorção, tela escura e um ponto branco pulsando.
- **Explosão:** frame P&B, preto e flash branco. Depois o núcleo, o plasma, o campo, blobs de energia, 130 streaks pra fora, distorção expandindo, luz de 60 studs, 3 ondas de choque, 64 bolas de poeira, 46 pedras com gravidade e quique, 180 brasas, coluna dupla com partículas subindo e cogumelo com anel de condensação.
- **Depois:** 360 flocos de cinza caindo girando, brasas subindo, cratera escura com borda brilhando, lâmina se reformando, pouso e flick com rastro.

Tudo isso está em `SCRIPTS/blender/abilities/anim_01_atomic_eclipse.py` (lista `CUES`) e é gerado em `AtomicEclipse.luau`.

## Gameplay

| Hit | Tempo | Raio | Dano | Knockback |
|---|---|---|---|---|
| NUKE | 19,63 s | 60 studs | 45 (cai até 40% na borda) | 90 pra fora + 45 pra cima |
| SHOCKWAVE 3 | 20,42 s | 120 studs | 0 | 45 pra fora + 15 pra cima |

Validação no servidor: a habilidade existe, cooldown de 45 s, personagem vivo e não estar lançando outra.
O knockback é um `LinearVelocity` de 0,22 s criado pelo servidor no HumanoidRootPart do alvo. Dano e knockback ficam em `Config.Damage` e há o hook `Config.OnHit`.

## Performance

| | Qualidade máxima |
|---|---|
| Partículas 3D no total | 2735 |
| Pico simultâneo | 514 (aos 20,8 s, na explosão) |
| Teto de partículas | `Config.Quality.MaxParticles` = 900 × qualidade |
| Pico de Beams | 326 (aos 16,5 s: 3 círculos + halo + circuitos + anéis) |
| Segmentos de raio | teto de 260 |
| Luzes dinâmicas | até 3 ao mesmo tempo |

A qualidade vem do nível gráfico do jogador (`UserGameSettings.SavedQualityLevel`): o nível 1 emite 25% das partículas e o 10 emite 100%. Camadas secundárias somem abaixo de 0,35 e terciárias abaixo de 0,6.
Partes vêm de um pool (sem `Instance.new` por partícula) e todo movimento de um frame vai num `BulkMoveTo` só.
Quem assiste de mais de 900 studs não roda os VFX, e efeitos de tela e shake perdem força com a distância.

## Validação

| Teste | Resultado |
|---|---|
| Round trip do export (T autorado × saída do add-on, 40.341 poses) | erro máx 7,7e-7 |
| `test_roundtrip_math.py` | PASS (5,4e-7) |
| Redução de keyframes | 1921 → 1523, erro máx 0,349° e 0,001 stud em 80.661 amostras (todo frame e meio frame) |
| Releitura do `.rbxm` | 1523 keyframes, 44 markers, erro máx 7,7e-6 |
| QA de movimento (`check_motion.py`) | nenhum giro de junta acima de 200° em 40 frames; o único pico acima de 18°/frame é o golpe da liberação (29°, proposital); só 2 roçados de antebraço no tronco de 0,23 stud por menos de 10 frames (tolerância do rig bloco: 0,2) |
| Lâmina abaixo do chão | nenhum frame |
| `luau-lsp analyze` (definições do Roblox) | 0 erros |
| `test_runtime.luau` (Lune) | 937 checagens ok: curvas, cone, arco do anel, root motion, dados, cues e markers |
| `check_props.luau` | 92 propriedades escritas pelo runtime existem e são graváveis (reflection 0.728) |
| Kit e place | montados e relidos pelo Lune |

## Limitações reais

- O runtime **não foi rodado dentro do Roblox Studio**: não tem Roblox neste ambiente. Ele foi validado por análise estática, testes em Lune e checagem de propriedades, mas o comportamento em jogo (visual, timing de rede, performance real) precisa ser conferido no Studio.
- O previs é Cycles no Blender com rig de blocos. Neon, Beam e transparência do Roblox não ficam idênticos ao previs, então a intensidade final se ajusta no Studio (curvas e cores na spec ou em `Config`).
- A distorção usa Glass, que só refrata com qualidade gráfica alta. Em gráfico baixo fica uma esfera quase invisível.
- "Invert" é um frame preto e branco, não uma inversão real de cor.
- A animação foi feita no R15 bloco. Em avatares com proporções diferentes a pose muda um pouco (o Roblox aplica as mesmas rotações em juntas com C0/C1 diferentes).
- Root motion usa `Humanoid:Move`. Se houver parede na frente, ele para em vez de atravessar.
- Os efeitos são só de código (sem texturas). Quem quiser textura ou flipbook pode refazer qualquer camada no Qwinkle's Particles 2 (`QwinkleBridge.luau`).

## Passos manuais

1. Publicar o KeyframeSequence e colar o ID em `Assets.Animations` (ver README). No Studio dá pra testar sem isso.
2. Jogo em R15 (Game Settings > Avatar). O place de teste já vem configurado.
3. Ajustar dano, knockback e cooldown em `Config.luau` se quiser.
4. (Opcional) Ligar `Config.UseQwinkle` e criar efeitos `AtomicEclipse_<MARKER>` em `ReplicatedStorage.Ember.Qwinkle`.
