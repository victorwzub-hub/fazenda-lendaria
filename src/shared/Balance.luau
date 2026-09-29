local Config = script.Parent.Config
local Rarities = require(Config.Rarities)
local Species = require(Config.Species)
local Materials = require(Config.Materials)
local Routes = require(Config.Routes)

local Balance = {}

Balance.SHINY_CHANCE = 1 / 100
Balance.SHINY_MULT = 3
Balance.BASE_CAPACITY = 6
Balance.CAPACITY_PER_LEVEL = 2
Balance.GIANT_FARM_BONUS = 10
Balance.LUCK_PER_LEVEL = 0.15
Balance.GOLDEN_HOUR_LUCK = 2
Balance.VIP_COIN_MULT = 2
Balance.OFFLINE_RATE = 0.5
Balance.OFFLINE_MAX_SECONDS = 8 * 60 * 60
Balance.SELL_SECONDS = 20
Balance.BOOST_SPEED = 8
-- Treino: +10 pontos por segundo na esteira (x Esteira Turbo). Cada nível de velocidade custa
-- 20, 25, 30… pontos: ⚡20 em ~11 s e ⚡26 em ~42 s (impacto rápido); os últimos demoram.
Balance.TRAIN_GAIN = 10
Balance.TRAIN_FIRST = 20
Balance.TRAIN_STEP = 5
Balance.TRAIN_LEVELS = 30
Balance.TRAIN_MAX = Balance.TRAIN_LEVELS * Balance.TRAIN_FIRST + Balance.TRAIN_STEP * Balance.TRAIN_LEVELS * (Balance.TRAIN_LEVELS - 1) / 2
Balance.BASE_SPEED = 16
Balance.BOOTS_SPEED = 3
Balance.BASKET_BASE = 20
Balance.BASKET_PER_LEVEL = 10
Balance.NET_CHANCE_PER_LEVEL = 0.5

-- Custo para subir da raridade [i] para i+1: { comum, incomum, raro, cristais, moedas (x base da espécie) }
local EVOLVE_STEPS = {
	{ 10, 3, 0, 0, 20 },
	{ 25, 10, 1, 0, 100 },
	{ 60, 25, 4, 0, 500 },
	{ 150, 60, 12, 0, 2500 },
	{ 400, 150, 35, 3, 15000 },
}

export type Animal = { id: string, species: string, rarity: number, shiny: boolean }

function Balance.animalName(animal: Animal): string
	local species = Species.byId[animal.species]
	local name = species.name .. " " .. Rarities.label(animal.rarity, species.feminine)
	return if animal.shiny then name .. " ✨" else name
end

function Balance.animalProduction(animal: Animal): number
	local species = Species.byId[animal.species]
	local rarity = Rarities.list[animal.rarity]
	if not species or not rarity then
		return 0
	end
	return species.base * rarity.mult * (if animal.shiny then Balance.SHINY_MULT else 1)
end

function Balance.totalProduction(profile, hasVip: boolean): number
	local total = 0
	for _, animal in profile.animals do
		total += Balance.animalProduction(animal)
	end
	return total * (if hasVip then Balance.VIP_COIN_MULT else 1)
end

function Balance.capacity(profile, hasGiantFarm: boolean): number
	return Balance.BASE_CAPACITY
		+ Balance.CAPACITY_PER_LEVEL * (profile.upgrades.Fazenda or 0)
		+ (if hasGiantFarm then Balance.GIANT_FARM_BONUS else 0)
end

function Balance.luck(profile, hasLuckPass: boolean, goldenHour: boolean): number
	local luck = 1 + Balance.LUCK_PER_LEVEL * (profile.upgrades.Sorte or 0)
	if hasLuckPass then
		luck *= 2
	end
	if goldenHour then
		luck *= Balance.GOLDEN_HOUR_LUCK
	end
	return luck
end

-- Pontos de treino por segundo: Esteira Turbo multiplica (nv 1 = x2, nv 2 = x3…).
function Balance.trainGain(profile): number
	return Balance.TRAIN_GAIN * (1 + (profile.upgrades.Esteira or 0))
end

-- Devolve (nível, pontos dentro do nível, custo do próximo nível).
function Balance.trainProgress(points: number): (number, number, number)
	local level = 0
	local remaining = math.max(0, points)
	while level < Balance.TRAIN_LEVELS do
		local cost = Balance.TRAIN_FIRST + Balance.TRAIN_STEP * level
		if remaining < cost then
			return level, remaining, cost
		end
		remaining -= cost
		level += 1
	end
	return level, 0, 0
end

function Balance.trainedSpeed(profile): number
	return (Balance.trainProgress(profile.training or 0))
