-- Move os pets de todos os jogadores (Workspace.Pets/<nome>) atrás dos donos, em leque,
-- pulando de leve enquanto andam. Roda no cliente para ficar lisinho.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PetFollow = {}

local SPACING = 4.5
local BEHIND = 5.5
local FOLLOW_SPEED = 7
local SNAP_DISTANCE = 70
local HOP_HEIGHT = 0.7

type State = { position: Vector3, facing: Vector3, ground: number, nextRay: number }

local states: { [Model]: State } = {}
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

local function groundAt(position: Vector3, ignore: { Instance }): number?
	params.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(position + Vector3.new(0, 8, 0), Vector3.new(0, -30, 0), params)
	return if hit then hit.Position.Y else nil
end

function PetFollow.start()
	local folder = Workspace:WaitForChild("Pets")
	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		local ignore: { Instance } = { folder }
		for _, other in Players:GetPlayers() do
			if other.Character then
				table.insert(ignore, other.Character)
			end
		end
		for _, mine in folder:GetChildren() do
			local owner = Players:GetPlayerByUserId(mine:GetAttribute("Dono") or 0)
			local character = owner and owner.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local total = mine:GetAttribute("Total") or 1
			for _, pet in mine:GetChildren() do
				local petRoot = pet:IsA("Model") and pet.PrimaryPart
				if root and petRoot then
					local slot = pet:GetAttribute("Slot") or 1
					local side = (slot - (total + 1) / 2) * SPACING
					local flatLook = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
					flatLook = if flatLook.Magnitude > 0.01 then flatLook.Unit else Vector3.zAxis
					local right = Vector3.new(-flatLook.Z, 0, flatLook.X)
					local goal = root.Position - flatLook * (BEHIND + math.abs(side) * 0.35) + right * side
					local state = states[pet]
					if not state or (state.position - goal).Magnitude > SNAP_DISTANCE then
						state = { position = goal, facing = flatLook, ground = root.Position.Y - 3, nextRay = 0 }
						states[pet] = state
					end
					if now >= state.nextRay then
						state.nextRay = now + 0.12
						state.ground = groundAt(goal, ignore) or (root.Position.Y - 3)
					end
					local target = Vector3.new(goal.X, state.ground, goal.Z)
					local before = state.position
					state.position = before:Lerp(target, math.min(1, dt * FOLLOW_SPEED))
					local step = Vector3.new(state.position.X - before.X, 0, state.position.Z - before.Z)
					local speed = step.Magnitude / math.max(dt, 1e-3)
					if speed > 1 then
						state.facing = state.facing:Lerp(step.Unit, math.min(1, dt * 10))
					else
						state.facing = state.facing:Lerp(flatLook, math.min(1, dt * 3))
					end
					local hop = if speed > 2 then math.abs(math.sin(now * 11 + slot)) * HOP_HEIGHT else 0
					local at = state.position + Vector3.new(0, hop, 0)
					local facing = if state.facing.Magnitude > 0.01 then state.facing.Unit else flatLook
					petRoot.CFrame = CFrame.lookAt(at, at + facing)
				end
			end
		end
		for pet in states do
			if not pet.Parent then
				states[pet] = nil
			end
		end
	end)
end

return PetFollow
