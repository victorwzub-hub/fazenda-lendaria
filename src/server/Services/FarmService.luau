local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnimalModel = require(Shared.AnimalModel)
local Balance = require(Shared.Balance)
local Format = require(Shared.Format)
local Rarities = require(Shared.Config.Rarities)
local Species = require(Shared.Config.Species)
local Style = require(Shared.Style)

local Basket = require(script.Parent.Basket)
local DataService = require(script.Parent.DataService)
local Notify = require(script.Parent.Notify)
local PassService = require(script.Parent.PassService)
local PetService = require(script.Parent.PetService)
local Teleport = require(script.Parent.Teleport)

local FarmService = {}

local BOUNDS = { minX = -30, maxX = 30, minZ = -29, maxZ = 13 }
local WALK_SPEED = 5
local HUB_SPAWN = CFrame.new(0, 3, 14)
local GOLD = Color3.fromRGB(255, 205, 60)

local plots = {}
local plotOf: { [Player]: any } = {}
local modelsOf: { [Player]: { [string]: Model } } = {}
local rng = Random.new()

local function randomSpot(plot): CFrame
	local x = rng:NextNumber(BOUNDS.minX, BOUNDS.maxX)
	local z = rng:NextNumber(BOUNDS.minZ, BOUNDS.maxZ)
	return plot.cframe * CFrame.new(x, 0, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
end

-- Ações paradas que o cliente anima (client/AnimalAnimator): farejar, comer, dormir.
local IDLE_ACTIONS = {
	{ name = "farejar", weight = 3, min = 2, max = 4 },
	{ name = "comer", weight = 3, min = 3, max = 5 },
	{ name = "dormir", weight = 1, min = 6, max = 10 },
}

local function idleAction(model: Model)
	local total = 0
	for _, action in IDLE_ACTIONS do
		total += action.weight
	end
	local roll = rng:NextNumber(0, total)
	for _, action in IDLE_ACTIONS do
		roll -= action.weight
		if roll <= 0 then
			model:SetAttribute("Acao", action.name)
			task.wait(rng:NextNumber(action.min, action.max))
			model:SetAttribute("Acao", nil)
			return
		end
	end
end

local function wander(model: Model, plot)
	local root = model.PrimaryPart :: BasePart
	while model.Parent do
		task.wait(rng:NextNumber(1, 3))
		if not model.Parent then
			break
		end
		if rng:NextNumber() < 0.45 then
			idleAction(model)
			continue
		end
		local from = root.Position
		local target = randomSpot(plot).Position
		local flat = Vector3.new(target.X, from.Y, target.Z)
		local distance = (flat - from).Magnitude
		if distance > 1 then
			local facing = CFrame.lookAt(from, flat)
			TweenService:Create(root, TweenInfo.new(0.3), { CFrame = facing }):Play()
			task.wait(0.3)
			local duration = distance / WALK_SPEED
			TweenService
				:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), { CFrame = facing + (flat - from) })
				:Play()
			task.wait(duration)
		end
	end
end

local function despawnModel(player: Player, animalId: string)
	local models = modelsOf[player]
	if models and models[animalId] then
		models[animalId]:Destroy()
		models[animalId] = nil
	end
end

local function spawnModel(player: Player, animal)
	local plot = plotOf[player]
	local models = modelsOf[player]
	local profile = DataService.get(player)
	if not plot or not models or not profile then
		return
	end
	-- Pet equipado anda com o dono, não fica na fazenda.
	if Balance.isEquipped(profile, animal.id) then
		despawnModel(player, animal.id)
		return
	end
	local previous = models[animal.id]
	local spot = if previous then previous:GetPivot() else randomSpot(plot)
	if previous then
		previous:Destroy()
	end
	local model = AnimalModel.build(animal.species, animal.rarity, animal.shiny, Balance.animalName(animal))
	model:PivotTo(spot)
	model.Parent = plot.animals
	models[animal.id] = model
	task.spawn(wander, model, plot)
end

