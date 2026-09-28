local Players = game:GetService("Players")

local Services = script.Services
local ActionService = require(Services.ActionService)
local Basket = require(Services.Basket)
local BoostService = require(Services.BoostService)
local DataService = require(Services.DataService)
local FarmService = require(Services.FarmService)
local GuardianService = require(Services.GuardianService)
local MapBuilder = require(Services.MapBuilder)
local Notify = require(Services.Notify)
local PassService = require(Services.PassService)
local RouteService = require(Services.RouteService)

local map = MapBuilder.build()
DataService.init()
PassService.init()
FarmService.init(map.plots)
RouteService.init(map.zones, map.portals)
GuardianService.init(map.zones)
BoostService.init(map.zones)
ActionService.init()

PassService.onGranted(function(player)
	DataService.push(player)
end)

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		FarmService.onCharacter(player, character)
	end)

	local profile, isNew, loaded = DataService.load(player)
	if not profile then
		return
	end
	PassService.load(player)
	if not player.Parent or not DataService.get(player) then
		return
	end
	FarmService.applyOfflineEarnings(player)
	FarmService.assignPlot(player)
	Basket.setup(player)
	if isNew then
		FarmService.giveStarter(player)
	end
	DataService.push(player)

	if player.Character then
		task.spawn(FarmService.onCharacter, player, player.Character)
	end

	if not loaded then
		Notify.big(
			player,
			"⚠️ Progresso não será salvo",
			"Não foi possível acessar o salvamento agora. Tente entrar de novo mais tarde.",
			Color3.fromRGB(255, 120, 100)
		)
	elseif isNew then
		Notify.big(
			player,
			"Bem-vindo à Fazenda Lendária! 🐔",
			"Entre no portal da Rota do Galinheiro para coletar materiais e achar ninhos",
			Color3.fromRGB(255, 205, 60)
		)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	FarmService.releasePlot(player)
	Basket.release(player)
	DataService.release(player)
end)
