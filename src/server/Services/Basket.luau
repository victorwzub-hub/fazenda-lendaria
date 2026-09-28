-- Cesta: o que o jogador coletou na rota e ainda não levou para casa.
-- Só vira material de verdade (profile.materials) quando ele volta para a fazenda.
-- Não é salva: sair do jogo guarda tudo automaticamente (ver init.server).
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage:WaitForChild("Shared").Balance)

local DataService = require(script.Parent.DataService)
local Notify = require(script.Parent.Notify)

local Basket = {}

local baskets: { [Player]: { [string]: number } } = {}

local function total(basket: { [string]: number }): number
	local sum = 0
	for _, amount in basket do
		sum += amount
	end
	return sum
end

local function sync(player: Player)
	local basket = baskets[player] or {}
	player:SetAttribute("Cesta", total(basket))
	player:SetAttribute("CestaMax", Basket.capacity(player))
	player:SetAttribute("CestaItens", HttpService:JSONEncode(basket))
end

function Basket.capacity(player: Player): number
	local profile = DataService.get(player)
	return if profile then Balance.basketCapacity(profile) else Balance.BASKET_BASE
end

function Basket.count(player: Player): number
	return total(baskets[player] or {})
end

function Basket.space(player: Player): number
	return math.max(0, Basket.capacity(player) - Basket.count(player))
end

-- Coloca até `amount` itens; devolve quantos couberam.
function Basket.add(player: Player, materialId: string, amount: number): number
	local added = math.min(amount, Basket.space(player))
	if added <= 0 then
		return 0
	end
	local basket = baskets[player] or {}
	baskets[player] = basket
	basket[materialId] = (basket[materialId] or 0) + added
	sync(player)
	return added
end

-- Tira uma fração da cesta (arredondada para cima) e devolve o que saiu.
function Basket.take(player: Player, fraction: number): { [string]: number }
	local basket = baskets[player]
	local removed: { [string]: number } = {}
	if not basket then
		return removed
	end
	local target = math.ceil(total(basket) * fraction)
	local taken = 0
	while taken < target do
		local biggest, most = nil, 0
		for materialId, amount in basket do
			if amount > most then
				biggest, most = materialId, amount
			end
		end
		if not biggest then
			break
		end
		basket[biggest] -= 1
		if basket[biggest] <= 0 then
			basket[biggest] = nil
		end
		removed[biggest] = (removed[biggest] or 0) + 1
		taken += 1
	end
	sync(player)
	return removed
end

-- Passa tudo da cesta para os materiais do jogador. Devolve quantos itens foram guardados.
function Basket.deposit(player: Player, silent: boolean?): number
	local basket = baskets[player]
	local amount = if basket then total(basket) else 0
	if amount == 0 or not DataService.get(player) then
		return 0
	end
	for materialId, count in basket :: { [string]: number } do
		DataService.addMaterial(player, materialId, count)
	end
	baskets[player] = nil
	sync(player)
	DataService.push(player)
	if not silent then
		Notify.toast(player, "🧺 Guardou " .. amount .. " itens na fazenda!", Color3.fromRGB(95, 235, 70), "guardar")
	end
	return amount
end

function Basket.setup(player: Player)
	sync(player)
end

-- Recalcula a capacidade (depois de comprar Cesta Maior).
Basket.refresh = sync

function Basket.release(player: Player)
	Basket.deposit(player, true)
	baskets[player] = nil
end

return Basket
