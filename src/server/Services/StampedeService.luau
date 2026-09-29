-- 🐄 Estouro da Boiada (Rota do Pasto): de tempos em tempos uma faixa vermelha pisca no chão
-- perto de alguém e, 3 segundos depois, uma boiada atravessa correndo. Quem estiver na faixa é
-- atropelado (perde parte da cesta e o ovo cai). Quem escapar ganha moedas.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnimalModel = require(Shared.AnimalModel)
local Format = require(Shared.Format)

local DataService = require(script.Parent.DataService)
local GuardianService = require(script.Parent.GuardianService)
local Notify = require(script.Parent.Notify)

local StampedeService = {}

local ROUTE = "Pasto"
local INTERVAL_MIN, INTERVAL_MAX = 35, 60
local WARN_SECONDS = 3
local LANE_WIDTH = 18
local COW_COUNT = 7
local COW_SPEED = 45
local COW_SCALE = 1.3
local HIT_RADIUS = 5.5
local DROP_FRACTION = 0.2
local ESCAPE_REWARD = 250
local RED = Color3.fromRGB(255, 60, 50)

local rng = Random.new()

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function inZone(zone, position: Vector3): boolean
	local offset = position - zone.origin
	local half = zone.size / 2
	return math.abs(offset.X) <= half and math.abs(offset.Z) <= half
end

local function inSafe(zone, position: Vector3): boolean
	return (flat(position) - flat(zone.safeCenter)).Magnitude <= zone.safeRadius
end

local function playersIn(zone): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root and inZone(zone, root.Position) and not inSafe(zone, root.Position) then
			table.insert(list, player)
		end
	end
	return list
end

local function run(zone)
	local targets = playersIn(zone)
	if #targets == 0 then
		return
	end
	local victim = targets[rng:NextInteger(1, #targets)]
	local aim = rootOf(victim)
	if not aim then
		return
	end
	local half = zone.size / 2
	-- Direção: ao longo de X ou de Z, passando pela posição de alguém.
	local alongX = rng:NextNumber() < 0.5
	local sign = if rng:NextNumber() < 0.5 then 1 else -1
	local direction = if alongX then Vector3.new(sign, 0, 0) else Vector3.new(0, 0, sign)
	local laneCenter = Vector3.new(
		if alongX then zone.origin.X else aim.Position.X,
		0,
		if alongX then aim.Position.Z else zone.origin.Z
	)
	local start = laneCenter - direction * (half + 10)
	local finish = laneCenter + direction * (half + 10)

	-- Aviso: faixa vermelha piscando no chão.
	local stripe = Instance.new("Part")
	stripe.Name = "FaixaEstouro"
	stripe.Anchored = true
	stripe.CanCollide = false
	stripe.CanQuery = false
	stripe.CanTouch = false
	stripe.Material = Enum.Material.Neon
	stripe.Color = RED
	stripe.Size = if alongX then Vector3.new(zone.size, 0.2, LANE_WIDTH) else Vector3.new(LANE_WIDTH, 0.2, zone.size)
	stripe.CFrame = CFrame.new(laneCenter + Vector3.new(0, 0.35, 0))
	stripe.Parent = zone.nodes
	for _, player in targets do
		Notify.big(player, "🐄 ESTOURO DA BOIADA!", "Saia da faixa vermelha! 3… 2… 1…", RED, "galo")
	end
	local blinkEnds = os.clock() + WARN_SECONDS
	while os.clock() < blinkEnds do
		stripe.Transparency = if stripe.Transparency < 0.5 then 0.75 else 0.35
		task.wait(0.2)
	end
	stripe.Transparency = 0.8

	-- Boiada: vacas bravas em formação, correndo pela faixa.
	local cows = {}
	for i = 1, COW_COUNT do
		local model = AnimalModel.build("Vaca", 1, false, "Boiada", true)
		local tag = model.PrimaryPart and model.PrimaryPart:FindFirstChild("Tag")
		if tag then
			tag:Destroy()
		end
		model:ScaleTo(COW_SCALE)
		local sideways = Vector3.new(direction.Z, 0, -direction.X)
		local offset = sideways * rng:NextNumber(-LANE_WIDTH / 2 + 2, LANE_WIDTH / 2 - 2) - direction * (i - 1) * 4.5
		model:PivotTo(CFrame.lookAt(start + offset, start + offset + direction))
		model:SetAttribute("Acao", "correr")
		model.Parent = zone.nodes
		table.insert(cows, { model = model, root = model.PrimaryPart :: BasePart, offset = offset })
	end

	local hit: { [Player]: boolean } = {}
	local travelled = 0
	local total = (finish - start).Magnitude + COW_COUNT * 4.5
	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		travelled += COW_SPEED * dt
		local now = os.clock()
		for index, cow in cows do
			local at = start + cow.offset + direction * travelled
			local hop = math.abs(math.sin(now * 14 + index)) * 0.8
			cow.root.CFrame = CFrame.lookAt(at + Vector3.new(0, hop, 0), at + Vector3.new(0, hop, 0) + direction)
			for _, player in Players:GetPlayers() do
				local root = rootOf(player)
				if root and not hit[player] and not inSafe(zone, root.Position) then
					local offset = root.Position - at
					if flat(offset).Magnitude <= HIT_RADIUS * COW_SCALE and math.abs(offset.Y) < 8 then
						hit[player] = true
						GuardianService.knock(player, at, zone, "Estouro da Boiada", DROP_FRACTION)
					end
				end
			end
		end
		if travelled >= total then
			connection:Disconnect()
		end
	end)
	while connection.Connected do
		task.wait(0.2)
	end
	for _, cow in cows do
		cow.model:Destroy()
	end
	stripe:Destroy()

	for _, player in targets do
		if player.Parent and not hit[player] then
			local profile = DataService.get(player)
			if profile then
				profile.stats.stampedes = (profile.stats.stampedes or 0) + 1
				DataService.addCoins(player, ESCAPE_REWARD)
				DataService.push(player)
				Notify.toast(player, "🐄 Você escapou do estouro! +💰 " .. Format.number(ESCAPE_REWARD), Color3.fromRGB(95, 235, 70), "boost")
			end
		end
	end
end

function StampedeService.init(zones)
	local zone = zones[ROUTE]
	if not zone then
		return
	end
	task.spawn(function()
		while true do
			task.wait(rng:NextNumber(INTERVAL_MIN, INTERVAL_MAX))
			local ok, err = pcall(run, zone)
			if not ok then
				warn("[StampedeService]", err)
			end
		end
	end)
end

-- Para testar no Studio: Workspace:SetAttribute("ForcarEstouro", true).
function StampedeService.force(zones)
	local zone = zones[ROUTE]
	if zone then
		task.spawn(run, zone)
	end
end

return StampedeService
