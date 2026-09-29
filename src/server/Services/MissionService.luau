-- Acompanha a missão atual de cada jogador, paga o prêmio ao completar e publica o estado
-- em atributos ("Missao*") para o painel do HUD e o guia.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Balance)
local Format = require(Shared.Format)
local Missions = require(Shared.Config.Missions)

local DataService = require(script.Parent.DataService)
local Notify = require(script.Parent.Notify)

local MissionService = {}

local CHECK_EVERY = 0.5
local GREEN = Color3.fromRGB(95, 235, 70)

local function statValue(profile, stat: string?): number
	return if stat then profile.stats[stat] or 0 else 0
end

-- Devolve (progresso, meta) da missão atual.
local function progressOf(profile, mission): (number, number)
	if mission.kind == "stat" then
		return math.max(0, statValue(profile, mission.stat) - (profile.mission.base or 0)), mission.goal
	elseif mission.kind == "speed" then
		return Balance.walkSpeed(profile), mission.goal
	elseif mission.kind == "upgrade" then
		return profile.upgrades[mission.id] or 0, mission.goal
	elseif mission.kind == "animal" then
		return if Balance.hasAnimal(profile, mission.id, mission.goal) then 1 else 0, 1
	elseif mission.kind == "route" then
		return if profile.routes[mission.id] then 1 else 0, 1
	elseif mission.kind == "equipped" then
		return #(profile.equipped or {}), mission.goal
	elseif mission.kind == "rebirth" then
		return profile.rebirths or 0, mission.goal
	end
	return 0, 1
end

local function start(profile, index: number)
	local mission = Missions.get(index)
	profile.mission = { index = index, base = if mission.kind == "stat" then statValue(profile, mission.stat) else 0 }
end

local function publish(player: Player, profile)
	local mission = Missions.get(profile.mission.index)
	local progress, goal = progressOf(profile, mission)
	player:SetAttribute("MissaoNumero", profile.mission.index)
	player:SetAttribute("MissaoTexto", mission.text)
	player:SetAttribute("MissaoProgresso", math.min(progress, goal))
	player:SetAttribute("MissaoMeta", goal)
	player:SetAttribute("MissaoPremio", mission.reward)
	player:SetAttribute("MissaoDica", mission.hint or "")
	player:SetAttribute("MissaoStat", if mission.kind == "stat" then mission.stat else nil)
	player:SetAttribute("MissaoUpgrade", if mission.kind == "upgrade" then mission.id else nil)
end

local function check(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	local mission = Missions.get(profile.mission.index)
	local progress, goal = progressOf(profile, mission)
	if progress >= goal then
		DataService.addCoins(player, mission.reward)
		Notify.big(
			player,
			"✅ MISSÃO COMPLETA!",
			mission.text .. "   +💰 " .. Format.number(mission.reward),
			GREEN,
			"revelar"
		)
		start(profile, profile.mission.index + 1)
		DataService.push(player)
	end
	publish(player, profile)
end

function MissionService.setup(player: Player)
	local profile = DataService.get(player)
	if profile and (profile.mission.index or 0) < 1 then
		start(profile, 1)
	end
	check(player)
end

function MissionService.init()
	task.spawn(function()
		while true do
			task.wait(CHECK_EVERY)
			for _, player in Players:GetPlayers() do
				check(player)
			end
		end
	end)
end

return MissionService
