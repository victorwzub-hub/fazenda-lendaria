-- Pose de carregar o ovo: quem tem o atributo "CarregandoOvo" no personagem fica com os dois
-- braços esticados para frente, segurando o ovo. A animação de andar é aplicada antes do
-- Stepped, então aqui a gente sobrescreve o Transform dos ombros/cotovelos por cima.
-- Funciona com Motor6D e com AnimationConstraint (juntas novas dos avatares R15).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CarryPose = {}

local ATTRIBUTE = "CarregandoOvo"
-- Braço para frente (quase 90°) e um pouco para dentro; cotovelo levemente dobrado.
local POSES: { [string]: { holder: string, pose: CFrame } } = {
	RightShoulder = { holder = "RightUpperArm", pose = CFrame.Angles(math.rad(85), 0, math.rad(-12)) },
	LeftShoulder = { holder = "LeftUpperArm", pose = CFrame.Angles(math.rad(85), 0, math.rad(12)) },
	RightElbow = { holder = "RightLowerArm", pose = CFrame.Angles(math.rad(12), 0, 0) },
	LeftElbow = { holder = "LeftLowerArm", pose = CFrame.Angles(math.rad(12), 0, 0) },
	-- R6
	["Right Shoulder"] = { holder = "Torso", pose = CFrame.Angles(0, 0, math.rad(90)) },
	["Left Shoulder"] = { holder = "Torso", pose = CFrame.Angles(0, 0, math.rad(-90)) },
}

function CarryPose.start()
	RunService.Stepped:Connect(function()
		for _, player in Players:GetPlayers() do
			local character = player.Character
			if character and character:GetAttribute(ATTRIBUTE) == true then
				for name, joint in POSES do
					local holder = character:FindFirstChild(joint.holder)
					local found = holder and holder:FindFirstChild(name)
					if found and (found:IsA("Motor6D") or found:IsA("AnimationConstraint")) then
						(found :: any).Transform = joint.pose
					end
				end
			end
		end
	end)
end

return CarryPose
