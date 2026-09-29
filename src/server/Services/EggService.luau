-- 🐣 Ovos: ninho e chefão dão um ovo (da cor da raridade) que vai para a Chocadeira da fazenda.
-- Quanto mais raro, mais demora para chocar. O tempo usa os.time(), então continua contando
-- com o jogo fechado. Pronto → "Chocar" → o animal nasce na fazenda.
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

type Timer = { label: TextLabel, egg: any }
local folders: { [Player]: Instance } = {}
local timers: { [Player]: { Timer } } = {}

local function eggName(rarity: number): string
	return "Ovo " .. Rarities.label(rarity, false)
end

local function readyCount(profile): (number, number)
	local now = os.time()
	local ready, waiting = 0, 0
	for _, egg in profile.eggs do
		if now >= egg.readyAt then
			ready += 1
		else
			waiting += 1
		end
	end
	return ready, waiting
end

local function hatch(player: Player, eggId: string)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	for index, egg in profile.eggs do
		if egg.id == eggId then
			local left = egg.readyAt - os.time()
			if left > 0 then
				Notify.toast(player, "⏳ Ainda falta " .. Format.time(left) .. " para chocar", Color3.fromRGB(255, 200, 120))
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
					else "Foi para a sua fazenda: +💰 " .. Format.rate(Balance.animalProduction(shown)) .. "/s",
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
	local shell = Instance.new("Part")
	shell.Name = "Ovo"
	shell.Shape = Enum.PartType.Ball
	shell.Size = Vector3.one * 2.4
	shell.Color = color:Lerp(Color3.new(1, 1, 1), if rarity == 1 then 0.6 else 0.15)
	shell.Material = if rarity >= Rarities.LEGENDARY then Enum.Material.Neon else Enum.Material.SmoothPlastic
	shell.Anchored = true
	shell.CanCollide = false
	shell.CFrame = slot
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
	for index, egg in profile.eggs do
		if index > #slots then
			break
		end
		table.insert(timers[player], { label = buildEgg(folder, slots[index], egg, player), egg = egg })
	end
	local extra = #profile.eggs - #slots
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

-- Entrega um ovo (ninho, chefão…). A raridade já vem sorteada; brilhante fica em segredo.
function EggService.give(player: Player, species: string, rarity: number, shiny: boolean, title: string?)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	profile.nextEggId = (profile.nextEggId or 1) + 1
	local seconds = EggService.HATCH_SECONDS[rarity] or 10
	table.insert(profile.eggs, {
		id = "e" .. profile.nextEggId,
		species = species,
		rarity = rarity,
		shiny = shiny,
		readyAt = os.time() + seconds,
	})
	Notify.reveal(player, {
		title = title or "🥚 VOCÊ PEGOU UM OVO!",
		name = eggName(rarity),
		color = Rarities.list[rarity].color,
		sub = "Foi para a 🐣 Chocadeira da sua fazenda. Choca em " .. Format.time(seconds),
	})
	DataService.push(player)
	EggService.refresh(player)
end

function EggService.release(player: Player)
	if folders[player] then
		folders[player]:Destroy()
	end
	folders[player] = nil
	timers[player] = nil
end

function EggService.init()
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
				end
			end
		end
	end)
end

return EggService
