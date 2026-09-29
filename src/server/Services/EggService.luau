-- 🐣 Ovos: o ninho dá um ovo (da cor da raridade) que o jogador CARREGA nos braços até a
-- Chocadeira da fazenda. Se um guardião pegar, o ovo cai e dá para pegar de volta por um tempo.
-- Na Chocadeira, quanto mais raro, mais demora para chocar. O tempo usa os.time(), então
-- continua contando com o jogo fechado. Pronto → "Chocar" → o animal nasce na fazenda.
-- Ovo do chefão e do prêmio diário vão direto para a Chocadeira.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnimalModel = require(Shared.AnimalModel)
local Balance = require(Shared.Balance)
local Format = require(Shared.Format)
local Rarities = require(Shared.Config.Rarities)
local Style = require(Shared.Style)

local DataService = require(script.Parent.DataService)
local FarmService = require(script.Parent.FarmService)
local Notify = require(script.Parent.Notify)

local EggService = {}

-- Segundos para chocar por raridade: Comum, Incomum, Rara, Épica, Lendária, Mítica.
EggService.HATCH_SECONDS = { 10, 30, 60, 120, 300, 600 }
local READY = Color3.fromRGB(95, 235, 70)
local ORANGE = Color3.fromRGB(255, 200, 120)
local PLACE_DISTANCE = 12
local DROP_SECONDS = 30
-- Onde o ovo fica em relação ao HumanoidRootPart: na frente do peito, entre as mãos.
local CARRY_OFFSET = CFrame.new(0, 0.55, -1.75)
-- Atributo no personagem que faz o cliente pôr os braços na pose de segurar.
local CARRY_ATTRIBUTE = "CarregandoOvo"

type Timer = { label: TextLabel, egg: any }
local folders: { [Player]: Instance } = {}
local timers: { [Player]: { Timer } } = {}
local carried: { [Player]: BasePart } = {}
local dropped: { [Player]: Model } = {}

local function eggName(rarity: number): string
	return "Ovo " .. Rarities.label(rarity, false)
end

local function carriedEgg(profile): any
	for _, egg in profile.eggs do
		if egg.carried then
			return egg
		end
	end
	return nil
end

function EggService.isCarrying(player: Player): boolean
	local profile = DataService.get(player)
	return profile ~= nil and carriedEgg(profile) ~= nil
end

local function readyCount(profile): (number, number)
	local now = os.time()
	local ready, waiting = 0, 0
	for _, egg in profile.eggs do
		if not egg.carried then
			if now >= egg.readyAt then
				ready += 1
			else
				waiting += 1
			end
		end
	end
	return ready, waiting
end

-- Casca do ovo na cor da raridade (Lendário brilha, Mítico é arco-íris, Raro+ solta brilhinho).
local function shellFor(rarity: number, size: number): Part
	local color = Rarities.list[rarity].color
	local shell = Instance.new("Part")
	shell.Name = "Ovo"
	shell.Shape = Enum.PartType.Ball
	shell.Size = Vector3.one * size
	shell.Color = color:Lerp(Color3.new(1, 1, 1), if rarity == 1 then 0.6 else 0.15)
	shell.Material = if rarity >= Rarities.LEGENDARY then Enum.Material.Neon else Enum.Material.SmoothPlastic
	shell.CanCollide = false
	shell.CanQuery = false
	shell.CanTouch = false
	shell.Massless = true
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(1, 1.3, 1)
	mesh.Parent = shell
	if rarity >= Rarities.MAX then
		CollectionService:AddTag(shell, AnimalModel.RAINBOW_TAG)
	end
	if rarity >= 3 then
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkles.Color = ColorSequence.new(color)
		sparkles.LightEmission = 1
		sparkles.Rate = rarity
		sparkles.Lifetime = NumberRange.new(0.6, 1.2)
		sparkles.Speed = NumberRange.new(0.5, 1.5)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Size = NumberSequence.new(0.35, 0)
		sparkles.Parent = shell
	end
	return shell
end

