-- Mostra os equipamentos comprados no boneco (todo mundo vê):
-- 👢 botas nos pés, 🥅 rede na mão e 🧺 cesta nas costas que enche conforme a coleta.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Style = require(Shared.Style)

local DataService = require(script.Parent.DataService)

local EquipmentService = {}

local FOLDER = "Equipamento"
local WICKER = Color3.fromRGB(196, 140, 72)
-- Cor das botas sobe de "tier" a cada 3 níveis: couro, azul, roxo, dourada.
local BOOT_TIERS = {
	Color3.fromRGB(120, 72, 40),
	Color3.fromRGB(60, 140, 235),
	Color3.fromRGB(165, 90, 230),
	Color3.fromRGB(255, 200, 50),
}

local function findPart(character: Model, ...: string): BasePart?
	for _, name in { ... } do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			return part
		end
	end
	return nil
end

local function attach(folder: Instance, anchor: BasePart, size: Vector3, offset: CFrame, color: Color3, name: string?): Part
	local part = Instance.new("Part")
	part.Name = name or "Peca"
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.Plastic
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	part.CFrame = anchor.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchor
	weld.Part1 = part
	weld.Parent = part
	part.Parent = folder
	return part
end

local function boots(folder: Instance, character: Model, level: number)
	local color = BOOT_TIERS[math.clamp(math.ceil(level / 3), 1, #BOOT_TIERS)]
	for _, pair in { { "LeftFoot", "Left Leg" }, { "RightFoot", "Right Leg" } } do
		local foot = findPart(character, pair[1], pair[2])
		if foot then
			local isR6 = foot.Name:find("Leg") ~= nil
			local y = if isR6 then -foot.Size.Y / 2 + 0.35 else 0
			local boot = attach(folder, foot, Vector3.new(foot.Size.X + 0.2, 0.7, foot.Size.Z + 0.3), CFrame.new(0, y, -0.05), color)
			Style.studs(boot)
			attach(folder, foot, Vector3.new(foot.Size.X + 0.25, 0.2, foot.Size.Z + 0.35), CFrame.new(0, y + 0.4, -0.05), Style.shade(color, 0.35))
		end
	end
end

-- Molinhas das Botas de Pulo embaixo de cada pé.
local function springs(folder: Instance, character: Model, level: number)
	local color = if level >= 3 then Color3.fromRGB(255, 200, 50) else Color3.fromRGB(80, 230, 120)
	for _, pair in { { "LeftFoot", "Left Leg" }, { "RightFoot", "Right Leg" } } do
		local foot = findPart(character, pair[1], pair[2])
		if foot then
			local bottom = -foot.Size.Y / 2
			for i = 0, 2 do
				local ring = attach(
					folder,
					foot,
					Vector3.new(0.18, 0.7, 0.7),
					CFrame.new(0, bottom - 0.15 - i * 0.22, 0) * CFrame.Angles(0, 0, math.rad(90)),
					color
				)
				ring.Shape = Enum.PartType.Cylinder
				ring.Material = Enum.Material.Metal
			end
		end
	end
end

local function net(folder: Instance, character: Model, level: number)
	local hand = findPart(character, "RightHand", "Right Arm")
	if not hand then
		return
	end
	local isR6 = hand.Name == "Right Arm"
	local grip = CFrame.new(0, if isR6 then -hand.Size.Y / 2 else 0, 0)
	attach(folder, hand, Vector3.new(0.25, 3.2, 0.25), grip * CFrame.new(0, 0.9, -0.3) * CFrame.Angles(math.rad(-20), 0, 0), Color3.fromRGB(150, 95, 50))
	local ring = attach(folder, hand, Vector3.new(1.6, 0.2, 1.6), grip * CFrame.new(0, 2.6, -0.9) * CFrame.Angles(math.rad(-20), 0, 0), Color3.fromRGB(235, 235, 235))
	ring.Transparency = 0.35
	-- A rede fica mais colorida conforme o nível.
	ring.Color = if level >= 6 then Color3.fromRGB(255, 205, 60) elseif level >= 3 then Color3.fromRGB(120, 210, 255) else ring.Color
end

local function basket(folder: Instance, character: Model, level: number, fill: number)
	local torso = findPart(character, "UpperTorso", "Torso")
	if not torso then
		return
	end
	local grow = 1 + 0.05 * level
	local depth = torso.Size.Z / 2
	local body = attach(folder, torso, Vector3.new(1.8, 1.8, 1.2) * grow, CFrame.new(0, -0.1, depth + 0.6 * grow), WICKER, "Cesta")
	Style.studs(body)
	attach(folder, torso, Vector3.new(1.95, 0.25, 1.35) * grow, CFrame.new(0, 0.85 * grow - 0.1, depth + 0.6 * grow), Style.shade(WICKER, -0.25))
	-- Alças.
	for _, x in { -0.55, 0.55 } do
		attach(folder, torso, Vector3.new(0.2, torso.Size.Y * 0.9, 0.12), CFrame.new(x, 0, depth + 0.05), Style.shade(WICKER, -0.35))
	end
	-- O "recheio" sobe conforme a cesta enche.
	if fill > 0 then
		local height = math.max(0.15, 1.6 * grow * math.min(fill, 1))
		attach(
			folder,
			torso,
			Vector3.new(1.5, height, 0.9) * Vector3.new(grow, 1, grow),
			CFrame.new(0, -0.1 - 0.9 * grow + height / 2 + 0.05, depth + 0.6 * grow),
			Color3.fromRGB(255, 205, 60),
			"Recheio"
		)
	end
end

function EquipmentService.refresh(player: Player)
	local character = player.Character
	local profile = DataService.get(player)
	if not character or not profile then
		return
	end
	local old = character:FindFirstChild(FOLDER)
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Model")
	folder.Name = FOLDER

	local upgrades = profile.upgrades
	if (upgrades.Velocidade or 0) > 0 then
		boots(folder, character, upgrades.Velocidade)
	end
	if (upgrades.Pulo or 0) > 0 then
		springs(folder, character, upgrades.Pulo)
	end
	if (upgrades.Rede or 0) > 0 then
		net(folder, character, upgrades.Rede)
	end
	local count = player:GetAttribute("Cesta") or 0
	local max = player:GetAttribute("CestaMax") or 1
	if (upgrades.Cesta or 0) > 0 or count > 0 then
		basket(folder, character, upgrades.Cesta or 0, count / math.max(max, 1))
	end
	folder.Parent = character
end

function EquipmentService.init()
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("HumanoidRootPart", 10)
			task.wait(0.5)
			EquipmentService.refresh(player)
		end)
		player:GetAttributeChangedSignal("Cesta"):Connect(function()
			EquipmentService.refresh(player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return EquipmentService
