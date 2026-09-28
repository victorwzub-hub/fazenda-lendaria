local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnimalModel = require(Shared.AnimalModel)
local Balance = require(Shared.Balance)
local Format = require(Shared.Format)
local Rarities = require(Shared.Config.Rarities)
local Species = require(Shared.Config.Species)

local Basket = require(script.Parent.Basket)
local DataService = require(script.Parent.DataService)
local Notify = require(script.Parent.Notify)
local PassService = require(script.Parent.PassService)
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

local function wander(model: Model, plot)
	local root = model.PrimaryPart :: BasePart
	while model.Parent do
		task.wait(rng:NextNumber(2, 6))
		if not model.Parent then
			break
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

local function spawnModel(player: Player, animal)
	local plot = plotOf[player]
	local models = modelsOf[player]
	if not plot or not models then
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

local function despawnModel(player: Player, animalId: string)
	local models = modelsOf[player]
	if models and models[animalId] then
		models[animalId]:Destroy()
		models[animalId] = nil
	end
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
	profile.index[animal.species .. ":" .. animal.rarity] = true
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
			return plot
		end
	end
	warn("[FarmService] Sem lotes livres para", player.Name, "- aumente PLOT_COUNT ou reduza o máximo de jogadores")
	return nil
end

function FarmService.releasePlot(player: Player)
	local plot = plotOf[player]
	if plot then
		plot.owner = nil
		plot.sign.Text = "Fazenda livre"
		plot.animals:ClearAllChildren()
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
		humanoid.WalkSpeed = Balance.walkSpeed(profile) + (if boosted then Balance.BOOST_SPEED else 0)
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
	registerDiscovery(player, profile, animal)
	spawnModel(player, animal)
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
		Notify.big(
			player,
			"Bem-vindo de volta! 🌾",
			"Sua fazenda rendeu 💰 " .. Format.number(amount) .. " enquanto você estava fora",
			GOLD
		)
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
