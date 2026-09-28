-- Guardiões: bichos bravos que vigiam cada rota. Quando alguém mexe num ninho (ou às vezes
-- num item), o guardião mais perto corre atrás. Se pegar, empurra, deixa tonto e derruba
-- parte da cesta no chão, que o jogador pode pegar de volta.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnimalModel = require(Shared.AnimalModel)
local Materials = require(Shared.Config.Materials)
local Remotes = require(Shared.Remotes)
local Style = require(Shared.Style)

local Basket = require(script.Parent.Basket)
local Notify = require(script.Parent.Notify)

local GuardianService = {}

type Def = { species: string, name: string, speed: number, rarity: number }

local DEFS: { [string]: Def } = {
	Galinheiro = { species = "Galinha", name = "Galo Bravo", speed = 15, rarity = 3 },
	Chiqueiro = { species = "Porco", name = "Porco Bravo", speed = 17, rarity = 3 },
	Pasto = { species = "Vaca", name = "Touro Bravo", speed = 19, rarity = 4 },
	Pradaria = { species = "Cavalo", name = "Cavalo Selvagem", speed = 21, rarity = 4 },
}

local PER_ZONE = 3
local MODEL_SCALE = 1.6
local ALERT_RADIUS = 70
local CATCH_DISTANCE = 4
local NOTICE_SECONDS = 0.8
local CHASE_SECONDS = 7
local CHARGE_SECONDS = 2
local CHARGE_MULT = 1.3
local COOLDOWN = 5
local DROP_FRACTION = 0.3
local DROP_LIFETIME = 45
local WANDER_RADIUS = 22
local WANDER_SPEED = 5
local ANGRY = Color3.fromRGB(255, 70, 60)

type Guardian = {
	def: Def,
	zone: any,
	model: Model,
	root: BasePart,
	alert: BillboardGui,
	home: Vector3,
	state: string,
	target: Player?,
	chaseEnds: number,
	chargeEnds: number,
	noticeEnds: number,
	cooldownUntil: number,
	wanderTo: Vector3?,
	nextWander: number,
}

local guardians: { Guardian } = {}
local chasing: { [Player]: Guardian } = {}
local rng = Random.new()
local EffectRemote: RemoteEvent

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function inZone(zone, position: Vector3): boolean
	local offset = position - zone.origin
	local half = zone.size / 2
	return math.abs(offset.X) <= half and math.abs(offset.Z) <= half
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function stopChase(guardian: Guardian)
	if guardian.target then
		if chasing[guardian.target] == guardian then
			chasing[guardian.target] = nil
			guardian.target:SetAttribute("Perseguido", nil)
		end
	end
	guardian.target = nil
	guardian.state = "return"
	guardian.alert.Enabled = false
end

-- Monta a pilha de itens caídos; só o dono pode pegar de volta.
local function dropPile(owner: Player, zone, position: Vector3, items: { [string]: number })
	local model = Instance.new("Model")
	model.Name = "Cesta caída"
	local base = Instance.new("Part")
	base.Size = Vector3.new(2.6, 0.8, 2.6)
	base.Color = Color3.fromRGB(170, 110, 55)
	base.Material = Enum.Material.WoodPlanks
	base.Anchored = true
	base.CanCollide = false
	base.CFrame = CFrame.new(position.X, 0.4, position.Z)
	base.Parent = model
	local i = 0
	for materialId in items do
		local material = Materials.byId[materialId]
		local cube = Instance.new("Part")
		cube.Size = Vector3.one * 0.8
		cube.Color = if material then material.color else Color3.new(1, 1, 1)
		cube.Material = Enum.Material.SmoothPlastic
		cube.Anchored = true
		cube.CanCollide = false
		cube.CFrame = base.CFrame * CFrame.new((i % 2) * 0.9 - 0.45, 0.8, math.floor(i / 2) * 0.9 - 0.45)
		cube.Parent = model
		i += 1
	end
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 220, 120)
	light.Range = 8
	light.Parent = base
	Style.apply(model)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pegar de volta"
	prompt.ObjectText = "Seus itens"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = base

	local taken = false
	prompt.Triggered:Connect(function(player)
		if taken then
			return
		end
		if player ~= owner then
			Notify.toast(player, "Esses itens são de " .. owner.DisplayName, ANGRY)
			return
		end
		taken = true
		local recovered = 0
		for materialId, amount in items do
			recovered += Basket.add(player, materialId, amount)
		end
		model:Destroy()
		Notify.toast(player, "🧺 Pegou de volta " .. recovered .. " itens!", Color3.fromRGB(95, 235, 70))
	end)
	model.Parent = zone.nodes
	task.delay(DROP_LIFETIME, function()
		if model.Parent then
			model:Destroy()
		end
	end)
end

local function catch(guardian: Guardian, player: Player)
	local root = rootOf(player)
	stopChase(guardian)
	guardian.cooldownUntil = os.clock() + COOLDOWN
	if not root then
		return
	end
	EffectRemote:FireClient(player, { kind = "knock", from = guardian.root.Position })
	local dropped = Basket.take(player, DROP_FRACTION)
	local count = 0
	for _, amount in dropped do
		count += amount
	end
	if count > 0 then
		dropPile(player, guardian.zone, root.Position, dropped)
		Notify.toast(player, "💥 O " .. guardian.def.name .. " te pegou! Caíram " .. count .. " itens", ANGRY)
	else
		Notify.toast(player, "💥 O " .. guardian.def.name .. " te pegou!", ANGRY)
	end
end

