-- Pulo duplo/triplo das Botas de Pulo. JumpRequest dispara tanto no teclado quanto no
-- botão de pular do celular. Os pulos extras recarregam ao encostar no chão.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Balance = require(ReplicatedStorage:WaitForChild("Shared").Balance)

local State = require(script.Parent.State)

local DoubleJump = {}

local MIN_AIR_TIME = 0.18 -- evita gastar o pulo extra no mesmo toque do pulo normal

local player = Players.LocalPlayer
local used = 0
local leftGround = 0

local function puff(root: BasePart)
	local cloud = Instance.new("Part")
	cloud.Size = Vector3.new(0.2, 2.6, 2.6)
	cloud.Shape = Enum.PartType.Cylinder
	cloud.Color = Color3.new(1, 1, 1)
	cloud.Material = Enum.Material.SmoothPlastic
	cloud.Transparency = 0.2
	cloud.Anchored = true
	cloud.CanCollide = false
	cloud.CanQuery = false
	cloud.CanTouch = false
	cloud.CFrame = CFrame.new(root.Position - Vector3.new(0, 3, 0)) * CFrame.Angles(0, 0, math.rad(90))
	cloud.Parent = workspace.CurrentCamera
	local start = os.clock()
	task.spawn(function()
		while os.clock() - start < 0.35 do
			local t = (os.clock() - start) / 0.35
			cloud.Size = Vector3.new(0.2, 2.6 + t * 3, 2.6 + t * 3)
			cloud.Transparency = 0.2 + t * 0.8
			task.wait()
		end
		cloud:Destroy()
	end)
end

local function watch(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	used = 0
	humanoid.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running then
			used = 0
		elseif new == Enum.HumanoidStateType.Freefall or new == Enum.HumanoidStateType.Jumping then
			if leftGround == 0 or used == 0 then
				leftGround = os.clock()
			end
		end
	end)
end

function DoubleJump.start()
	if player.Character then
		task.spawn(watch, player.Character)
	end
	player.CharacterAdded:Connect(watch)

	UserInputService.JumpRequest:Connect(function()
		local profile = State.profile
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not profile or not humanoid or not root or humanoid.PlatformStand then
			return
		end
		local state = humanoid:GetState()
		local inAir = state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping
		if not inAir or os.clock() - leftGround < MIN_AIR_TIME then
			return
		end
		if used >= Balance.extraJumps(profile) then
			return
		end
		used += 1
		-- Mesma velocidade de subida de um pulo normal com a altura atual.
		local rise = math.sqrt(2 * workspace.Gravity * humanoid.JumpHeight)
		root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, rise, root.AssemblyLinearVelocity.Z)
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		puff(root)
	end)
end

return DoubleJump
