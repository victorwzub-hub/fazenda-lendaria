-- 👊 Bater: tecla F (ou botão X do controle) e um botão na tela do celular.
-- O cliente só faz o avanço e a animação; quem decide se acertou é o servidor (GuardianService.hit).
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)

local Sfx = require(script.Parent.Sfx)

local Punch = {}

local COOLDOWN = 0.7
local LUNGE = 28

local player = Players.LocalPlayer
local last = 0

local function swing()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root or humanoid.PlatformStand then
		return
	end
	-- Animação de golpe que já vem no Animate do Roblox (toolslash), se existir.
	local animate = character:FindFirstChild("Animate")
	local slash = animate and animate:FindFirstChild("toolslash")
	local animation = slash and slash:FindFirstChildOfClass("Animation")
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animation and animator then
		local track = animator:LoadAnimation(animation)
		track.Priority = Enum.AnimationPriority.Action
		track:Play(0.05, 1, 1.4)
	end
	-- Pequeno avanço para a frente, dá a sensação de soco.
	local forward = root.CFrame.LookVector
	root.AssemblyLinearVelocity = Vector3.new(forward.X * LUNGE, root.AssemblyLinearVelocity.Y, forward.Z * LUNGE)
end

local function onAction(_, state: Enum.UserInputState)
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	local now = os.clock()
	if now - last < COOLDOWN then
		return Enum.ContextActionResult.Sink
	end
	last = now
	swing()
	Remotes.event("Bater"):FireServer()
	return Enum.ContextActionResult.Sink
end

function Punch.start()
	ContextActionService:BindAction("Bater", onAction, true, Enum.KeyCode.F, Enum.KeyCode.ButtonX)
	ContextActionService:SetTitle("Bater", "👊")
	ContextActionService:SetPosition("Bater", UDim2.new(1, -170, 1, -150))
end

-- "💥 POW!" onde o golpe acertou (o servidor manda quando acerta).
function Punch.pow(at: Vector3)
	Sfx.play("empurrao")
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.CFrame = CFrame.new(at + Vector3.new(0, 5, 0))
	anchor.Parent = workspace.CurrentCamera
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(7, 3)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.Text = "💥 POW!"
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 220, 60)
	label.TextStrokeTransparency = 0
	label.Rotation = math.random(-12, 12)
	label.Parent = gui
	task.delay(0.6, function()
		anchor:Destroy()
	end)
end

return Punch
