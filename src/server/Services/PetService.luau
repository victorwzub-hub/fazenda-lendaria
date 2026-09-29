-- 🐾 Pets: os bichos equipados andam atrás do dono e dão bônus (Balance.petBonus).
-- O servidor só cria os modelos em Workspace.Pets; cada cliente move todos eles
-- (client/PetFollow), então eles andam lisinhos sem pesar o servidor.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnimalModel = require(Shared.AnimalModel)
local Balance = require(Shared.Balance)

local DataService = require(script.Parent.DataService)

local PetService = {}

local folder: Folder
local foldersOf: { [Player]: Folder } = {}

function PetService.refresh(player: Player)
	local profile = DataService.get(player)
	if foldersOf[player] then
		foldersOf[player]:Destroy()
		foldersOf[player] = nil
	end
	if not profile or not player.Parent then
		return
	end
	local mine = Instance.new("Folder")
	mine.Name = player.Name
	mine:SetAttribute("Dono", player.UserId)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local start = if root then root.CFrame * CFrame.new(0, -3, 5) else CFrame.new(0, 0, 0)
	local count = 0
	for _, animalId in profile.equipped do
		for _, animal in profile.animals do
			if animal.id == animalId then
				count += 1
				local model = AnimalModel.build(animal.species, animal.rarity, animal.shiny, Balance.animalName(animal))
				local tag = model.PrimaryPart and model.PrimaryPart:FindFirstChild("Tag")
				if tag then
					tag:Destroy()
				end
				model:ScaleTo(AnimalModel.petScale(animal.species))
				model:SetAttribute("Slot", count)
				model:PivotTo(start)
				model.Parent = mine
				break
			end
		end
	end
	mine:SetAttribute("Total", count)
	mine.Parent = folder
	foldersOf[player] = mine
end

function PetService.release(player: Player)
	if foldersOf[player] then
		foldersOf[player]:Destroy()
	end
	foldersOf[player] = nil
end

function PetService.init()
	folder = Instance.new("Folder")
	folder.Name = "Pets"
	folder.Parent = Workspace
	Players.PlayerRemoving:Connect(PetService.release)
end

return PetService
