local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Services = script.Services
local ActionService = require(Services.ActionService)
local Basket = require(Services.Basket)
local BossService = require(Services.BossService)
local BoostService = require(Services.BoostService)
local DailyService = require(Services.DailyService)
local DataService = require(Services.DataService)
local EggService = require(Services.EggService)
local EquipmentService = require(Services.EquipmentService)
local FarmService = require(Services.FarmService)
local GuardianService = require(Services.GuardianService)
local MapBuilder = require(Services.MapBuilder)
local Notify = require(Services.Notify)
local PassService = require(Services.PassService)
local PetService = require(Services.PetService)
local RaceService = require(Services.RaceService)
local RebirthService = require(Services.RebirthService)
local RouteService = require(Services.RouteService)
local MissionService = require(Services.MissionService)
local StampedeService = require(Services.StampedeService)
local TrainingService = require(Services.TrainingService)
local TreasureService = require(Services.TreasureService)
local UpgradeService = require(Services.UpgradeService)

local map = MapBuilder.build()
DataService.init()
PassService.init()
PetService.init()
FarmService.init(map.plots)
RouteService.init(map.zones, map.portals)
GuardianService.init(map.zones)
BoostService.init(map.zones)
GuardianService.onKnockout = function(zone, position, def)
	BoostService.dropFood(zone, position, def.food)
end
BossService.init(map.zones)
GuardianService.beforeHit = BossService.hit
EquipmentService.init()
EggService.init()
TreasureService.init(map.zones)
TrainingService.init(map.plots)
StampedeService.init(map.zones)
RaceService.init(map.zones)
MissionService.init()
ActionService.init()

-- Placa da esteira acompanha compras, pets e renascimento.
UpgradeService.onBought = function(player, upgradeId)
	if upgradeId == "Esteira" then
		TrainingService.refreshBoard(player)
	end
end
FarmService.onBonusChanged = TrainingService.refreshBoard
FarmService.onPlotReleased = TrainingService.clearBoard
RebirthService.onRebirth = function(player)
	TrainingService.setup(player)
end

-- Só no Studio: atributos para testar eventos na hora.
if RunService:IsStudio() then
	-- Acesso aos serviços para testes pelo Studio (não existe no jogo publicado):
	-- ServerStorage.Teste:Invoke("Farm", "equipBest", ...) chama FarmService.equipBest(jogador, ...);
	-- Invoke("perfil") devolve o perfil do primeiro jogador.
	local api = {
		Data = DataService,
		Farm = FarmService,
		Egg = EggService,
		Pet = PetService,
		Race = RaceService,
		Rebirth = RebirthService,
		Stampede = StampedeService,
		Training = TrainingService,
		Upgrade = UpgradeService,
		Guardian = GuardianService,
	}
	local test = Instance.new("BindableFunction")
	test.Name = "Teste"
	test.OnInvoke = function(service: string, fn: string?, ...)
		local player = Players:GetPlayers()[1]
		if service == "perfil" then
			return DataService.get(player)
		elseif service == "zona" then
			return map.zones[fn].origin
		elseif service == "set" then
			-- Invoke("set", "routes.Pradaria", true)
			local target = DataService.get(player)
			local keys = string.split(fn :: string, ".")
			for i = 1, #keys - 1 do
				target = target[keys[i]]
			end
			target[keys[#keys]] = (...)
			DataService.push(player)
			return true
		end
		return api[service][fn :: string](player, ...)
	end
	test.Parent = game:GetService("ServerStorage")
	Workspace:GetAttributeChangedSignal("ForcarEstouro"):Connect(function()
		if Workspace:GetAttribute("ForcarEstouro") then
			Workspace:SetAttribute("ForcarEstouro", nil)
			StampedeService.force(map.zones)
		end
	end)
end

PassService.onGranted(function(player)
	DataService.push(player)
end)

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		RaceService.onCharacter(player)
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
	EggService.setup(player)
	PetService.refresh(player)
	Basket.setup(player)
	EquipmentService.refresh(player)
	TrainingService.setup(player)
	MissionService.setup(player)
	if isNew then
		FarmService.giveStarter(player)
	end
	DailyService.claim(player)
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
	EggService.release(player)
	PetService.release(player)
	FarmService.releasePlot(player)
	Basket.release(player)
	DataService.release(player)
end)
