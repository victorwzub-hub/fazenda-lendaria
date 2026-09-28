local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Upgrades = require(Shared.Config.Upgrades)

local DataService = require(script.Parent.DataService)
local FarmService = require(script.Parent.FarmService)
local PassService = require(script.Parent.PassService)
local RouteService = require(script.Parent.RouteService)

local ActionService = {}

local RATE_WINDOW = 1
local RATE_LIMIT = 8

type Handler = (Player, string) -> (boolean, any)

local function buyUpgrade(player: Player, upgradeId: string): (boolean, string?)
	local def = Upgrades.byId[upgradeId]
	if not def then
		return false, "Melhoria inválida"
	end
	local profile = DataService.get(player)
	local level = profile.upgrades[upgradeId] or 0
	if level >= def.max then
		return false, "Nível máximo!"
	end
	if not DataService.spendCoins(player, Upgrades.cost(upgradeId, level)) then
		return false, "Moedas insuficientes"
	end
	profile.upgrades[upgradeId] = level + 1
	if upgradeId == "Velocidade" then
		FarmService.applySpeed(player)
	end
	DataService.push(player)
	return true, def.emoji .. " " .. def.name .. " nível " .. (level + 1) .. "!"
end

local HANDLERS: { [string]: Handler } = {
	GetProfile = function(player)
		return true, DataService.get(player)
	end,
	Evolve = FarmService.evolve,
	Sell = FarmService.sell,
	BuyUpgrade = buyUpgrade,
	UnlockRoute = RouteService.unlock,
	Travel = RouteService.travel,
	BuyPass = PassService.prompt,
}

local calls: { [Player]: { start: number, count: number } } = {}

local function allowed(player: Player): boolean
	local now = os.clock()
	local entry = calls[player]
	if not entry or now - entry.start > RATE_WINDOW then
		calls[player] = { start = now, count = 1 }
		return true
	end
	entry.count += 1
	return entry.count <= RATE_LIMIT
end

function ActionService.init()
	Remotes.func("Request").OnServerInvoke = function(player: Player, action: unknown, arg: unknown)
		if type(action) ~= "string" or not HANDLERS[action] then
			return false, "Ação inválida"
		end
		if arg ~= nil and type(arg) ~= "string" then
			return false, "Argumento inválido"
		end
		if not allowed(player) then
			return false, "Calma! Muitas ações ao mesmo tempo"
		end
		if not DataService.get(player) then
			return false, "Carregando seu progresso..."
		end
		local ok, success, result = pcall(HANDLERS[action], player, (arg or "") :: string)
		if not ok then
			warn("[ActionService]", action, success)
			return false, "Erro no servidor"
		end
		return success, result
	end

	Players.PlayerRemoving:Connect(function(player)
		calls[player] = nil
	end)
end

return ActionService
