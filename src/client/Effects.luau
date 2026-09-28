-- Efeitos pedidos pelo servidor que precisam rodar no cliente (o personagem é do cliente).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Style = require(Shared.Style)

local Effects = {}

local KNOCK_SPEED = 55
local KNOCK_LIFT = 32
local DIZZY_SECONDS = 1.2

local player = Players.LocalPlayer

-- Estrelinhas girando em cima da cabeça enquanto está tonto.
local function dizzy(head: BasePart)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(3, 1.5)
	gui.StudsOffset = Vector3.new(0, 2.4, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.Text = "💫💫"
	label.TextScaled = true
	Style.outline(label, 2)
	label.Parent = gui
	gui.Parent = head
	TweenService:Create(label, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Rotation = 12,
	}):Play()
	task.delay(DIZZY_SECONDS + 0.3, function()
		gui:Destroy()
	end)
end

local function knock(from: Vector3)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	local away = Vector3.new(root.Position.X - from.X, 0, root.Position.Z - from.Z)
	away = if away.Magnitude > 0.1 then away.Unit else -root.CFrame.LookVector

	humanoid.PlatformStand = true
	root.AssemblyLinearVelocity = away * KNOCK_SPEED + Vector3.new(0, KNOCK_LIFT, 0)
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		dizzy(head)
	end
	-- Tremidinha na câmera.
	task.spawn(function()
		for i = 1, 8 do
			humanoid.CameraOffset = Vector3.new(math.random(-10, 10), math.random(-10, 10), 0) / (20 + i * 4)
			task.wait(0.03)
		end
		humanoid.CameraOffset = Vector3.zero
	end)
	task.delay(DIZZY_SECONDS, function()
		if humanoid.Parent then
			humanoid.PlatformStand = false
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end

function Effects.start()
	Remotes.event("Effect").OnClientEvent:Connect(function(payload)
		if payload.kind == "knock" then
			knock(payload.from)
		end
	end)
end

return Effects