-- Primeiro o guardião "percebe" (para, vira, "!" e pulinho); só depois corre.
-- Esse aviso dá tempo de reagir mesmo quando o ninho nasce perto dele.
local function startChase(guardian: Guardian, player: Player)
	local now = os.clock()
	guardian.state = "alert"
	guardian.target = player
	guardian.chaseEnds = now + NOTICE_SECONDS + CHASE_SECONDS
	guardian.chargeEnds = now + NOTICE_SECONDS + CHARGE_SECONDS
	guardian.noticeEnds = now + NOTICE_SECONDS
	guardian.alert.Enabled = true
	chasing[player] = guardian
	player:SetAttribute("Perseguido", guardian.def.name)
end

-- Chamado pela coleta: `chance` é a probabilidade de o guardião mais perto vir atrás.
function GuardianService.alert(player: Player, position: Vector3, chance: number)
	if chasing[player] or rng:NextNumber() > chance then
		return
	end
	local now = os.clock()
	local best: Guardian? = nil
	local bestDistance = ALERT_RADIUS
	for _, guardian in guardians do
		if guardian.state ~= "chase" and guardian.state ~= "alert" and now >= guardian.cooldownUntil and inZone(guardian.zone, position) then
			local distance = (flat(guardian.root.Position) - flat(position)).Magnitude
			if distance < bestDistance then
				best, bestDistance = guardian, distance
			end
		end
	end
	if best then
		startChase(best, player)
	end
end

local function step(guardian: Guardian, dt: number, now: number)
	local position = guardian.root.Position
	local goal: Vector3? = nil
	local speed = WANDER_SPEED

	if guardian.state == "alert" then
		local target = guardian.target and rootOf(guardian.target)
		if not target then
			stopChase(guardian)
			return
		end
		local look = flat(target.Position) - flat(position)
		local at = Vector3.new(position.X, math.abs(math.sin(now * 18)) * 1.4, position.Z)
		guardian.root.CFrame = if look.Magnitude > 0.1
			then CFrame.lookAt(at, at + look.Unit)
			else CFrame.new(at) * guardian.root.CFrame.Rotation
		if now >= guardian.noticeEnds then
			guardian.state = "chase"
		end
		return
	end

	if guardian.state == "chase" then
		local player = guardian.target :: Player
		local target = rootOf(player)
		if not target or now > guardian.chaseEnds or not inZone(guardian.zone, target.Position) then
			stopChase(guardian)
		else
			goal = target.Position
			speed = guardian.def.speed * (if now < guardian.chargeEnds then CHARGE_MULT else 1)
			if (flat(target.Position) - flat(position)).Magnitude <= CATCH_DISTANCE then
				catch(guardian, player)
				goal = nil
			end
		end
	end
	if guardian.state == "return" then
		goal = guardian.home
		speed = guardian.def.speed * 0.6
		if (flat(guardian.home) - flat(position)).Magnitude < 2 then
			guardian.state = "idle"
		end
	end
	if guardian.state == "idle" then
		if not guardian.wanderTo or now > guardian.nextWander then
			local angle = rng:NextNumber(0, math.pi * 2)
			local radius = rng:NextNumber(4, WANDER_RADIUS)
			guardian.wanderTo = guardian.home + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
			guardian.nextWander = now + rng:NextNumber(3, 6)
		end
		goal = guardian.wanderTo
	end

	if not goal then
		return
	end
	local offset = flat(goal) - flat(position)
	local distance = offset.Magnitude
	if distance < 0.5 then
		return
	end
	local direction = offset.Unit
	local moved = flat(position) + direction * math.min(distance, speed * dt)
	-- Pulinho enquanto anda: mais alto quando está correndo atrás de alguém.
	local hop = math.abs(math.sin(now * (if guardian.state == "chase" then 14 else 8))) * (if guardian.state
			== "chase"
		then 0.9
		else 0.3)
	local at = Vector3.new(moved.X, hop, moved.Z)
	guardian.root.CFrame = CFrame.lookAt(at, at + direction)
end

local function makeAlert(root: BasePart): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "Alerta"
	gui.Size = UDim2.fromScale(4, 4)
	gui.StudsOffset = Vector3.new(0, 12, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Enabled = false
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.Text = "!"
	label.TextScaled = true
	label.TextColor3 = ANGRY
	Style.outline(label, 4)
	label.Parent = gui
	gui.Parent = root
	return gui
end

function GuardianService.init(zones)
	EffectRemote = Remotes.event("Effect")
	for routeId, zone in zones do
		local def = DEFS[routeId]
		if def then
			local folder = Instance.new("Folder")
			folder.Name = "Guardioes"
			folder.Parent = zone.nodes.Parent
			for i = 1, PER_ZONE do
				local model = AnimalModel.build(def.species, def.rarity, false, def.name)
				model:ScaleTo(MODEL_SCALE)
				local root = model.PrimaryPart :: BasePart
				local tag = root:FindFirstChild("Tag")
				local tagLabel = tag and tag:FindFirstChildOfClass("TextLabel")
				if tagLabel then
					tagLabel.Text = "😠 " .. def.name
					tagLabel.TextColor3 = ANGRY
				end
				local angle = (i / PER_ZONE) * math.pi * 2
				local home = zone.origin + Vector3.new(math.cos(angle), 0, math.sin(angle)) * zone.size * 0.25
				model:PivotTo(CFrame.new(home))
				model.Parent = folder
				table.insert(guardians, {
					def = def,
					zone = zone,
					model = model,
					root = root,
					alert = makeAlert(root),
					home = home,
					state = "idle",
					target = nil,
					chaseEnds = 0,
					chargeEnds = 0,
					noticeEnds = 0,
					cooldownUntil = 0,
					wanderTo = nil,
					nextWander = 0,
				})
			end
		end
	end

	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		for _, guardian in guardians do
			step(guardian, dt, now)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local guardian = chasing[player]
		if guardian then
			stopChase(guardian)
		end
	end)
end

return GuardianService
