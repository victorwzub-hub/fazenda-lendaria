-- Baú do Tesouro no topo da árvore de cada rota. Cada jogador pode abrir a cada 5 minutos.
-- Os itens vão para a cesta (ainda precisa levar para casa); as moedas entram na hora.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local Materials = require(Shared.Config.Materials)
local Routes = require(Shared.Config.Routes)

local Basket = require(script.Parent.Basket)
local DataService = require(script.Parent.DataService)
local Notify = require(script.Parent.Notify)

local TreasureService = {}

local COOLDOWN = 5 * 60
local RARE_AMOUNT = 3
local CRYSTAL_CHANCE = 0.35
local COINS_PER_ROUTE = 150
local GOLD = Color3.fromRGB(255, 200, 50)

local opened: { [Player]: { [string]: number } } = {}
local rng = Random.new()

local function rareMaterial(route): string?
	for _, def in route.nodes do
		if def.material and Materials.byId[def.material].tier == 3 then
			return def.material
		end
	end
	return nil
end

local function open(player: Player, routeId: string, index: number)
	local profile = DataService.get(player)
	if not profile or not profile.routes[routeId] then
		return
	end
	local mine = opened[player] or {}
	opened[player] = mine
	local last = mine[routeId]
	local wait = if last then last + COOLDOWN - os.clock() else 0
	if wait > 0 then
		Notify.toast(player, "⏳ O baú enche de novo em " .. Format.time(wait), GOLD)
		return
	end
	mine[routeId] = os.clock()

	local route = Routes.byId[routeId]
	local parts = {}
	local material = rareMaterial(route)
	if material then
		local added = Basket.add(player, material, RARE_AMOUNT)
		if added > 0 then
			table.insert(parts, "+" .. added .. " " .. Materials.byId[material].emoji)
		end
	end
	if rng:NextNumber() < CRYSTAL_CHANCE and Basket.add(player, "CristalEstelar", 1) > 0 then
		table.insert(parts, "+1 💎")
	end
	local coins = COINS_PER_ROUTE * index
	DataService.addCoins(player, coins)
	DataService.push(player)
	table.insert(parts, "+💰 " .. Format.number(coins))
	Notify.big(player, "🎁 BAÚ DO TESOURO!", table.concat(parts, "   ") .. "   • leve a cesta para casa!", GOLD)
end

function TreasureService.init(zones)
	for index, routeId in Routes.order do
		local zone = zones[routeId]
		if zone and zone.treasure then
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Abrir baú"
			prompt.ObjectText = "Baú do Tesouro"
			prompt.HoldDuration = 1
			prompt.MaxActivationDistance = 10
			prompt.RequiresLineOfSight = false
			prompt.Parent = zone.treasure
			prompt.Triggered:Connect(function(player)
				open(player, routeId, index)
			end)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		opened[player] = nil
	end)
end

return TreasureService
