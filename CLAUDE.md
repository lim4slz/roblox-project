# Brightbrook + pets animados

Jogo Roblox (Rojo) com lógica compartilhada em `src/shared`, testes headless com Lune em `tests/` e um conjunto
de pets animados que também são vendidos ao cliente como pastas de arrastar e soltar.

## Regras do dono

- Tudo que vai pro cliente é em inglês: código, comentários, Config, READMEs.
- A entrega fica em `Work꞉ pet animation/` (o "꞉" é U+A789: o Windows não aceita ":" em nome de pasta, e com ":"
  o git e o zip quebram lá). Seis pastas: Dog, Snake, Bunny, Crab, Dragon e All in One. Dentro de cada pet, pastas
  com os nomes do Explorer do Roblox (`ReplicatedStorage/`, `StarterPlayer/StarterPlayerScripts/`) e um README.md.
- Nunca fingir teste. O que não dá pra testar fora do Studio vai escrito como limitação.

## Estado

| Pet | Estado |
|---|---|
| Dog | pronto |
| Snake | pronto |
| Bunny | pronto |
| Crab | pronto |
| Dragon | falta: o dono vai mandar o modelo. A pasta `Dragon/` só tem um README de placeholder |

## Como os pets funcionam

Tudo roda no cliente, nada replica. Arquivos em `src/shared/Pets`:

- `PetRig`: cinemática direta (ossos + partes), escala uniforme, ossos "pinned" em espaço de mundo (a cobra usa).
- `PetKit`: monta as partes a partir da definição (e do visual do modelo em `Models`, se houver), chão, balões, som.
- `PetFollow`: segue o dono até o `Spot` dele.
- `PetSpawner`: lê a Config (quem ganha qual pet, atributo `Pet`, ajustes por pet) e cria/destrói os pets.
- Por pet: `<Pet>Model` (dados da arte), `<Pet>Animation` (animação procedural, matemática pura), `<Pet>Pet` (classe).

## Adicionar o dragão (ou outro pet)

1. Converter a arte pro espaço do pet (origem no chão embaixo do corpo, olhando pra -Z):
   `lune run scripts/convert_art -- pets.rbxm Dragon [yaw]`. Escreve cada peça como `size(...) at(x, y, z, rx, ry, rz)`,
   o mesmo `at()` dos arquivos de modelo. O yaw é o giro da arte em Y (Dog 6.47, Crab 1.606, os outros 0).
2. `src/shared/Pets/DragonModel.luau`, `DragonAnimation.luau`, `DragonPet.luau` seguindo o Dog/Snake
   (mesma API: `new(seed, every)`, `step`, `pose`, `react`, `gait`, `Every`; a classe com `Defaults`).
3. `tests/unit/dragon.spec.luau` no estilo de `snake.spec.luau`.
4. `packs/config/Dragon.luau` (valores iguais aos `Defaults`) e `packs/pets/Dragon.md`.
5. Registrar em `scripts/PetPacks.luau` (`PetPacks.Pets`, um pack próprio e o All in One) e tirar "Dragon" de
   `PetPacks.Placeholders`; apagar `packs/readme/Dragon.md`. Pra testar no jogo, pôr em `src/client/Pets/init.client.luau`.
6. `lune run tests/run`, `bash scripts/analyze.sh`, `lune run scripts/build_pet_packs` (gera a pasta e o zip).

## Comandos

```bash
lune run tests/run                 # monta o place com rojo e roda todos os testes
lune run tests/run -- snake        # só os specs que batem com o filtro (--no-build reaproveita o place)
bash scripts/analyze.sh            # luau-lsp strict
lune run scripts/build_pet_packs   # gera "Work꞉ pet animation" e "Work pet animation.zip"
```

Ferramentas e versões em `rokit.toml` (`rokit install`).

## Coisas que já custaram caro descobrir

- O `CFrame.lookAt` do Lune olha pro lado contrário (no Z). O sandbox dos testes corrige; nos specs use
  `require("../harness/Datatypes").CFrame` se precisar de lookAt.
- O stylua reescreve placeholder `{{X}}` em código Luau (vira tabela aninhada que ainda compila). Nos templates
  em `packs/` use `__X__` em código e `{{X}}` só em comentário/string.
- No harness o `Workspace:Raycast` sempre erra: os pets caem na altura do pé do dono.
- Os sons ProSoundEffects (licenciados pela Roblox) funcionam em qualquer jogo. O chiado da cobra tem 2,8 s de
  silêncio no começo, por isso `SoundStart = 2.8`.
- Os worktrees de agentes ficam em `.claude/worktrees/`: não deixar o `git add -A` pegar eles.
