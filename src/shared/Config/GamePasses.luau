-- Crie os passes no Creator Hub (Monetização > Passes) e cole os IDs aqui. id = 0 deixa o passe como "Em breve".
local GamePasses = {}

GamePasses.byId = {
	VIP = { key = "VIP", id = 0, name = "VIP", emoji = "👑", desc = "2x moedas de todos os animais, para sempre" },
	SorteDupla = {
		key = "SorteDupla",
		id = 0,
		name = "Sorte Dupla",
		emoji = "🍀",
		desc = "2x sorte em todas as rotas",
	},
	FazendaGigante = {
		key = "FazendaGigante",
		id = 0,
		name = "Fazenda Gigante",
		emoji = "🏰",
		desc = "+10 espaços para animais",
	},
}

GamePasses.order = { "VIP", "SorteDupla", "FazendaGigante" }

return GamePasses