local function hatch(player: Player, eggId: string)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	for index, egg in profile.eggs do
		if egg.id == eggId and not egg.carried then
			local left = egg.readyAt - os.time()
			if left > 0 then
				Notify.toast(player, "⏳ Ainda falta " .. Format.time(left) .. " para chocar", ORANGE)
				return
			end
			table.remove(profile.eggs, index)
			profile.stats.hatched = (profile.stats.hatched or 0) + 1
			local animal, soldFor = FarmService.addAnimal(player, egg.species, egg.rarity, egg.shiny)
			local shown = animal or { id = "", species = egg.species, rarity = egg.rarity, shiny = egg.shiny }
			Notify.reveal(player, {
				title = "🐣 NASCEU!",
				name = Balance.animalName(shown),
				color = Rarities.list[egg.rarity].color,
				sub = if soldFor
					then "Fazenda cheia! Vendido por 💰 " .. Format.number(soldFor) .. " — aumente a fazenda na 🛒 Loja"
					else "+💰 " .. Format.rate(Balance.animalProduction(shown)) .. "/s  •  equipe como 🐾 pet em Animais!",
			})
			DataService.push(player)
			EggService.refresh(player)
			return
		end
	end
end

local function buildEgg(parent: Instance, slot: CFrame, egg, owner: Player): TextLabel
	local rarity = egg.rarity
	local color = Rarities.list[rarity].color
	local shell = shellFor(rarity, 2.4)
	shell.Anchored = true
	shell.CanQuery = true
	shell.CFrame = slot

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(170, 52)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.5)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.Text = eggName(rarity)
	title.TextColor3 = color
	Style.outline(title, 2)
	title.Parent = gui
	local timer = Instance.new("TextLabel")
	timer.BackgroundTransparency = 1
	timer.Position = UDim2.fromScale(0, 0.5)
	timer.Size = UDim2.fromScale(1, 0.5)
	timer.Font = Enum.Font.FredokaOne
	timer.TextScaled = true
	timer.TextColor3 = Color3.new(1, 1, 1)
	Style.outline(timer, 2)
	timer.Parent = gui
	gui.Parent = shell

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Chocar"
	prompt.ObjectText = eggName(rarity)
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = shell
	prompt.Triggered:Connect(function(player)
		if player ~= owner then
			Notify.toast(player, "Esse ovo é de " .. owner.DisplayName, Color3.fromRGB(255, 120, 100))
			return
		end
		hatch(owner, egg.id)
	end)
	shell.Parent = parent
	return timer
end

-- Remonta os ovos na Chocadeira do jogador (até 3 à mostra; o resto fica na fila).
function EggService.refresh(player: Player)
	local profile = DataService.get(player)
	local plot = FarmService.plotFor(player)
	if folders[player] then
		folders[player]:Destroy()
		folders[player] = nil
	end
	timers[player] = {}
	if not profile or not plot then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Ovos"
	local slots = plot.incubator.slots
	local shown, total = 0, 0
	for _, egg in profile.eggs do
		if not egg.carried then
			total += 1
			if shown < #slots then
				shown += 1
				table.insert(timers[player], { label = buildEgg(folder, slots[shown], egg, player), egg = egg })
			end
		end
	end
	local extra = total - shown
	if extra > 0 then
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(220, 30)
		gui.StudsOffset = Vector3.new(0, -2.2, 0)
		gui.MaxDistance = 90
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.Text = "+" .. extra .. " ovos na fila"
		label.TextColor3 = Color3.new(1, 1, 1)
		Style.outline(label, 2)
		label.Parent = gui
		gui.Name = "Fila"
		-- Mostra em cima da mesa, mas mora na pasta para sumir junto no próximo refresh.
		gui.Adornee = plot.incubator.anchor
		gui.Parent = folder
	end
	folder.Parent = (plot.animals :: Instance).Parent
	folders[player] = folder
end

-- ---------- Carregar nos braços ----------

local function detachCarry(player: Player)
	if carried[player] then
		carried[player]:Destroy()
		carried[player] = nil
	end
	local character = player.Character
	if character then
		character:SetAttribute(CARRY_ATTRIBUTE, nil)
	end
	player:SetAttribute("OvoNaMao", nil)
end

