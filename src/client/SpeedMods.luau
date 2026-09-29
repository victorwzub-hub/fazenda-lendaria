-- Terreno muda a velocidade do jogador (no cliente, que é quem move o personagem):
--   🟫 Lama (tag "Lama", Chiqueiro): fica lento
--   🛝 Lama escorregadia (tag "Escorrega"): fica bem rápido
--   🌳 Árvore do Tesouro: velocidade limitada, para quem é muito rápido não cair dos galhos
-- A base vem do servidor no atributo "Velocidade" (FarmService.applySpeed).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local SpeedMods = {}

local MUD_MULT = 0.55
local SLIDE_MULT = 1.8
local TREE_CAP = 20
local TREE_RADIUS = 22
local TREE_MIN_HEIGHT = 2.5

-- Terreno atual ("lama", "escorrega", "arvore" ou nil): o HUD mostra ao lado da velocidade.
SpeedMods.terrain = nil :: string?

local player = Players.LocalPlayer
local trunks: { BasePart } = {}

local function findTrunks()
	trunks = {}
	local world = Workspace:FindFirstChild("Mundo")
	local zones = world and world:FindFirstChild("Rotas")
	if not zones then
		return
	end
	for _, zone in zones:GetChildren() do
		local tree = zone:FindFirstChild("ArvoreDoTesouro")
		local trunk = tree and tree:FindFirstChild("Tronco")
		if trunk and trunk:IsA("BasePart") then
			table.insert(trunks, trunk)
		end
	end
end

local function onMud(position: Vector3): boolean
	for _, part in CollectionService:GetTagged("Lama") do
		if part:IsA("BasePart") then
			-- Cilindro deitado: o raio está em Size.Y.
			local offset = position - part.Position
			if Vector3.new(offset.X, 0, offset.Z).Magnitude <= part.Size.Y / 2 and offset.Y < 5 and offset.Y > -1 then
				return true
			end
		end
	end
	return false
end

local function onSlide(position: Vector3): boolean
	for _, part in CollectionService:GetTagged("Escorrega") do
		if part:IsA("BasePart") then
			local rel = part.CFrame:PointToObjectSpace(position)
			if math.abs(rel.X) <= part.Size.X / 2 and math.abs(rel.Z) <= part.Size.Z / 2 and rel.Y < 5 and rel.Y > -1 then
				return true
			end
		end
	end
	return false
end

local function onTree(position: Vector3): boolean
	for _, trunk in trunks do
		local bottom = trunk.Position.Y - trunk.Size.Y / 2
		local offset = position - trunk.Position
		if Vector3.new(offset.X, 0, offset.Z).Magnitude <= TREE_RADIUS and position.Y > bottom + TREE_MIN_HEIGHT + 3 then
			return true
		end
	end
	return false
end

function SpeedMods.start()
	task.delay(3, findTrunks)
	local lastScan = os.clock()
	RunService.Heartbeat:Connect(function()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local base = player:GetAttribute("Velocidade")
		if not humanoid or not root or type(base) ~= "number" then
			return
		end
		if #trunks == 0 and os.clock() - lastScan > 5 then
			lastScan = os.clock()
			findTrunks()
		end
		local speed = base
		local terrain = nil
		if not player:GetAttribute("CorridaVelocidade") then
			local position = root.Position
			if onTree(position) then
				terrain = "arvore"
				speed = math.min(speed, TREE_CAP)
			elseif onSlide(position) then
				terrain = "escorrega"
				speed *= SLIDE_MULT
			elseif onMud(position) then
				terrain = "lama"
				speed *= MUD_MULT
			end
		end
		SpeedMods.terrain = terrain
		if math.abs(humanoid.WalkSpeed - speed) > 0.01 then
			humanoid.WalkSpeed = speed
		end
	end)
end

return SpeedMods
