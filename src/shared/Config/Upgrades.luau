local Upgrades = {}

Upgrades.byId = {
	Sorte = {
		id = "Sorte",
		name = "Sorte",
		emoji = "🍀",
		desc = "+10% de sorte: ninhos mais raros e chance de coletar em dobro",
		max = 20,
		baseCost = 250,
		growth = 1.65,
	},
	Fazenda = {
		id = "Fazenda",
		name = "Fazenda Maior",
		emoji = "🏡",
		desc = "+2 espaços para animais na sua fazenda",
		max = 12,
		baseCost = 150,
		growth = 1.9,
	},
	Velocidade = {
		id = "Velocidade",
		name = "Botas Rápidas",
		emoji = "👢",
		desc = "+2 de velocidade para explorar as rotas",
		max = 8,
		baseCost = 100,
		growth = 1.8,
	},
}

Upgrades.order = { "Sorte", "Fazenda", "Velocidade" }

function Upgrades.cost(id: string, level: number): number
	local def = Upgrades.byId[id]
	return math.floor(def.baseCost * def.growth ^ level)
end

return Upgrades
