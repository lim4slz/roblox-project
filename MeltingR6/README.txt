MELTING R6
==========

Personagem R6 com a cabeça derretendo: olho saltado, órbita vazia com o nervo
pendurado e um sorrisão cheio de dente. Corpo no formato clássico do R6
(Torso, braços e pernas de sempre), então funciona com animações R6.

O rig é o mesmo de um R6 normal do Roblox: Humanoid (RigType R6),
HumanoidRootPart e os Motor6D Neck, Left/Right Shoulder, Left/Right Hip e
RootJoint, com os nomes que o Animate e o Animation Editor esperam.


O QUE TEM NESTA PASTA
---------------------

As pastas têm o nome do lugar do Explorer onde cada arquivo vai:

  MeltingR6/
    README.txt                  este arquivo
    Workspace/
      MeltingR6.glb             o modelo 3D, entra pelo Importer 3D
    ServerScriptService/
      MeltingR6Rig.rbxm         arraste no ServerScriptService
    Teste/
      MeltingR6_Teste.rbxl      place vazio já com o script, pra testar

Por que o modelo não vem dentro de um .rbxm? O Roblox só mostra malha que foi
enviada pra sua conta, e quem envia é o Importer 3D do Studio. Então o modelo
entra pelo Importer e o script monta o rig em cima dele.


INSTALAR NO SEU JOGO (5 MINUTOS)
--------------------------------

1. Abra o seu jogo no Roblox Studio. Se não aparecer o Explorer, abra em
   View > Explorer.

2. Importe o modelo: aba Avatar > Importer 3D (ou File > Import 3D) e
   escolha Workspace/MeltingR6.glb.
   Pode deixar tudo como vem, só confira se "Merge Meshes" está desligado.
   Clique em Import. O MeltingR6 aparece no Workspace.

3. Arraste ServerScriptService/MeltingR6Rig.rbxm do seu computador e solte em
   cima do ServerScriptService no Explorer. Outro jeito: botão direito no
   ServerScriptService > Insert from File... e escolha o arquivo.

4. Aperte Play. No Output aparece:
     [MeltingR6] Rig R6 montado: Workspace.MeltingR6
   e ele fica de pé no chão, montado.

Se o arquivo cair no lugar errado (no Workspace, por exemplo), é só arrastar
no Explorer pra onde ele deveria estar. Com tudo certo, o Explorer fica assim:

  Workspace
    MeltingR6              (Model)    o que veio do Importer
  ServerScriptService
    MeltingR6Rig           (Script)   monta o rig quando o jogo liga

Arquivo .rbxm não abre com dois cliques. Abra o Studio primeiro e arraste o
arquivo pra dentro da janela dele.


TESTAR NUM PLACE SEPARADO
-------------------------

Abra Teste/MeltingR6_Teste.rbxl no Studio (File > Open from File...). Ele já
tem chão, spawn e o script no ServerScriptService. Faça só o passo 2 (importar
o .glb), aperte Play e ande até ele.


COMO USAR NO JOGO
-----------------

Mais de um: duplique o MeltingR6 no Workspace (Ctrl+D) quantas vezes quiser.
Todos que estiverem no Workspace quando o jogo liga são montados.

Spawnar por script: o script só monta o que está no Workspace na hora que o
servidor liga. Se você quer guardar no ServerStorage e clonar depois, monte
o rig antes no Studio (veja "Deixar montado no Studio" abaixo) e aí clone o
modelo já montado:

    local modelo = game.ServerStorage.MeltingR6:Clone()
    modelo:PivotTo(CFrame.new(0, 5, 0))
    modelo.Parent = workspace

Animar: o rig não vem com animação, ele fica parado em pé. Pra tocar uma
animação R6 (sua ou do Animation Editor), pelo servidor:

    local humanoide = workspace.MeltingR6.Humanoid
    local animacao = Instance.new("Animation")
    animacao.AnimationId = "rbxassetid://COLE_O_ID_AQUI"
    humanoide.Animator:LoadAnimation(animacao):Play()

Lembre que o Roblox só toca animação publicada pela mesma conta (ou grupo) que
é dona do jogo.

Andar até um ponto: como é um Humanoid normal, funciona igual a qualquer NPC:

    workspace.MeltingR6.Humanoid:MoveTo(Vector3.new(0, 0, -30))

Jogar com ele: monte no Studio (abaixo), renomeie o modelo pra
StarterCharacter e coloque dentro do StarterPlayer. O jogo precisa estar em R6
(Game Settings > Avatar > R6). Pra ele andar animado, dê Play, copie o script
"Animate" do seu personagem (Workspace > seu nome), pare o jogo e cole o
Animate dentro do StarterCharacter.


DEIXAR MONTADO NO STUDIO (PRA ANIMAR OU CLONAR)
------------------------------------------------

Pelo Play o rig só existe enquanto o jogo roda. Pra ele ficar montado de vez
no place (pra abrir no Animation Editor, por exemplo):

1. Dê dois cliques no MeltingR6Rig dentro do ServerScriptService e copie tudo
   (Ctrl+A, Ctrl+C).
2. View > Command Bar, cole e aperte Enter.

Pronto, o MeltingR6 fica com Humanoid e Motor6D salvos no place. Dá pra
desfazer com Ctrl+Z. Pode deixar o script no ServerScriptService mesmo assim:
o que já está montado ele não mexe.


SE ALGO DER ERRADO
------------------

"Não achei o modelo importado no Workspace"
    O modelo não está no Workspace ou foi importado com "Merge Meshes" ligado
    (vira uma peça só). Importe de novo com essa opção desligada.

"A malha veio girada na importação"
    O rig funciona normal. Só importa se você usa script que escreve o
    Neck.C0 com valor fixo (cabeça seguindo o mouse, por exemplo): aí importe
    de novo trocando "World Forward" entre Front e Back.

Ele veio gigante ou minúsculo
    Não precisa mexer, o script ajusta pro tamanho certo de R6.


DETALHES
--------

- A cabeça é dividida em várias peças (Head, Mouth, EyeSockets, PoppingEye,
  Nerve, Teeth e Gums) porque o Roblox não aceita malha com mais de uns
  20 mil triângulos. Fica tudo soldado na Head, sem massa e sem colisão.
- Só Torso e Head colidem, igual ao R6 normal.
- Uns 100 mil triângulos no total. Pra um monstro principal está tranquilo;
  se for colocar dezenas ao mesmo tempo, pode pesar em celular.