-- Põe o ovo na frente do peito do personagem (soldado no HumanoidRootPart).
local function attachCarry(player: Player)
	local profile = DataService.get(player)
	local egg = profile and carriedEgg(profile)
	if carried[player] then
		carried[player]:Destroy()
		carried[player] = nil
	end
	if not egg or dropped[player] then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not root then
		return
	end
	local shell = shellFor(egg.rarity, 2)
	shell.Name = "OvoCarregado"
	shell.Anchored = false
	shell.CFrame = root.CFrame * CARRY_OFFSET
	local weld = Instance.new("Weld")
	weld.Part0 = root
	weld.Part1 = shell
	weld.C0 = CARRY_OFFSET
	weld.Parent = shell
	local light = Instance.new("PointLight")
	light.Color = Rarities.list[egg.rarity].color
	light.Range = 7
	light.Brightness = 1.2
	light.Parent = shell
	shell.Parent = character
	carried[player] = shell
	character:SetAttribute(CARRY_ATTRIBUTE, true)
	player:SetAttribute("OvoNaMao", eggName(egg.rarity))
end

-- Coloca o ovo carregado na Chocadeira: o cronômetro começa agora.
function EggService.place(player: Player)
	local profile = DataService.get(player)
	local egg = profile and carriedEgg(profile)
	if not egg then
		return
	end
	local seconds = EggService.HATCH_SECONDS[egg.rarity] or 10
	egg.carried = nil
	egg.readyAt = os.time() + seconds
	profile.stats.placed = (profile.stats.placed or 0) + 1
	detachCarry(player)
	Notify.big(
		player,
		"🐣 OVO NA CHOCADEIRA!",
		eggName(egg.rarity) .. " choca em " .. Format.time(seconds) .. ". Enquanto isso, treine na 🏃 esteira!",
		Rarities.list[egg.rarity].color,
		"guardar"
	)
	DataService.push(player)
	EggService.refresh(player)
end

-- Guardião (ou estouro da boiada) pegou quem carregava: o ovo cai no chão.
function EggService.drop(player: Player, position: Vector3, parent: Instance)
	local profile = DataService.get(player)
	local egg = profile and carriedEgg(profile)
	if not egg or dropped[player] then
		return
	end
	detachCarry(player)
	local model = Instance.new("Model")
	model.Name = "OvoCaido"
	local shell = shellFor(egg.rarity, 2.2)
	shell.Anchored = true
	shell.CanQuery = true
	shell.CFrame = CFrame.new(position.X, 1.4, position.Z)
	shell.Parent = model
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 40)
	gui.StudsOffset = Vector3.new(0, 2.4, 0)
	gui.MaxDistance = 120
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = "🥚 Seu ovo caiu!"
	label.TextColor3 = ORANGE
	Style.outline(label, 2.5)
	label.Parent = gui
	gui.Parent = shell
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pegar ovo"
	prompt.ObjectText = eggName(egg.rarity)
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = shell
	model.Parent = parent
	dropped[player] = model
	player:SetAttribute("OvoCaido", true)

	local done = false
	local function finish()
		done = true
		model:Destroy()
		dropped[player] = nil
		player:SetAttribute("OvoCaido", nil)
	end
	prompt.Triggered:Connect(function(who)
		if done then
			return
		end
		if who ~= player then
			Notify.toast(who, "Esse ovo é de " .. player.DisplayName, Color3.fromRGB(255, 120, 100))
			return
		end
		finish()
		attachCarry(player)
		Notify.toast(player, "🥚 Pegou o ovo de volta! Leve para a Chocadeira", READY)
	end)
	Notify.toast(player, "🥚 Você deixou o ovo cair! Pegue de volta em " .. DROP_SECONDS .. "s", ORANGE)
	-- Contagem regressiva; se ninguém pegar, o ovo quebra.
	task.spawn(function()
		for left = DROP_SECONDS, 1, -1 do
			if done then
				return
			end
			label.Text = "🥚 Pegue seu ovo! " .. left .. "s"
			task.wait(1)
		end
		if done then
			return
		end
		finish()
		local current = DataService.get(player)
		if current then
			local index = table.find(current.eggs, egg)
			if index then
				table.remove(current.eggs, index)
			end
			DataService.push(player)
		end
		if player.Parent then
			Notify.toast(player, "💔 O ovo quebrou… abra outro ninho!", Color3.fromRGB(255, 120, 100))
		end
	end)
