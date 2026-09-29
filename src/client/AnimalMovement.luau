-- A fazenda publica trechos de caminhada; cada cliente desenha os bichos entre os pontos.
-- Guardiões continuam sendo simulados e acertando jogadores somente no servidor.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AnimalModel = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").AnimalModel)

local AnimalMovement = {}
local MAX_DISTANCE = 240
local tracked: { [Model]: BasePart } = {}

local function track(instance: Instance)
	if instance:IsA("Model") then
		local root = instance.PrimaryPart or instance:FindFirstChild("Root") or instance:WaitForChild("Root", 5)
		if root and root:IsA("BasePart") then
			tracked[instance] = root
		end
	end
end

function AnimalMovement.start()
	for _, instance in CollectionService:GetTagged(AnimalModel.ANIMATED_TAG) do
		track(instance)
	end
	CollectionService:GetInstanceAddedSignal(AnimalModel.ANIMATED_TAG):Connect(function(instance)
		task.defer(track, instance)
	end)
	CollectionService:GetInstanceRemovedSignal(AnimalModel.ANIMATED_TAG):Connect(function(instance)
		tracked[instance :: Model] = nil
	end)

	RunService.RenderStepped:Connect(function(dt)
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local now = Workspace:GetServerTimeNow()
		for model, root in tracked do
			if not model.Parent then
				tracked[model] = nil
			elseif (root.Position - camera.CFrame.Position).Magnitude <= MAX_DISTANCE then
				local started = model:GetAttribute("PasseioQuando")
				if type(started) == "number" then
					local from = model:GetAttribute("PasseioDe")
					local to = model:GetAttribute("PasseioPara")
					local duration = model:GetAttribute("PasseioDuracao")
					if typeof(from) == "CFrame" and typeof(to) == "CFrame" and type(duration) == "number" and duration > 0 then
						root.CFrame = from:Lerp(to, math.clamp((now - started) / duration, 0, 1))
					end
				else
					local pose = model:GetAttribute("Pose")
					if typeof(pose) == "CFrame" then
						root.CFrame = if (root.Position - pose.Position).Magnitude > 12 then pose else root.CFrame:Lerp(pose, math.min(1, dt * 22))
					end
				end
			end
		end
	end)
end

return AnimalMovement
