-- Peças marcadas com a tag de arco-íris (animais Míticos) trocam de cor sem parar.
-- Roda no cliente para não mandar mudança de cor pela rede a cada quadro.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AnimalModel = require(ReplicatedStorage:WaitForChild("Shared").AnimalModel)

local Rainbow = {}

local SPEED = 0.25 -- voltas no círculo de cores por segundo

function Rainbow.start()
	RunService.RenderStepped:Connect(function()
		local base = os.clock() * SPEED
		for index, part in CollectionService:GetTagged(AnimalModel.RAINBOW_TAG) do
			if part:IsA("BasePart") then
				-- Cada peça um pouco defasada: o arco-íris "corre" pelo corpo.
				part.Color = Color3.fromHSV((base + index * 0.07) % 1, 0.75, 1)
			end
		end
	end)
end

return Rainbow
