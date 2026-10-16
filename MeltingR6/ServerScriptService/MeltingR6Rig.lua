--[[
	Monta o rig R6 do MeltingR6 (Humanoid, HumanoidRootPart e os Motor6D).

	No jogo: deixe este Script no ServerScriptService. Quando o servidor liga, todo MeltingR6
	importado que estiver no Workspace vira um personagem R6 montado.

	No Studio (pra animar no Animation Editor): copie tudo daqui, cole na Command Bar e aperte
	Enter. Aí o rig fica salvo no place e o script não mexe mais nele.
]]

local CORPO = { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }

-- C0 padrão do R6 (os mesmos do Rig Builder), no espaço do torso
local JUNTAS = {
	{ "RootJoint", "HumanoidRootPart", "Torso", CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0) },
	{ "Neck", "Torso", "Head", CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0) },
	{ "Right Shoulder", "Torso", "Right Arm", CFrame.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0) },
	{ "Left Shoulder", "Torso", "Left Arm", CFrame.new(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0) },
	{ "Right Hip", "Torso", "Right Leg", CFrame.new(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0) },
	{ "Left Hip", "Torso", "Left Leg", CFrame.new(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0) },
}

-- "Left Arm", "Left_Arm" e "LeftArm" contam como o mesmo nome
local function chave(nome)
	return (string.lower(nome):gsub("[^%w]", ""))
end

local function pecasDe(modelo)
	local pecas = {}
	for _, obj in modelo:GetDescendants() do
		if obj:IsA("BasePart") then
			local k = chave(obj.Name)
			if not pecas[k] then
				pecas[k] = obj
			end
		end
	end
	return pecas
end

local function serveDeBase(obj)
	if not obj:IsA("Model") or obj:FindFirstChildWhichIsA("Humanoid") then
		return false
	end
	local pecas = pecasDe(obj)
	for _, nome in CORPO do
		if not pecas[chave(nome)] then
			return false
		end
	end
	return true
end

local function acharModelos()
	local achados = {}
	local function olhar(obj)
		local atual = obj
		while atual and atual ~= game and atual ~= workspace do
			if serveDeBase(atual) then
				if not table.find(achados, atual) then
					table.insert(achados, atual)
				end
				return
			end
			atual = atual.Parent
		end
	end

	local ok, selecao = pcall(function()
		return game:GetService("Selection"):Get()
	end)
	if ok then
		for _, obj in selecao do
			olhar(obj)
		end
	end
	for _, obj in workspace:GetChildren() do
		olhar(obj)
	end
	return achados
end

