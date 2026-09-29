-- ♻️ Renascer: com a Rota do Pasto liberada e moedas suficientes, o jogador recomeça
-- (moedas, materiais, melhorias, treino, rotas e bichos da fazenda) mas fica com os pets
-- equipados, os ovos, o índice e ganha bônus para sempre: +50% moedas, +10% sorte e +1 pet.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Balance)
local Format = require(Shared.Format)

local Basket = require(script.Parent.Basket)
local DataService = require(script.Parent.DataService)
local EquipmentService = require(script.Parent.EquipmentService)
local FarmService = require(script.Parent.FarmService)
local Notify = require(script.Parent.Notify)

local RebirthService = {}

local PURPLE = Color3.fromRGB(200, 120, 255)

-- Avisado depois de renascer (init.server atualiza treino/placa).
RebirthService.onRebirth = nil :: ((Player) -> ())?

function RebirthService.rebirth(player: Player): (boolean, string?)
	local profile = DataService.get(player)
	if not profile then
		return false, "Carregando seu progresso..."
	end
	local ok, reason = Balance.canRebirth(profile, profile.coins)
	if not ok then
		return false, reason
	end

	DataService.spendCoins(player, profile.coins)
	profile.materials = {}
	for id in profile.upgrades do
		profile.upgrades[id] = 0
	end
	profile.training = 0
	profile.routes = { Galinheiro = true }
	local kept = {}
	for _, animal in profile.animals do
		if Balance.isEquipped(profile, animal.id) then
			table.insert(kept, animal)
		end
	end
	if #kept == 0 then
		table.insert(kept, { id = "a" .. profile.nextAnimalId, species = "Galinha", rarity = 1, shiny = false })
		profile.nextAnimalId += 1
	end
	profile.animals = kept
	profile.rebirths = (profile.rebirths or 0) + 1
	profile.stats.rebirths = profile.rebirths

	Basket.clear(player)
	EquipmentService.refresh(player)
	FarmService.decorate(player)
	FarmService.reloadAnimals(player)
	if RebirthService.onRebirth then
		RebirthService.onRebirth(player)
	end
	FarmService.teleportHome(player)
	DataService.push(player)

	Notify.bigAll(
		"♻️ " .. player.DisplayName .. " RENASCEU! (x" .. profile.rebirths .. ")",
		"Agora: 💰 x" .. string.format("%.1f", 1 + Balance.REBIRTH_COIN_BONUS * profile.rebirths)
			.. " moedas • 🐾 " .. Balance.petSlots(profile) .. " pets • próximo renascer: 💰 "
			.. Format.number(Balance.rebirthCost(profile)),
		PURPLE,
		"revelar"
	)
	return true, "♻️ Renascimento confirmado! Seu bônus permanente já está ativo."
end

return RebirthService
