-- Guardiões de cada rota. Mais rápidos que o jogador sem treino (16): treinar e comprar
-- botas é o que permite fugir. O treino compara a velocidade do jogador com estas.
local Guardians = {}

Guardians.byRoute = {
	-- food: o que ele solta ao ser derrubado (3 golpes) e o boost que a comida dá.
	Galinheiro = { species = "Galinha", name = "Galo Bravo", emoji = "🐔", speed = 17, rarity = 3, food = { emoji = "🍗", name = "Coxinha", boost = "Velocidade" } },
	Chiqueiro = { species = "Porco", name = "Porco Bravo", emoji = "🐷", speed = 21, rarity = 3, food = { emoji = "🥓", name = "Bacon", boost = "Escudo" } },
	Pasto = { species = "Vaca", name = "Touro Bravo", emoji = "🐮", speed = 25, rarity = 4, food = { emoji = "🥩", name = "Bife", boost = "Ima" } },
	Pradaria = { species = "Cavalo", name = "Cavalo Selvagem", emoji = "🐴", speed = 30, rarity = 4, food = { emoji = "🥕", name = "Cenoura", boost = "Velocidade" } },
}

Guardians.order = { "Galinheiro", "Chiqueiro", "Pasto", "Pradaria" }

return Guardians
