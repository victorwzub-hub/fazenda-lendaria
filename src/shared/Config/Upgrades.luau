local Upgrades = {}

Upgrades.byId = {
	Sorte = {
		id = "Sorte",
		name = "Sorte",
		emoji = "🍀",
		desc = "Ninhos mais raros e mais chance de coletar em dobro",
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
		desc = "+3 de velocidade para fugir dos guardiões",
		max = 8,
		baseCost = 100,
		growth = 1.8,
	},
	Rede = {
		id = "Rede",
		name = "Rede de Coleta",
		emoji = "🥅",
		desc = "Pega mais itens em cada coleta",
		max = 8,
		baseCost = 150,
		growth = 1.8,
	},
	Cesta = {
		id = "Cesta",
		name = "Cesta Maior",
		emoji = "🧺",
		desc = "+10 de espaço na cesta antes de voltar para casa",
		max = 10,
		baseCost = 120,
		growth = 1.75,
	},
	Esteira = {
		id = "Esteira",
		name = "Esteira Turbo",
		emoji = "🏃",
		desc = "Treina muito mais rápido na esteira",
		max = 4,
		baseCost = 200,
		growth = 2.6,
	},
	Pulo = {
		id = "Pulo",
		name = "Botas de Pulo",
		emoji = "🦘",
		desc = "Nv 1: pulo duplo • Nv 2: pulo triplo • depois: pulo mais alto",
		max = 5,
		baseCost = 300,
		growth = 2.2,
	},
}

-- Equipamentos aparecem no boneco; melhorias da fazenda não.
Upgrades.equipment = { "Velocidade", "Pulo", "Rede", "Cesta" }
Upgrades.farm = { "Esteira", "Sorte", "Fazenda" }
Upgrades.order = { "Esteira", "Sorte", "Fazenda", "Velocidade", "Pulo", "Rede", "Cesta" }

function Upgrades.cost(id: string, level: number): number
	local def = Upgrades.byId[id]
	return math.floor(def.baseCost * def.growth ^ level)
end

return Upgrades
