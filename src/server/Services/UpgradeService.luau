-- Compra de melhorias (Loja e placa da esteira usam a mesma função).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Upgrades = require(ReplicatedStorage:WaitForChild("Shared").Config.Upgrades)

local Basket = require(script.Parent.Basket)
local DataService = require(script.Parent.DataService)
local EquipmentService = require(script.Parent.EquipmentService)
local FarmService = require(script.Parent.FarmService)

local UpgradeService = {}

-- Avisado depois de cada compra (init.server liga na placa da esteira).
UpgradeService.onBought = nil :: ((Player, string) -> ())?

function UpgradeService.buy(player: Player, upgradeId: string): (boolean, string?)
	local def = Upgrades.byId[upgradeId]
	if not def then
		return false, "Melhoria inválida"
	end
	local profile = DataService.get(player)
	if not profile then
		return false, "Carregando seu progresso..."
	end
	local level = profile.upgrades[upgradeId] or 0
	if level >= def.max then
		return false, "Nível máximo!"
	end
	if not DataService.spendCoins(player, Upgrades.cost(upgradeId, level)) then
		return false, "Moedas insuficientes"
	end
	profile.upgrades[upgradeId] = level + 1
	if upgradeId == "Velocidade" or upgradeId == "Pulo" then
		FarmService.applySpeed(player)
	elseif upgradeId == "Cesta" then
		Basket.refresh(player)
	elseif upgradeId == "Fazenda" then
		FarmService.decorate(player)
	end
	EquipmentService.refresh(player)
	DataService.push(player)
	if UpgradeService.onBought then
		UpgradeService.onBought(player, upgradeId)
	end
	return true, def.emoji .. " " .. def.name .. " nível " .. (level + 1) .. "!"
end

return UpgradeService