local function findAnimal(profile, animalId: string): (any, number?)
	for i, animal in profile.animals do
		if animal.id == animalId then
			return animal, i
		end
	end
	return nil, nil
end

local function registerDiscovery(player: Player, profile, animal)
	local key = animal.species .. ":" .. animal.rarity
	if not profile.index[key] then
		profile.index[key] = true
		local count = Balance.indexCount(profile)
		if count % Balance.INDEX_STEP == 0 then
			Notify.big(
				player,
				"📖 ÍNDICE: " .. count .. " DESCOBERTAS!",
				"Bônus do índice agora: +" .. Balance.indexBonus(profile) .. "% de moedas para sempre",
				Color3.fromRGB(190, 130, 255),
				"revelar"
			)
		else
			Notify.toast(
				player,
				"📖 Nova descoberta no Índice! (" .. count .. " • faltam " .. (Balance.INDEX_STEP - count % Balance.INDEX_STEP) .. " para +" .. Balance.INDEX_BONUS .. "% moedas)",
				Color3.fromRGB(190, 130, 255)
			)
		end
	end
	if animal.rarity >= Rarities.LEGENDARY then
		profile.stats.legendaries += 1
		DataService.syncLegendaries(player)
		local species = Species.byId[animal.species]
		local article = if species.feminine then "uma" else "um"
		Notify.bigAll(
			"🌟 " .. player.DisplayName .. " conseguiu " .. article .. " " .. Balance.animalName(animal) .. "!",
			nil,
			Rarities.list[animal.rarity].color
		)
	end
end

function FarmService.assignPlot(player: Player)
	local profile = DataService.get(player)
	for _, plot in plots do
		if not plot.owner then
			plot.owner = player
			plot.sign.Text = "Fazenda de " .. player.DisplayName
			plotOf[player] = plot
			modelsOf[player] = {}
			for _, animal in profile.animals do
				spawnModel(player, animal)
			end
			FarmService.decorate(player)
			return plot
		end
	end
	warn("[FarmService] Sem lotes livres para", player.Name, "- aumente PLOT_COUNT ou reduza o máximo de jogadores")
	return nil
end

-- Enfeites da fazenda que aparecem conforme o nível de "Fazenda Maior".
local DECOR_LEVELS = { silo = 1, flores = 3, postes = 5, moinho = 8, cataVento = 12 }