local function montar(modelo)
	local pecas = pecasDe(modelo)
	local partes = {}
	local doCorpo = {}
	for _, nome in CORPO do
		local p = pecas[chave(nome)]
		p.Name = nome
		p.Parent = modelo -- o Humanoid procura as partes direto no modelo
		partes[nome] = p
		doCorpo[p] = true
	end
	local torso = partes.Torso

	local function centroPernas()
		return (partes["Left Leg"].Position + partes["Right Leg"].Position) / 2
	end

	-- escala: no R6 o centro do torso fica 2 studs acima do centro das pernas
	local altura = (torso.Position - centroPernas()).Magnitude
	if math.abs(altura - 2) > 0.01 then
		modelo:ScaleTo(modelo:GetScale() * 2 / altura)
	end

	-- referencial do corpo tirado das posições das peças, então não importa
	-- como o importador girou o modelo
	local cima = (torso.Position - centroPernas()).Unit
	local lado = partes["Right Arm"].Position - partes["Left Arm"].Position
	local direita = (lado - cima * lado:Dot(cima)).Unit
	local atual = CFrame.fromMatrix(torso.Position, direita, cima)

	-- deixa em pé, olhando para o mesmo lado
	local frente = atual.LookVector * Vector3.new(1, 0, 1)
	if frente.Magnitude < 1e-3 then
		frente = Vector3.new(0, 0, -1)
	end
	local corpo = CFrame.lookAt(torso.Position, torso.Position + frente.Unit)
	if (atual.UpVector - corpo.UpVector).Magnitude > 1e-4 then
		modelo:PivotTo(corpo * atual:Inverse() * modelo:GetPivot())
	end

	local raiz = Instance.new("Part")
	raiz.Name = "HumanoidRootPart"
	raiz.Size = Vector3.new(2, 2, 1)
	raiz.CFrame = corpo
	raiz.Transparency = 1
	raiz.CanCollide = false
	raiz.Anchored = false
	raiz.Parent = modelo
	partes.HumanoidRootPart = raiz

	for nome, p in partes do
		if nome ~= "HumanoidRootPart" then
			p.Anchored = false
			p.Massless = false
			p.CanCollide = nome == "Torso" or nome == "Head"
			pcall(function()
				p.CollisionFidelity = Enum.CollisionFidelity.Box
			end)
		end
	end

	for _, j in JUNTAS do
		local p0, p1 = partes[j[2]], partes[j[3]]
		local junta = corpo * j[4]
		local motor = Instance.new("Motor6D")
		motor.Name = j[1]
		motor.Part0 = p0
		motor.Part1 = p1
		motor.C0 = p0.CFrame:ToObjectSpace(junta)
		motor.C1 = p1.CFrame:ToObjectSpace(junta)
		motor.MaxVelocity = 0.1
		motor.Parent = p0
	end

	-- o resto (olho, dentes, gengiva, nervo, boca, órbitas) é soldado na parte mais próxima
	for _, obj in modelo:GetDescendants() do
		if obj:IsA("BasePart") and not doCorpo[obj] and obj ~= raiz then
			local alvo, menor = torso, math.huge
			for _, nome in CORPO do
				local d = (partes[nome].Position - obj.Position).Magnitude
				if d < menor then
					alvo, menor = partes[nome], d
				end
			end
			obj.Anchored = false
			obj.Massless = true
			obj.CanCollide = false
			obj.CanTouch = false
			obj.CanQuery = false
			obj.Parent = modelo
			local solda = Instance.new("Weld")
			solda.Name = "Solda"
			solda.Part0 = alvo
			solda.Part1 = obj
			solda.C0 = alvo.CFrame:ToObjectSpace(obj.CFrame)
			solda.Parent = obj
		end
	end

	-- limpa as pastas/modelos que o importador criou e ficaram vazios
	local apagou = true
	while apagou do
		apagou = false
		for _, obj in modelo:GetDescendants() do
			if (obj:IsA("Model") or obj:IsA("Folder")) and #obj:GetChildren() == 0 then
				obj:Destroy()
				apagou = true
			end
		end
	end

	local humanoide = Instance.new("Humanoid")
	humanoide.RigType = Enum.HumanoidRigType.R6
	humanoide.Parent = modelo
	Instance.new("Animator").Parent = humanoide

	modelo.PrimaryPart = raiz

	-- se a malha veio girada dentro da peça, o rig funciona igual, mas os C0 não ficam
	-- com os valores de sempre (scripts que escrevem Neck.C0 fixo iam girar a cabeça)
	local alinhado = torso.CFrame.LookVector:Dot(corpo.LookVector) > 0.99
		and torso.CFrame.UpVector:Dot(corpo.UpVector) > 0.99
	if not alinhado then
		warn("[MeltingR6] A malha veio girada na importação. O rig funciona, mas os C0 ficaram "
			.. "fora do padrão. Se for usar scripts com C0 fixo (ex.: cabeça seguindo o mouse), "
			.. "reimporte mudando World Forward (Front/Back) até o rosto aparecer de frente no preview.")
	end
end

local modelos = acharModelos()
if #modelos == 0 then
	if not workspace:FindFirstChildWhichIsA("Humanoid", true) then
		warn("[MeltingR6] Não achei o modelo importado no Workspace (precisa ter Head, Torso, "
			.. "Left Arm, Right Arm, Left Leg e Right Leg). Importe o MeltingR6.glb sem Merge Meshes.")
	end
	return
end

local historico = game:GetService("ChangeHistoryService")
local gravacao
pcall(function()
	gravacao = historico:TryBeginRecording("Montar rig R6")
end)

local montados = {}
local tudoCerto = true
for _, modelo in modelos do
	local ok, erro = pcall(montar, modelo)
	if ok then
		table.insert(montados, modelo)
		print("[MeltingR6] Rig R6 montado: " .. modelo:GetFullName())
	else
		tudoCerto = false
		warn("[MeltingR6] Erro ao montar " .. modelo:GetFullName() .. ": " .. tostring(erro))
	end
end

if gravacao then
	pcall(function()
		historico:FinishRecording(
			gravacao,
			if tudoCerto then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel
		)
	end)
end

pcall(function()
	game:GetService("Selection"):Set(montados)
end)