end

function Balance.walkSpeed(profile): number
	return Balance.BASE_SPEED + Balance.BOOTS_SPEED * (profile.upgrades.Velocidade or 0) + Balance.trainedSpeed(profile)
end

-- Pulos no ar além do normal (nv 1 = duplo, nv 2 = triplo).
function Balance.extraJumps(profile): number
	return math.min(profile.upgrades.Pulo or 0, 2)
end

-- Altura do pulo: padrão do Roblox (7.2) e +0.8 por nível acima do 2.
function Balance.jumpHeight(profile): number
	return 7.2 + 0.8 * math.max(0, (profile.upgrades.Pulo or 0) - 2)
end

function Balance.basketCapacity(profile): number
	return Balance.BASKET_BASE + Balance.BASKET_PER_LEVEL * (profile.upgrades.Cesta or 0)
end

-- Itens a mais da Rede: cada 4 níveis garante +1; o resto é chance de +1.
function Balance.netBonus(profile, roll: number): number
	local value = Balance.NET_CHANCE_PER_LEVEL * (profile.upgrades.Rede or 0)
	return math.floor(value) + (if roll < value % 1 then 1 else 0)
end

function Balance.doubleDropChance(luck: number): number
	return math.clamp((luck - 1) * 0.25, 0, 0.6)
end

function Balance.sellPrice(animal: Animal): number
	return math.floor(Balance.animalProduction(animal) * Balance.SELL_SECONDS)
end

function Balance.evolveCost(speciesId: string, rarity: number): { coins: number, materials: { [string]: number } }?
	local step = EVOLVE_STEPS[rarity]
	local species = Species.byId[speciesId]
	if not step or not species then
		return nil
	end
	local materials = {}
	for tier = 1, 3 do
		if step[tier] > 0 then
			materials[species.materials[tier]] = step[tier]
		end
	end
	if step[4] > 0 then
		materials.CristalEstelar = step[4]
	end
	return { coins = step[5] * species.base, materials = materials }
end

function Balance.missingForCost(profile, coins: number, cost): (boolean, string?)
	if coins < cost.coins then
		return false, "Moedas insuficientes"
	end
	for materialId, amount in cost.materials do
		if (profile.materials[materialId] or 0) < amount then
			return false, "Falta " .. Materials.byId[materialId].name
		end
	end
	return true, nil
end

function Balance.rarityWeights(luck: number): { number }
	local weights = {}
	for i, rarity in Rarities.list do
		weights[i] = rarity.weight * luck ^ ((i - 1) * 0.5)
	end
	return weights
end

local function pickWeighted(weights: { number }, roll: number): number
	local total = 0
	for _, w in weights do
		total += w
	end
	local cursor = roll * total
	for i, w in weights do
		cursor -= w
		if cursor <= 0 then
			return i
		end
	end
	return #weights
end
Balance.pickWeighted = pickWeighted

function Balance.rollRarity(luck: number, rng: Random): number
	return pickWeighted(Balance.rarityWeights(luck), rng:NextNumber())
end

function Balance.rollShiny(luck: number, rng: Random): boolean
	return rng:NextNumber() < Balance.SHINY_CHANCE * luck
end

function Balance.hasAnimal(profile, speciesId: string, minRarity: number): boolean
	for _, animal in profile.animals do
		if animal.species == speciesId and animal.rarity >= minRarity then
			return true
		end
	end
	return false
end

function Balance.requirementText(routeId: string): string
	local route = Routes.byId[routeId]
	local req = route.requirement
	if not req then
		return "Livre"
	end
	local species = Species.byId[req.species]
	return species.emoji .. " " .. species.name .. " " .. Rarities.label(req.rarity, species.feminine) .. " ou melhor"
end

function Balance.canUnlockRoute(profile, coins: number, routeId: string): (boolean, string?)
	local route = Routes.byId[routeId]
	if not route then
		return false, "Rota inválida"
	end
	if profile.routes[routeId] then
		return false, "Rota já desbloqueada"
	end
	local req = route.requirement
	if req and not Balance.hasAnimal(profile, req.species, req.rarity) then
		return false, "Precisa de " .. Balance.requirementText(routeId)
	end
	if coins < route.unlockCost then
		return false, "Moedas insuficientes"
	end
	return true, nil
end

function Balance.offlineEarnings(profile, seconds: number, hasVip: boolean): number
	local capped = math.clamp(seconds, 0, Balance.OFFLINE_MAX_SECONDS)
	return math.floor(Balance.totalProduction(profile, hasVip) * capped * Balance.OFFLINE_RATE)
end

return Balance