local function decorPart(parent: Instance, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.Plastic
	if shape then
		part.Shape = shape
	end
	part.Parent = parent
	return part
end

function FarmService.decorate(player: Player)
	local plot = plotOf[player]
	local profile = DataService.get(player)
	if not plot or not profile then
		return
	end
	local level = profile.upgrades.Fazenda or 0
	plot.sign.Text = "🏡 Fazenda de " .. player.DisplayName .. " • Nv " .. level
	local plotModel = plot.animals.Parent :: Instance
	local old = plotModel:FindFirstChild("Melhorias")
	if old then
		old:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = "Melhorias"
	local at = plot.cframe

	if level >= DECOR_LEVELS.silo then
		local silo = at * CFrame.new(25, 0, 6)
		decorPart(model, Vector3.new(14, 7, 7), silo * CFrame.new(0, 7, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(200, 50, 45), nil, Enum.PartType.Cylinder)
		decorPart(model, Vector3.new(1, 7.2, 7.2), silo * CFrame.new(0, 10, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.new(1, 1, 1), nil, Enum.PartType.Cylinder)
		decorPart(model, Vector3.one * 7, silo * CFrame.new(0, 14, 0), Color3.fromRGB(190, 195, 205), Enum.Material.Metal, Enum.PartType.Ball)
	end
	if level >= DECOR_LEVELS.flores then
		local colors = { Color3.fromRGB(255, 90, 170), Color3.fromRGB(255, 225, 60), Color3.fromRGB(170, 110, 255) }
		for _, x in { -9, 9 } do
			local bed = at * CFrame.new(x, 0, -24)
			decorPart(model, Vector3.new(6, 0.8, 3), bed * CFrame.new(0, 0.4, 0), Color3.fromRGB(120, 75, 40), Enum.Material.WoodPlanks)
			for i = 1, 4 do
				decorPart(model, Vector3.new(0.9, 0.9, 0.9), bed * CFrame.new(-2.25 + i * 0.9, 1.2, (i % 2) * 0.6 - 0.3), colors[(i % #colors) + 1])
			end
		end
	end
	if level >= DECOR_LEVELS.postes then
		for _, x in { -31, 31 } do
			for _, z in { -31, 31 } do
				local post = at * CFrame.new(x, 0, z)
				decorPart(model, Vector3.new(0.7, 8, 0.7), post * CFrame.new(0, 4, 0), Color3.fromRGB(50, 50, 60), Enum.Material.Metal)
				local lamp = decorPart(model, Vector3.new(1.6, 1.4, 1.6), post * CFrame.new(0, 8.6, 0), Color3.fromRGB(255, 230, 140), Enum.Material.Neon)
				local light = Instance.new("PointLight")
				light.Color = Color3.fromRGB(255, 220, 150)
				light.Range = 18
				light.Brightness = 1.5
				light.Parent = lamp
			end
		end
	end
	if level >= DECOR_LEVELS.moinho then
		local mill = at * CFrame.new(-25, 0, 6)
		decorPart(model, Vector3.new(5, 14, 5), mill * CFrame.new(0, 7, 0), Color3.fromRGB(245, 240, 230), Enum.Material.WoodPlanks)
		decorPart(model, Vector3.new(6, 3, 6), mill * CFrame.new(0, 15.5, 0), Color3.fromRGB(200, 50, 45), Enum.Material.WoodPlanks)
		for i = 0, 3 do
			decorPart(model, Vector3.new(1.2, 9, 0.3), mill * CFrame.new(0, 12, -2.8) * CFrame.Angles(0, 0, math.rad(i * 90 + 20)) * CFrame.new(0, 4.5, 0), Color3.fromRGB(235, 225, 200), Enum.Material.WoodPlanks)
		end
	end
	if level >= DECOR_LEVELS.cataVento then
		local top = at * CFrame.new(0, 14.5, 24)
		decorPart(model, Vector3.new(0.3, 3, 0.3), top * CFrame.new(0, 1.5, 0), Color3.fromRGB(255, 200, 40), Enum.Material.Metal)
		decorPart(model, Vector3.new(3, 0.5, 0.3), top * CFrame.new(0, 2.6, 0), Color3.fromRGB(255, 200, 40), Enum.Material.Metal)
		decorPart(model, Vector3.one * 0.9, top * CFrame.new(0, 3.3, 0), Color3.fromRGB(255, 215, 80), Enum.Material.Neon, Enum.PartType.Ball)
	end

	Style.apply(model)
	model.Parent = plotModel
end

function FarmService.plotFor(player: Player)
	return plotOf[player]
end

-- Chamado quando algo que muda os bônus acontece (pets, renascer). init.server liga no
-- TrainingService para atualizar a placa da esteira.
FarmService.onBonusChanged = nil :: ((Player) -> ())?
FarmService.onPlotReleased = nil :: ((any) -> ())?

local function bonusChanged(player: Player)
	FarmService.applySpeed(player)
	Basket.refresh(player)
	PetService.refresh(player)
	if FarmService.onBonusChanged then
		FarmService.onBonusChanged(player)
	end
	DataService.push(player)
end

-- Remonta todos os bichos da fazenda (depois de renascer, por exemplo).
function FarmService.reloadAnimals(player: Player)
	local profile = DataService.get(player)
	local models = modelsOf[player]
	if not profile or not models then
		return
	end
	for id in models do
		despawnModel(player, id)
	end
	for _, animal in profile.animals do
		spawnModel(player, animal)
	end
	bonusChanged(player)
end

-- Equipar/desequipar um pet.
function FarmService.equip(player: Player, animalId: string): (boolean, string?)
	local profile = DataService.get(player)
	local animal = findAnimal(profile, animalId)
	if not animal then
		return false, "Animal não encontrado"
	end
	local index = table.find(profile.equipped, animalId)
	if index then
		table.remove(profile.equipped, index)
		spawnModel(player, animal)
		bonusChanged(player)
		return true, "🐾 " .. Balance.animalName(animal) .. " voltou para a fazenda"
	end
	if #profile.equipped >= Balance.petSlots(profile) then
		return false, "Pets cheios! (" .. Balance.petSlots(profile) .. ") Desequipe um ou renasça para ter mais espaço"
	end
	table.insert(profile.equipped, animalId)
	despawnModel(player, animalId)
	profile.stats.equips = (profile.stats.equips or 0) + 1
	bonusChanged(player)
	local stat, value = Balance.buffOf(animal)
	local buff = Species.buffs[stat]
	return true, "🐾 " .. Balance.animalName(animal) .. " equipado! " .. buff.emoji .. " +" .. value .. buff.suffix .. " " .. buff.label
end

-- Nota de "quão bom" é um pet: raridade conta muito, rotas mais difíceis contam mais.
local ROUTE_WEIGHT = { Galinheiro = 1, Chiqueiro = 1.3, Pasto = 1.6, Pradaria = 2 }

local function petScore(animal): number
	local species = Species.byId[animal.species]
	return (Balance.PET_BUFF_MULT[animal.rarity] or 1)
		* (if animal.shiny then Balance.SHINY_BUFF_MULT else 1)
		* (ROUTE_WEIGHT[species.route] or 1)
end

function FarmService.equipBest(player: Player): (boolean, string?)
	local profile = DataService.get(player)
	local list = table.clone(profile.animals)
	table.sort(list, function(a, b)
		local sa, sb = petScore(a), petScore(b)
		if sa ~= sb then
			return sa > sb
		end
		return a.id < b.id
	end)
	local previous = profile.equipped
	profile.equipped = {}
	for i = 1, math.min(Balance.petSlots(profile), #list) do
		table.insert(profile.equipped, list[i].id)
	end
	for _, animal in profile.animals do
		local was = table.find(previous, animal.id) ~= nil
		local now = Balance.isEquipped(profile, animal.id)
		if was ~= now then
			if now then
				despawnModel(player, animal.id)
			else
				spawnModel(player, animal)
			end
		end
	end
	profile.stats.equips = (profile.stats.equips or 0) + 1
	bonusChanged(player)
	return true, "🐾 Melhores pets equipados!"
end

function FarmService.releasePlot(player: Player)
	local plot = plotOf[player]
	if plot then
		plot.owner = nil
		plot.sign.Text = "Fazenda livre"
		if FarmService.onPlotReleased then
			FarmService.onPlotReleased(plot)
		end
		plot.animals:ClearAllChildren()
		local decorations = (plot.animals.Parent :: Instance):FindFirstChild("Melhorias")
		if decorations then
			decorations:Destroy()
		end
	end
	plotOf[player] = nil
	modelsOf[player] = nil
end

function FarmService.teleportHome(player: Player): (boolean, string?)
	local plot = plotOf[player]
	Teleport.to(player, if plot then plot.spawn else HUB_SPAWN)
	-- Chegou em casa: o que estava na cesta fica guardado de vez.
	Basket.deposit(player)
	return true, nil
end

function FarmService.applySpeed(player: Player)
	local profile = DataService.get(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if profile and humanoid then
		local boosted = (player:GetAttribute("BoostVelocidade") or 0) > Workspace:GetServerTimeNow()
		local speed = Balance.walkSpeed(profile) + (if boosted then Balance.BOOST_SPEED else 0)
		-- Corrida a cavalo (Pradaria): velocidade fixa do cavalo.
		local race = player:GetAttribute("CorridaVelocidade")
		if race then
			speed = race
		end
		humanoid.WalkSpeed = speed
		-- O cliente usa este valor como base (lama deixa lento, árvore limita…).
		player:SetAttribute("Velocidade", speed)
		humanoid.UseJumpPower = false
		humanoid.JumpHeight = Balance.jumpHeight(profile)
	end
end

function FarmService.onCharacter(player: Player, character: Model)
	character:WaitForChild("HumanoidRootPart", 10)
	if not DataService.get(player) or player.Character ~= character then
		return
	end
	task.wait()
	FarmService.applySpeed(player)
	FarmService.teleportHome(player)
end

function FarmService.addAnimal(player: Player, speciesId: string, rarity: number, shiny: boolean): (any, number?)
	local profile = DataService.get(player)
	if not profile then
		return nil, nil
	end
	local animal = { id = "a" .. profile.nextAnimalId, species = speciesId, rarity = rarity, shiny = shiny }
	profile.nextAnimalId += 1
	registerDiscovery(player, profile, animal)

	local capacity = Balance.capacity(profile, PassService.has(player, "FazendaGigante"))
	if #profile.animals >= capacity then
		local value = Balance.sellPrice(animal)
		DataService.addCoins(player, value)
		DataService.push(player)
		return nil, value
	end

	table.insert(profile.animals, animal)
	spawnModel(player, animal)
	DataService.push(player)
	return animal, nil
end

function FarmService.evolve(player: Player, animalId: string): (boolean, string?)
	local profile = DataService.get(player)
	local animal = findAnimal(profile, animalId)
	if not animal then
		return false, "Animal não encontrado"
	end
	if animal.rarity >= Rarities.MAX then
		return false, "Esse animal já está no máximo!"
	end
	local cost = Balance.evolveCost(animal.species, animal.rarity)
	if not cost then
		return false, "Não dá para evoluir"
	end
	local ok, reason = Balance.missingForCost(profile, profile.coins, cost)
	if not ok then
		return false, reason
	end

	DataService.spendCoins(player, cost.coins)
	for materialId, amount in cost.materials do
		profile.materials[materialId] -= amount
	end
	animal.rarity += 1
	profile.stats.evolved = (profile.stats.evolved or 0) + 1
	registerDiscovery(player, profile, animal)
	spawnModel(player, animal)
	if Balance.isEquipped(profile, animal.id) then
		bonusChanged(player)
	end
	DataService.push(player)

	Notify.reveal(player, {
		title = "⬆️ EVOLUIU!",
		name = Balance.animalName(animal),
		color = Rarities.list[animal.rarity].color,
		sub = "Agora produz 💰 " .. Format.rate(Balance.animalProduction(animal)) .. "/s",
	})
	return true, nil
end

function FarmService.sell(player: Player, animalId: string): (boolean, string?)
	local profile = DataService.get(player)
	if #profile.animals <= 1 then
		return false, "Você precisa manter pelo menos 1 animal"
	end
	local animal, index = findAnimal(profile, animalId)
	if not animal or not index then
		return false, "Animal não encontrado"
	end
	table.remove(profile.animals, index)
	local value = Balance.sellPrice(animal)
	DataService.addCoins(player, value)
	despawnModel(player, animalId)
	local equippedIndex = table.find(profile.equipped, animalId)
	if equippedIndex then
		table.remove(profile.equipped, equippedIndex)
		bonusChanged(player)
	end
	DataService.push(player)
	return true, "Vendido por 💰 " .. Format.number(value)
end

function FarmService.giveStarter(player: Player)
	FarmService.addAnimal(player, "Galinha", 1, false)
end

function FarmService.applyOfflineEarnings(player: Player)
	local profile = DataService.get(player)
	if not profile or profile.lastOnline <= 0 then
		return
	end
	local amount = Balance.offlineEarnings(profile, os.time() - profile.lastOnline, PassService.has(player, "VIP"))
	if amount > 0 then
		DataService.addCoins(player, amount)
		Notify.welcome(player, amount, os.time() - profile.lastOnline)
	end
end

function FarmService.init(plotList)
	plots = plotList
	task.spawn(function()
		while true do
			task.wait(1)
			for player, profile in DataService.all() do
				local rate = Balance.totalProduction(profile, PassService.has(player, "VIP"))
				if rate > 0 then
					DataService.addCoins(player, rate)
				end
			end
		end
	end)
end

return FarmService