end

-- Entrega um ovo. A raridade já vem sorteada; brilhante fica em segredo.
-- carry = true: o jogador leva nos braços (ninho). Se já estiver carregando um, vai direto.
function EggService.give(player: Player, species: string, rarity: number, shiny: boolean, title: string?, carry: boolean?)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	profile.nextEggId = (profile.nextEggId or 1) + 1
	local seconds = EggService.HATCH_SECONDS[rarity] or 10
	local inArms = carry == true and carriedEgg(profile) == nil
	local egg = {
		id = "e" .. profile.nextEggId,
		species = species,
		rarity = rarity,
		shiny = shiny,
		readyAt = if inArms then 0 else os.time() + seconds,
		carried = if inArms then true else nil,
	}
	table.insert(profile.eggs, egg)
	Notify.reveal(player, {
		title = title or "🥚 VOCÊ PEGOU UM OVO!",
		name = eggName(rarity),
		color = Rarities.list[rarity].color,
		sub = if inArms
			then "Leve nos braços até a 🐣 Chocadeira da sua fazenda! Cuidado com os guardiões"
			else "Foi para a 🐣 Chocadeira da sua fazenda. Choca em " .. Format.time(seconds),
	})
	if inArms then
		attachCarry(player)
	end
	DataService.push(player)
	EggService.refresh(player)
end

-- Ao entrar: um ovo que ficou "nos braços" (servidor caiu) vai para a Chocadeira.
function EggService.setup(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	for _, egg in profile.eggs do
		if egg.carried then
			egg.carried = nil
			egg.readyAt = os.time() + (EggService.HATCH_SECONDS[egg.rarity] or 10)
		end
	end
	EggService.refresh(player)
end

function EggService.release(player: Player)
	-- Saiu carregando (ou com o ovo caído): o ovo vai direto para a Chocadeira, não perde.
	local profile = DataService.get(player)
	local egg = profile and carriedEgg(profile)
	if egg then
		egg.carried = nil
		egg.readyAt = os.time() + (EggService.HATCH_SECONDS[egg.rarity] or 10)
	end
	for _, list in { folders, dropped, carried } do
		if list[player] then
			list[player]:Destroy()
		end
		list[player] = nil
	end
	timers[player] = nil
end

local function watchCharacter(player: Player)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart", 10)
		task.wait(0.5)
		if player.Character == character then
			attachCarry(player)
		end
	end)
end

function EggService.init()
	Players.PlayerAdded:Connect(watchCharacter)
	for _, player in Players:GetPlayers() do
		watchCharacter(player)
	end
	-- Chegou perto da Chocadeira carregando o ovo: coloca sozinho.
	task.spawn(function()
		while true do
			task.wait(0.25)
			for player, shell in carried do
				local plot = FarmService.plotFor(player)
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if plot and root and shell.Parent then
					if (root.Position - plot.incubator.anchor.Position).Magnitude <= PLACE_DISTANCE then
						EggService.place(player)
					end
				end
			end
		end
	end)
	-- Atualiza os cronômetros e conta ovos prontos/esperando (o guia usa).
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.time()
			for _, player in Players:GetPlayers() do
				for _, timer in timers[player] or {} do
					local left = timer.egg.readyAt - now
					if left <= 0 then
						timer.label.Text = "✅ PRONTO! Choque"
						timer.label.TextColor3 = READY
					else
						timer.label.Text = "⏳ " .. Format.time(left)
					end
				end
				local profile = DataService.get(player)
				if profile then
					local ready, waiting = readyCount(profile)
					player:SetAttribute("OvosProntos", ready)
					player:SetAttribute("OvosEsperando", waiting)
					-- Personagem novo (morreu/resetou) sem o ovo na mão: põe de volta.
					if carriedEgg(profile) and not carried[player] and not dropped[player] and player.Character then
						attachCarry(player)
					end
				end
			end
		end
	end)
end

return EggService
