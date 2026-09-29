-- Guardiões de cada rota. Mais rápidos que o jogador sem treino (16): treinar e comprar
-- botas é o que permite fugir. O treino compara a velocidade do jogador com estas.
local Guardians = {}

Guardians.byRoute = {
	Galinheiro = { species = "Galinha", name = "Galo Bravo", emoji = "🐔", speed = 17, rarity = 3 },
	Chiqueiro = { species = "Porco", name = "Porco Bravo", emoji = "🐷", speed = 21, rarity = 3 },
	Pasto = { species = "Vaca", name = "Touro Bravo", emoji = "🐮", speed = 25, rarity = 4 },
	Pradaria = { species = "Cavalo", name = "Cavalo Selvagem", emoji = "🐴", speed = 30, rarity = 4 },
}

Guardians.order = { "Galinheiro", "Chiqueiro", "Pasto", "Pradaria" }

return Guardians
