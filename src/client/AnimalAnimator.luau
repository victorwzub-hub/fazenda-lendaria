-- Dá vida aos bichos (tag "Bicho", ver AnimalModel): patas andando conforme a velocidade,
-- cabeça balançando, rabo abanando, asas batendo quando correm, e as ações paradas que o
-- servidor pede no atributo "Acao" (farejar, comer, dormir, tonto, desmaiado).
-- Tudo roda só no cliente (Motor6D.Transform), então não pesa a rede.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AnimalModel = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").AnimalModel)

local AnimalAnimator = {}

local MAX_DISTANCE = 220
local LOOK_DISTANCE = 18
local LEG_SWING = 0.75
local SLEEP_TEXT = "💤"

type Rig = {
	model: Model,
	root: BasePart,
	groups: { [string]: { Motor6D } },
	lastPos: Vector3,
	lastMove: number,
	speed: number,
	phase: number,
	seed: number,
	scale: number,
	zzz: BillboardGui?,
	scans: number,
}

local rigs: { [Model]: Rig } = {}
local player = Players.LocalPlayer

local function collect(rig: Rig)
	rig.groups = {}
	for _, descendant in rig.model:GetDescendants() do
		if descendant:IsA("Motor6D") then
			local list = rig.groups[descendant.Name]
			if not list then
				list = {}
				rig.groups[descendant.Name] = list
			end
			table.insert(list, descendant)
		end
	end
	rig.scans += 1
end

local function track(model: Instance)
	if not model:IsA("Model") or rigs[model] then
		return
	end
	local root = model.PrimaryPart or model:FindFirstChild("Root")
	if not root then
		return
	end
	local extents = model:GetExtentsSize()
	local rig: Rig = {
		model = model,
		root = root :: BasePart,
		groups = {},
		lastPos = (root :: BasePart).Position,
		lastMove = os.clock(),
		speed = 0,
		phase = math.random() * 10,
		seed = math.random() * 100,
		scale = math.max(extents.Y / 4, 0.5),
		zzz = nil,
		scans = 0,
	}
	collect(rig)
	rigs[model] = rig
end

local function setGroup(rig: Rig, name: string, transform: CFrame)
	local list = rig.groups[name]
	if list then
		for _, motor in list do
			motor.Transform = transform
		end
	end
end

local function sleepBubble(rig: Rig, asleep: boolean)
	if asleep and not rig.zzz then
		local gui = Instance.new("BillboardGui")
		gui.Name = "Zzz"
		gui.Size = UDim2.fromOffset(60, 60)
		gui.StudsOffset = Vector3.new(1.5, 3 + rig.scale * 3, 0)
		gui.MaxDistance = 90
		gui.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.TextScaled = true
		label.Text = SLEEP_TEXT
		label.Parent = gui
		gui.Parent = rig.root
		rig.zzz = gui
	elseif not asleep and rig.zzz then
		rig.zzz:Destroy()
		rig.zzz = nil
	end
end

local function animate(rig: Rig, dt: number, now: number, camera: Vector3, me: Vector3?)
	local root = rig.root
	local position = root.Position
	if (position - camera).Magnitude > MAX_DISTANCE then
		return
	end
	if next(rig.groups) == nil and rig.scans < 5 then
		collect(rig)
	end

	-- Velocidade pelo quanto andou (o servidor/cliente move o Root). Os passos chegam da rede
	-- aos pulinhos, então mede entre mudanças e suaviza.
	local moved = Vector3.new(position.X - rig.lastPos.X, 0, position.Z - rig.lastPos.Z).Magnitude
	local raw = rig.speed
	if moved > 0.02 then
		raw = moved / math.max(now - rig.lastMove, dt)
		rig.lastMove = now
		rig.lastPos = position
	elseif now - rig.lastMove > 0.3 then
		raw = 0
		rig.lastPos = position
	end
	rig.speed += (math.min(raw, 80) - rig.speed) * math.min(1, dt * 8)

	local action = rig.model:GetAttribute("Acao")
	local stride = rig.speed / rig.scale
	local walking = math.clamp(stride / 6, 0, 1)
	rig.phase += dt * (4 + math.min(stride, 40) * 0.55)
	local swing = math.sin(rig.phase) * LEG_SWING * walking
	local t = now + rig.seed

	-- Patas: diagonais juntas (frente-esquerda com trás-direita).
	local a, b = CFrame.Angles(swing, 0, 0), CFrame.Angles(-swing, 0, 0)
	setGroup(rig, "legFL", a)
	setGroup(rig, "legBR", a)
	setGroup(rig, "legFR", b)
	setGroup(rig, "legBL", b)
	setGroup(rig, "legL", a)
	setGroup(rig, "legR", b)

	-- Cabeça: balança andando, abaixa para farejar/comer, olha para você quando está perto.
	local pitch = math.sin(rig.phase * 2) * 0.06 * walking
	local yaw = 0
	local roll = 0
	if action == "farejar" then
		pitch = -0.45 + math.sin(t * 7) * 0.1
		yaw = math.sin(t * 1.7) * 0.4
	elseif action == "comer" then
		pitch = -0.7 + math.abs(math.sin(t * 5)) * 0.2
	elseif action == "dormir" or action == "desmaiado" then
		pitch = -0.35 + math.sin(t * 1.5) * 0.04
	elseif action == "tonto" then
		roll = math.sin(t * 9) * 0.3
		yaw = math.cos(t * 9) * 0.3
	elseif walking < 0.2 and me and (me - position).Magnitude < LOOK_DISTANCE then
		local rel = root.CFrame:PointToObjectSpace(me)
		yaw = math.clamp(math.atan2(-rel.X, -rel.Z), -0.9, 0.9)
		pitch = 0.1
	else
		yaw = math.sin(t * 0.6) * 0.15
	end
	setGroup(rig, "head", CFrame.Angles(pitch, yaw, roll))

	-- Rabo abana; mais rápido correndo.
	local wagSpeed = if action == "correr" or walking > 0.6 then 16 else 6
	setGroup(rig, "tail", CFrame.Angles(0, math.sin(t * wagSpeed) * 0.35, 0))

	-- Asas: batem correndo ou de vez em quando.
	local flap = 0
	if action == "correr" or walking > 0.8 then
		flap = math.abs(math.sin(t * 20)) * 0.9
	elseif math.sin(t * 0.7) > 0.97 then
		flap = math.abs(math.sin(t * 18)) * 0.6
	end
	setGroup(rig, "wingR", CFrame.Angles(0, 0, flap))
	setGroup(rig, "wingL", CFrame.Angles(0, 0, -flap))

	sleepBubble(rig, action == "dormir")
end

function AnimalAnimator.start()
	for _, model in CollectionService:GetTagged(AnimalModel.ANIMATED_TAG) do
		track(model)
	end
	CollectionService:GetInstanceAddedSignal(AnimalModel.ANIMATED_TAG):Connect(function(model)
		task.defer(track, model)
	end)
	CollectionService:GetInstanceRemovedSignal(AnimalModel.ANIMATED_TAG):Connect(function(model)
		rigs[model] = nil
	end)

	RunService.Stepped:Connect(function(_, dt)
		local now = os.clock()
		local camera = Workspace.CurrentCamera.CFrame.Position
		local character = player.Character
		local me = character and character:FindFirstChild("HumanoidRootPart")
		local myPosition = if me then (me :: BasePart).Position else nil
		for model, rig in rigs do
			if not model.Parent then
				rigs[model] = nil
			else
				animate(rig, dt, now, camera, myPosition)
			end
		end
	end)
end

return AnimalAnimator
