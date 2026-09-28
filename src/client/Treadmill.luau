-- Visual da esteira no cliente: setas da lona correndo, boneco correndo sozinho,
-- "+10 ⚡" subindo a cada ganho e aura de fogo enquanto treina.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Style = require(ReplicatedStorage:WaitForChild("Shared").Style)

local Treadmill = {}

local BELT_SPEED = 7 -- studs/s das setas
local RUN_ANIMATION_SPEED = 1.6
local FLAME = "rbxasset://textures/particles/fire_main.dds"

local player = Players.LocalPlayer
local runTrack: AnimationTrack? = nil
local aura: ParticleEmitter? = nil

type Chevron = { model: Model, belt: BasePart, base: number }
local chevrons: { Chevron } = {}

local function collectChevrons()
	local lotes = Workspace:WaitForChild("Mundo"):WaitForChild("Lotes")
	for _, lote in lotes:GetChildren() do
		local esteira = lote:FindFirstChild("Esteira")
		local belt = esteira and esteira:FindFirstChild("Lona")
		local setas = esteira and esteira:FindFirstChild("Setas")
		if belt and setas then
			for _, seta in setas:GetChildren() do
				if seta:IsA("Model") then
					local local_ = (belt :: BasePart).CFrame:PointToObjectSpace(seta:GetPivot().Position)
					table.insert(chevrons, { model = seta, belt = belt :: BasePart, base = local_.Z })
				end
			end
		end
	end
end

-- Setas andam para trás (de quem corre) e voltam para a frente ao chegar no fim.
local function animateChevrons()
	local shift = os.clock() * BELT_SPEED
	for _, chevron in chevrons do
		local length = chevron.belt.Size.Z
		local z = (chevron.base + length / 2 + shift) % length - length / 2
		chevron.model:PivotTo(chevron.belt.CFrame * CFrame.new(0, chevron.belt.Size.Y / 2 + 0.03, z))
	end
end

local function nearestBelt(root: BasePart): BasePart?
	for _, chevron in chevrons do
		local rel = chevron.belt.CFrame:PointToObjectSpace(root.Position)
		if math.abs(rel.X) <= chevron.belt.Size.X / 2 + 0.3 and math.abs(rel.Z) <= chevron.belt.Size.Z / 2 then
			return chevron.belt
		end
	end
	return nil
end

local function startRunning(character: Model, belt: BasePart)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not humanoid or not root or not animator then
		return
	end
	-- Vira o boneco para a frente da esteira (o painel fica em -Z da lona).
	local forward = -belt.CFrame.LookVector
	forward = Vector3.new(forward.X, 0, forward.Z).Unit
	root.CFrame = CFrame.lookAt(root.Position, root.Position - forward)

	local animate = character:FindFirstChild("Animate")
	local runFolder = animate and animate:FindFirstChild("run")
	local animation = runFolder and runFolder:FindFirstChildOfClass("Animation")
	if animation then
		runTrack = animator:LoadAnimation(animation)
		local track = runTrack :: AnimationTrack
		track.Looped = true
		track.Priority = Enum.AnimationPriority.Action
		track:Play(0.2, 1, RUN_ANIMATION_SPEED)
	end

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "AuraTreino"
	emitter.Texture = FLAME
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 220, 60), Color3.fromRGB(255, 70, 30))
	emitter.LightEmission = 0.8
	emitter.Rate = 40
	emitter.Lifetime = NumberRange.new(0.4, 0.7)
	emitter.Speed = NumberRange.new(4, 7)
	emitter.SpreadAngle = Vector2.new(30, 30)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2.2),
		NumberSequenceKeypoint.new(1, 0.4),
	})
	emitter.Transparency = NumberSequence.new(0.2, 1)
	emitter.Parent = root
	aura = emitter
end

local function stopRunning()
	if runTrack then
		runTrack:Stop(0.2)
		runTrack = nil
	end
	if aura then
		aura:Destroy()
		aura = nil
	end
end

-- "+10 ⚡" que sobe e some em cima do boneco.
local function popup(amount: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.CFrame = CFrame.new(root.Position + Vector3.new(math.random(-20, 20) / 10, 2, math.random(-20, 20) / 10))
	anchor.Parent = Workspace.CurrentCamera
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(5, 1.6)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.Text = "👟+" .. amount
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(120, 200, 255)
	Style.outline(label, 3)
	label.Parent = gui
	local info = TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(anchor, info, { CFrame = anchor.CFrame + Vector3.new(0, 4, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1 }):Play()
	task.delay(1.2, function()
		anchor:Destroy()
	end)
end

function Treadmill.start()
	collectChevrons()
	RunService.RenderStepped:Connect(animateChevrons)

	local running = false
	RunService.Heartbeat:Connect(function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local belt = root and nearestBelt(root)
		if belt and not running then
			running = true
			startRunning(character :: Model, belt)
		elseif not belt and running then
			running = false
			stopRunning()
		end
	end)
	player.CharacterAdded:Connect(function()
		running = false
		runTrack = nil
		aura = nil
	end)

	local last = player:GetAttribute("Treino") or 0
	player:GetAttributeChangedSignal("Treino"):Connect(function()
		local now = player:GetAttribute("Treino") or 0
		if now > last then
			popup(now - last)
		end
		last = now
	end)
end

return Treadmill
