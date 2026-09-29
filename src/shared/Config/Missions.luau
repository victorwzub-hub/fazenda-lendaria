-- Missões em sequência: ensinam o loop do jogo (coletar → guardar → ninho → evoluir →
-- treinar → comprar → nova rota) e dão moedas. Depois da última, repete "Colete N itens".
--
-- kind:
--   "stat"    progresso = profile.stats[stat] desde o início da missão
--   "speed"   velocidade atual ≥ goal
--   "upgrade" nível do upgrade `id` ≥ goal
--   "animal"  ter a espécie `id` com raridade ≥ goal
--   "route"   rota `id` liberada
-- hint: para onde o guia aponta ("rota", "esteira", "loja", "rotas", "animais", "tesouro").
export type Mission = {
	text: string,
	kind: string,
	stat: string?,
	id: string?,
	goal: number,
	reward: number,
	hint: string?,
}

local Missions = {}

Missions.list = {
	{ text = "Colete 10 itens na rota", kind = "stat", stat = "collected", goal = 10, reward = 40, hint = "rota" },
	{ text = "Leve a cesta para casa", kind = "stat", stat = "deposited", goal = 1, reward = 40, hint = "casa" },
	{ text = "Abra 1 ninho no 🥚 Ninhal", kind = "stat", stat = "nests", goal = 1, reward = 60, hint = "rota" },
	{ text = "🐣 Choque seu ovo na Chocadeira", kind = "stat", stat = "hatched", goal = 1, reward = 60, hint = "ovo" },
	{ text = "Evolua um animal", kind = "stat", stat = "evolved", goal = 1, reward = 80, hint = "animais" },
	{ text = "Treine na esteira até ⚡20", kind = "speed", goal = 20, reward = 100, hint = "esteira" },
	{ text = "Compre as 👢 Botas Rápidas", kind = "upgrade", id = "Velocidade", goal = 1, reward = 120, hint = "loja" },
	{ text = "👊 Derrube o Galo Bravo (3 golpes)", kind = "stat", stat = "ko_Galinheiro", goal = 1, reward = 150, hint = "rota" },
	{ text = "Colete 40 itens", kind = "stat", stat = "collected", goal = 40, reward = 150, hint = "rota" },
	{ text = "Tenha uma 🐔 Galinha Rara", kind = "animal", id = "Galinha", goal = 3, reward = 200, hint = "animais" },
	{ text = "⚔️ Ajude a derrotar um Chefão", kind = "stat", stat = "bosses", goal = 1, reward = 400, hint = "chefe" },
	{ text = "Treine até ⚡28 para fugir do Porco", kind = "speed", goal = 28, reward = 250, hint = "esteira" },
	{ text = "Libere a Rota do Chiqueiro", kind = "route", id = "Chiqueiro", goal = 1, reward = 300, hint = "rotas" },
	{ text = "👊 Derrube o Porco Bravo e pegue o 🥓 Bacon", kind = "stat", stat = "ko_Chiqueiro", goal = 1, reward = 350, hint = "rota" },
	{ text = "Compre as 🦘 Botas de Pulo", kind = "upgrade", id = "Pulo", goal = 1, reward = 350, hint = "loja" },
	{ text = "💎 Suba na árvore e abra o Baú do Tesouro", kind = "stat", stat = "chests", goal = 1, reward = 500, hint = "tesouro" },
	{ text = "💎 Abra o Baú do Tesouro do Chiqueiro", kind = "stat", stat = "chest_Chiqueiro", goal = 1, reward = 600, hint = "tesouro" },
	{ text = "Compre a 🏃 Esteira Turbo", kind = "upgrade", id = "Esteira", goal = 1, reward = 400, hint = "loja" },
	{ text = "Evolua 5 vezes", kind = "stat", stat = "evolved", goal = 5, reward = 800, hint = "animais" },
	{ text = "Treine até ⚡35", kind = "speed", goal = 35, reward = 900, hint = "esteira" },
	{ text = "Libere a Rota do Pasto", kind = "route", id = "Pasto", goal = 1, reward = 1500, hint = "rotas" },
	{ text = "💎 Abra o Baú do Tesouro do Pasto", kind = "stat", stat = "chest_Pasto", goal = 1, reward = 1800, hint = "tesouro" },
	{ text = "Abra 10 ninhos", kind = "stat", stat = "nests", goal = 10, reward = 2000, hint = "rota" },
	{ text = "Consiga um animal Lendário", kind = "stat", stat = "legendaries", goal = 1, reward = 5000, hint = "animais" },
	{ text = "Libere a Rota da Pradaria", kind = "route", id = "Pradaria", goal = 1, reward = 8000, hint = "rotas" },
	{ text = "💎 Abra o Baú do Tesouro da Pradaria", kind = "stat", stat = "chest_Pradaria", goal = 1, reward = 10000, hint = "tesouro" },
	{ text = "💎 Abra 10 Baús do Tesouro", kind = "stat", stat = "chests", goal = 10, reward = 15000, hint = "tesouro" },
} :: { Mission }

-- Depois da lista: missões infinitas de coleta, cada vez maiores.
function Missions.get(index: number): Mission
	local fixed = Missions.list[index]
	if fixed then
		return fixed
	end
	local extra = index - #Missions.list
	return {
		text = "Colete " .. (100 * extra) .. " itens",
		kind = "stat",
		stat = "collected",
		goal = 100 * extra,
		reward = 3000 * extra,
		hint = "rota",
	}
end

return Missions
