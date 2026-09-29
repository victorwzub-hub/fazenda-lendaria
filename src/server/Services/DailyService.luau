-- 📅 Prêmio diário: entrar em dias seguidos aumenta o prêmio (até o dia 7).
-- No 3º e no 7º dia seguido vem também um ovo raro para a Chocadeira.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Balance)
local Format = require(Shared.Format)
local Species = require(Shared.Config.Species)

local DataService = require(script.Parent.DataService)
local EggService = require(script.Parent.EggService)
local Notify = require(script.Parent.Notify)
local PassService = require(script.Parent.PassService)

local DailyService = {}

local DAY = 24 * 60 * 60
local MAX_STREAK = 7
local EGG_DAYS = { [3] = 3, [7] = 4 } -- dia seguido → raridade do ovo
local GOLD = Color3.fromRGB(255, 205, 60)

local function bestRoute(profile): string
	local best = "Galinheiro"
	for _, routeId in { "Galinheiro", "Chiqueiro", "Pasto", "Pradaria" } do
		if profile.routes[routeId] then
			best = routeId
		end
	end
	return best
end

function DailyService.claim(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	local today = math.floor(os.time() / DAY)
	local daily = profile.daily
	if daily.day == today then
		return
	end
	daily.streak = if daily.day == today - 1 then daily.streak + 1 else 1
	daily.day = today
	local day = math.min(daily.streak, MAX_STREAK)
	-- Prêmio cresce com a produção da fazenda: ~2 minutos de produção por dia seguido.
	local rate = Balance.totalProduction(profile, PassService.has(player, "VIP"))
	local coins = math.floor((150 + rate * 120) * day)
	DataService.addCoins(player, coins)
	DataService.push(player)

	local sub = "+💰 " .. Format.number(coins) .. "  •  volte amanhã para o dia " .. math.min(daily.streak + 1, MAX_STREAK)
	local eggRarity = EGG_DAYS[day]
	task.delay(4, function()
		if not player.Parent then
			return
		end
		Notify.big(player, "📅 PRÊMIO DIÁRIO • DIA " .. daily.streak .. "!", sub, GOLD, "revelar")
		if eggRarity then
			local routeId = bestRoute(profile)
			local species = Species.roll(routeId, Random.new():NextNumber())
			task.wait(3)
			EggService.give(player, species, eggRarity, false, "📅 OVO DO PRÊMIO DIÁRIO!")
		end
	end)
end

return DailyService
