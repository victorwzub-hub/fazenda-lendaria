-- Treino na esteira: quem está em cima da lona corre sozinho (animação no cliente) e ganha
-- Balance.trainGain pontos por segundo; cada nível custa um pouco mais (Balance.trainProgress).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Balance)
local Guardians = require(Shared.Config.Guardians)

local DataService = require(script.Parent.DataService)
local FarmService = require(script.Parent.FarmService)
local Notify = require(script.Parent.Notify)

local TrainingService = {}

local TICK = 0.5
local SECONDS_PER_GAIN = 1

local belts: { BasePart } = {}
local progress: { [Player]: number } = {}

local function onBelt(root: BasePart): boolean
	for _, belt in belts do
		local rel = belt.CFrame:PointToObjectSpace(root.Position)
		if math.abs(rel.X) <= belt.Size.X / 2 + 0.3 and math.abs(rel.Z) <= belt.Size.Z / 2 and rel.Y > 0 and rel.Y < 5 then
			return true
		end
	end
	return false
end

local function tick(player: Player)
	local profile = DataService.get(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not profile or not root then
		return
	end
	local training = onBelt(root)
	if player:GetAttribute("NaEsteira") ~= training then
		player:SetAttribute("NaEsteira", training)
	end
	if not training or (profile.training or 0) >= Balance.TRAIN_MAX then
		return
	end
	progress[player] = (progress[player] or 0) + TICK
	if progress[player] < SECONDS_PER_GAIN then
		return
	end
	progress[player] = 0
	local before = Balance.trainedSpeed(profile)
	local oldSpeed = Balance.walkSpeed(profile)
	profile.training = math.min((profile.training or 0) + Balance.trainGain(profile), Balance.TRAIN_MAX)
	player:SetAttribute("Treino", profile.training)
	if Balance.trainedSpeed(profile) > before then
		FarmService.applySpeed(player)
		DataService.push(player)
		local speed = Balance.walkSpeed(profile)
		-- Comemora quando passa um guardião: é aí que o treino faz diferença na hora de fugir.
		local passed = nil
		for _, routeId in Guardians.order do
			local guardian = Guardians.byRoute[routeId]
			if oldSpeed <= guardian.speed and speed > guardian.speed then
				passed = guardian
			end
		end
		if passed then
			Notify.big(
				player,
				"⚡ VELOCIDADE " .. speed .. "!",
				"Agora você corre mais que o " .. passed.emoji .. " " .. passed.name .. " (⚡" .. passed.speed .. ")",
				Color3.fromRGB(120, 230, 255),
				"revelar"
			)
		else
			Notify.toast(player, "⚡ +1 de velocidade! Agora: " .. speed, Color3.fromRGB(120, 230, 255), "boost")
		end
	end
end

function TrainingService.setup(player: Player)
	local profile = DataService.get(player)
	player:SetAttribute("Treino", if profile then profile.training or 0 else 0)
	player:SetAttribute("TreinoMax", Balance.TRAIN_MAX)
end

function TrainingService.init(plots)
	for _, plot in plots do
		table.insert(belts, plot.treadmill)
	end
	task.spawn(function()
		while true do
			task.wait(TICK)
			for _, player in Players:GetPlayers() do
				tick(player)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		progress[player] = nil
	end)
end

return TrainingService
